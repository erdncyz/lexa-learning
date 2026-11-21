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

    private(set) var words: WordRepository
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

    /// Firebase Hosting'deki kelime setinde değişiklik varsa indirip uygular.
    func refreshWords() async {
        guard let fresh = await WordSync.refresh() else { return }
        words = WordRepository(words: fresh)
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

    /// Bugünün kelimesi. Widget ile aynı takvimden okunur (bkz. `todaySchedule`),
    /// böylece widget'a basıp uygulamayı açınca aynı kelime görünür.
    @discardableResult
    func syncTodayWord(now: Date = Date()) -> Word? {
        guard let schedule = todaySchedule(now: now),
              let current = schedule.current(at: now),
              let id = current.entry.id,
              let word = word(id: id) else { return nil }
        WidgetBridge.publish(schedule)
        if data.todayWordId != id || data.todayWordShownAt != current.start {
            update {
                $0.todayWordId = id
                $0.todayWordShownAt = current.start
            }
        }
        return word
    }

    private var scheduleKey: String {
        [data.effectiveLang.rawValue, data.effectiveLevel.rawValue,
         data.effectiveExam?.rawValue ?? "-", String(data.effectiveRefresh.rawValue)].joined(separator: "|")
    }

    /// Kelime takvimi: şu anki kelime + sıradaki kelimeler, her biri başlangıç zamanıyla.
    /// - Ayarlar aynıysa şu anki kelime App Group'taki takvimden alınır (widget'ın gösterdiği kelime).
    /// - Sıradaki kelimeler ayarlara ve başlangıç anına göre deterministik karıştırılır; “Biliyorum”
    ///   denen kelimeler çıkarılır. Aynı girdiler hep aynı takvimi üretir (widget gereksiz yenilenmez).
    func todaySchedule(now: Date = Date()) -> WidgetSnapshot? {
        let pool = words.todayPool(lang: data.effectiveLang, level: data.effectiveLevel, exam: data.effectiveExam)
        guard !pool.isEmpty else { return nil }
        let key = scheduleKey
        let interval = TimeInterval(max(data.effectiveRefresh.rawValue, 15) * 60)
        let known = Set(data.known)

        var current: Word
        var start: Date
        if let shared = SharedStore.read(), shared.scheduleKey == key,
           let scheduled = shared.current(at: now), let id = scheduled.entry.id,
           let word = pool.first(where: { $0.id == id }) {
            current = word
            start = scheduled.start
        } else if let id = data.todayWordId, let word = pool.first(where: { $0.id == id }),
                  let shownAt = data.todayWordShownAt, now.timeIntervalSince(shownAt) < interval {
            // Takvim yok ama uygulamanın gösterdiği kelime hâlâ geçerli (ör. güncellemeden sonra ilk açılış).
            current = word
            start = shownAt
        } else {
            let candidates = pool.filter { !known.contains($0.id) }
            current = (candidates.isEmpty ? pool : candidates).randomElement()!
            start = now
        }

        var upcoming = pool.filter { $0.id != current.id && !known.contains($0.id) }
        if upcoming.isEmpty { upcoming = pool.filter { $0.id != current.id } }
        var generator = SeededGenerator(seed: Self.stableHash("\(key)|\(Int(start.timeIntervalSince1970))"))
        upcoming.shuffle(using: &generator)

        let entries = [current.widgetEntry(start: start)]
            + upcoming.prefix(23).enumerated().map { offset, word in
                word.widgetEntry(start: start.addingTimeInterval(TimeInterval(offset + 1) * interval))
            }
        return WidgetSnapshot(entries: entries, refreshMinutes: data.effectiveRefresh.rawValue,
                              languageName: data.effectiveLang.name, scheduleKey: key)
    }

    /// Uygulama açılışları arasında değişmeyen hash (Swift'in `Hasher`'ı her açılışta farklıdır).
    private static func stableHash(_ text: String) -> UInt64 {
        text.utf8.reduce(0xcbf29ce484222325) { ($0 ^ UInt64($1)) &* 0x100000001b3 }
    }

    func word(id: String) -> Word? {
        words.word(id: id, custom: data.customWords)
    }

    // MARK: - Widget

    func publishWidget() {
        guard data.onboarded || phase == .main else { return }
        if let schedule = todaySchedule() { WidgetBridge.publish(schedule) }
        // Günün kelimesi planı da güncel kalsın (değişmediyse servis hiçbir şey yapmaz).
        rescheduleNotification()
    }

    // MARK: - Bildirim

    /// Günün kelimesi bildirimi — widget kelimesinden bağımsız.
    /// Önümüzdeki 14 gün için, her güne kendi kelimesiyle, seçilen saatte birer bildirim kurulur.
    func rescheduleNotification(now: Date = Date()) {
        guard data.notifyOn else {
            notifications.cancel()
            return
        }
        _ = dailyWord(on: now)   // bugünün kelimesini sabitle (bildirimle aynı kalsın)
        let calendar = Calendar.current
        var plan: [NotificationService.DailyItem] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: data.notifyHour, minute: data.notifyMinute, second: 0, of: day),
                  fireDate > now else { continue }
            let word = dailyWord(on: day)
            let body = word.map { "Günün kelimesi: \($0.term) — \($0.meaning)" } ?? "Bugünün kelimesi seni bekliyor."
            plan.append(.init(
                date: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                wordId: word?.id,
                body: body
            ))
        }
        notifications.scheduleDaily(plan)
    }

    /// Günün kelimesi: tarihe göre belirlenir, günde bir değişir; widget takviminden bağımsızdır.
    /// Dil/seviye/sınav aynı kaldıkça aynı sırayla ilerler; “Biliyorum” denen kelimeler atlanır.
    /// Bugünün kelimesi cihazda sabitlenir: gün içinde “Biliyorum” denince değişmez ve bildirimle aynı kalır.
    func dailyWord(on date: Date) -> Word? {
        let pool = words.todayPool(lang: data.effectiveLang, level: data.effectiveLevel, exam: data.effectiveExam)
        let key = [data.effectiveLang.rawValue, data.effectiveLevel.rawValue, data.effectiveExam?.rawValue ?? "-"].joined(separator: "|")
        let day = DateKey.string(date)
        let isToday = Calendar.current.isDateInToday(date)
        if isToday,
           let pin = UserDefaults.standard.dictionary(forKey: Self.dailyPinKey) as? [String: String],
           pin["day"] == day, pin["key"] == key,
           let word = pool.first(where: { $0.id == pin["id"] }) {
            return word
        }

        let known = Set(data.known)
        var candidates = pool.filter { !known.contains($0.id) }
        if candidates.isEmpty { candidates = pool }
        guard !candidates.isEmpty else { return nil }
        var generator = SeededGenerator(seed: Self.stableHash("daily|\(key)"))
        candidates.shuffle(using: &generator)
        let dayNumber = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let word = candidates[dayNumber % candidates.count]
        if isToday {
            UserDefaults.standard.set(["day": day, "key": key, "id": word.id], forKey: Self.dailyPinKey)
        }
        return word
    }

    private static let dailyPinKey = "lexa.dailyWord"

    // MARK: - Kelime kararları (Bugün ve Pratik ortak)

    func setDecision(_ decision: TodayViewModel.Decision, for word: Word) {
        let current: TodayViewModel.Decision? = data.known.contains(word.id) ? .known : data.learning.contains(word.id) ? .learn : nil
        guard current != decision else { return }
        update { data in
            data.known.removeAll { $0 == word.id }
            data.learning.removeAll { $0 == word.id }
            switch decision {
            case .known: data.known.append(word.id)
            case .learn: data.learning.append(word.id)
            }
        }
        showToast(ToastMessage(
            title: decision == .known ? "Biliyorum olarak işaretlendi" : "Öğreneceklerim'e eklendi",
            detail: word.term,
            symbol: decision == .known ? "checkmark.circle" : "book",
            tone: decision == .known ? .mint : .lilac
        ))
    }

    func toggleSaved(_ word: Word) {
        let wasSaved = data.saved.contains(word.id)
        update { data in
            if wasSaved { data.saved.removeAll { $0 == word.id } } else { data.saved.append(word.id) }
        }
        showToast(ToastMessage(
            title: wasSaved ? "“\(word.term)” Kelimelerim destesinden çıkarıldı" : "“\(word.term)” Kelimelerim destesine eklendi",
            symbol: "bookmark"
        ))
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
