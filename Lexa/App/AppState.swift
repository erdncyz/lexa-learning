import Foundation
import Observation

/// Uygulamanın tek doğruluk kaynağı (single source of truth).
/// ViewModel'ler veriyi buradan okur ve `update` ile değiştirir; kalıcılık ve
/// Firestore senkronu burada merkezi olarak yönetilir.
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case launching
        case landing
        case onboarding
        case ready
        case main
    }

    private(set) var phase: Phase = .launching
    private(set) var data = UserData()
    private(set) var user: AuthUser?
    private(set) var isGuest = false
    var selectedTab: MainTab = .today
    var toast: ToastMessage?

    let words: WordRepository
    let auth: AuthServicing
    let repository: UserRepositing
    let dictionary: DictionaryServicing
    let speech: SpeechService
    let notifications: NotificationService

    @ObservationIgnored private var remoteSaveTask: Task<Void, Never>?

    init(
        words: WordRepository = WordRepository(),
        auth: AuthServicing,
        repository: UserRepositing,
        dictionary: DictionaryServicing,
        speech: SpeechService? = nil,
        notifications: NotificationService? = nil
    ) {
        self.words = words
        self.auth = auth
        self.repository = repository
        self.dictionary = dictionary
        self.speech = speech ?? SpeechService()
        self.notifications = notifications ?? NotificationService()
    }

    var isSignedIn: Bool { user != nil }
    private var storeKey: String { user?.uid ?? "guest" }

    // MARK: - Açılış

    func bootstrap() async {
        if let current = auth.currentUser {
            user = current
            data = LocalStore.load(key: current.uid) ?? UserData()
            phase = data.onboarded ? .main : .onboarding
            if let remote = try? await repository.load(uid: current.uid) {
                data = remote
                LocalStore.save(remote, key: current.uid)
                phase = remote.onboarded ? .main : .onboarding
            }
        } else if LocalStore.lastSessionKey == "guest", let local = LocalStore.load(key: "guest") {
            isGuest = true
            data = local
            phase = local.onboarded ? .main : .onboarding
        } else {
            phase = .landing
        }
        publishWidget()
    }

    // MARK: - Veri güncelleme

    func update(_ change: (inout UserData) -> Void) {
        var copy = data
        change(&copy)
        guard copy != data else { return }
        copy.updatedAt = Date()
        data = copy
        persist()
    }

    private func persist() {
        LocalStore.save(data, key: storeKey)
        LocalStore.lastSessionKey = storeKey
        publishWidget()
        guard let uid = user?.uid else { return }
        // Art arda gelen değişiklikleri tek Firestore yazmasında birleştir.
        remoteSaveTask?.cancel()
        let snapshot = data
        remoteSaveTask = Task { [repository] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            try? await repository.save(snapshot, uid: uid)
        }
    }

    // MARK: - Oturum

    func continueAsGuest() {
        isGuest = true
        user = nil
        LocalStore.lastSessionKey = "guest"
        data = LocalStore.load(key: "guest") ?? UserData()
        phase = data.onboarded ? .main : .onboarding
    }

    func startOnboarding() {
        phase = .onboarding
    }

    /// Giriş / kayıt sonrası: buluttaki veri varsa onu kullan, yoksa misafir ilerlemesini taşı.
    func didAuthenticate(_ authUser: AuthUser, isNewAccount: Bool) async {
        var guestData = data
        // "LEXA hazır!" ekranından gelindiyse kurulum tamamlanmış sayılır.
        if phase == .ready { guestData.onboarded = true }
        user = authUser
        isGuest = false
        var resolved: UserData
        if !isNewAccount, let remote = try? await repository.load(uid: authUser.uid), remote.onboarded || !guestData.onboarded {
            resolved = remote
        } else {
            resolved = guestData
            if resolved.displayName == nil { resolved.displayName = authUser.displayName }
            try? await repository.save(resolved, uid: authUser.uid)
        }
        data = resolved
        LocalStore.save(resolved, key: authUser.uid)
        LocalStore.lastSessionKey = authUser.uid
        if isNewAccount { LocalStore.remove(key: "guest") }
        phase = resolved.onboarded ? .main : .onboarding
        publishWidget()
    }

    func signOut() {
        try? auth.signOut()
        remoteSaveTask?.cancel()
        resetSession()
    }

    /// Hesabı kalıcı olarak siler: önce şifre ya da Apple ile yeniden doğrular, sonra
    /// Firestore verisini, Firebase Auth hesabını ve cihazdaki kopyayı temizler.
    func deleteAccount(reauth method: ReauthMethod) async throws {
        guard let uid = user?.uid else { return }
        try await auth.reauthenticate(method)
        // Bekleyen kayıt, silinen dokümanı yeniden oluşturmasın.
        remoteSaveTask?.cancel()
        remoteSaveTask = nil
        do {
            try await repository.delete(uid: uid)
        } catch {
            throw AuthFailure.message("Verilerin silinemedi. İnternetini kontrol edip tekrar dene.")
        }
        var appleCode: String?
        if case .apple(let credential) = method { appleCode = credential.authorizationCode }
        try await auth.deleteCurrentUser(appleAuthorizationCode: appleCode)
        LocalStore.remove(key: uid)
        notifications.cancel()
        resetSession()
        showToast(ToastMessage(title: "Hesabın silindi", detail: "Tüm verilerin kaldırıldı.", symbol: "trash"))
    }

    private func resetSession() {
        user = nil
        isGuest = false
        data = UserData()
        LocalStore.lastSessionKey = nil
        selectedTab = .today
        phase = .landing
    }

    func finishOnboardingSteps() {
        if isSignedIn {
            completeOnboarding()
        } else {
            phase = .ready
        }
    }

    func completeOnboarding() {
        update { $0.onboarded = true }
        selectedTab = .today
        phase = .main
    }

    func backToLanding() {
        phase = .landing
    }

    // MARK: - Bugünün kelimesi

    /// Yenileme süresi dolduysa ya da dil/seviye değiştiyse yeni kelime seçer.
    @discardableResult
    func syncTodayWord(now: Date = Date()) -> Word? {
        let pool = words.todayPool(lang: data.effectiveLang, level: data.effectiveLevel)
        guard !pool.isEmpty else { return nil }
        let current = data.todayWordId.flatMap { id in pool.first { $0.id == id } }
        let interval = TimeInterval(data.effectiveRefresh.rawValue * 60)
        let due = data.todayWordShownAt.map { now.timeIntervalSince($0) >= interval } ?? true
        if let current, !due { return current }

        let known = Set(data.known)
        let candidates = pool.filter { !known.contains($0.id) && $0.id != current?.id }
        let next = candidates.randomElement() ?? pool.randomElement()!
        update {
            $0.todayWordId = next.id
            $0.todayWordShownAt = now
        }
        return next
    }

    func word(id: String) -> Word? {
        words.word(id: id, custom: data.customWords)
    }

    // MARK: - Widget

    func publishWidget() {
        guard data.onboarded || phase == .main else { return }
        var list = words.todayPool(lang: data.effectiveLang, level: data.effectiveLevel)
        if let id = data.todayWordId, let today = list.first(where: { $0.id == id }) {
            list.removeAll { $0.id == id }
            list.insert(today, at: 0)
        }
        WidgetBridge.publish(words: list, refresh: data.effectiveRefresh, lang: data.effectiveLang)
    }

    // MARK: - Bildirim

    func rescheduleNotification() {
        guard data.notifyOn else {
            notifications.cancel()
            return
        }
        let word = data.todayWordId.flatMap(word(id:))
        notifications.scheduleDaily(hour: data.notifyHour, minute: data.notifyMinute, word: word)
    }

    // MARK: - Toast

    func showToast(_ message: ToastMessage) {
        toast = message
    }
}

enum MainTab: Hashable, CaseIterable {
    case today, explore, practice, widgets, profile

    var title: String {
        switch self {
        case .today: "Bugün"
        case .explore: "Keşfet"
        case .practice: "Pratik"
        case .widgets: "Widget’lar"
        case .profile: "Profil"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .explore: "safari"
        case .practice: "target"
        case .widgets: "square.grid.2x2"
        case .profile: "person"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    enum Tone { case neutral, mint, lilac }
    let id = UUID()
    var title: String
    var detail: String?
    var symbol: String = "checkmark"
    var tone: Tone = .neutral
}
