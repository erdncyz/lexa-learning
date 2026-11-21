import SwiftUI
import AuthenticationServices

enum ProfileRoute: Hashable { case notifications, help, about }

struct ProfileView: View {
    @State private var preferences: PreferencesViewModel
    @State private var showAuth = false
    @State private var confirmSignOut = false
    @State private var showDeleteAccount = false
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    init(app: AppState) {
        _preferences = State(initialValue: PreferencesViewModel(app: app))
    }

    private var app: AppState { preferences.app }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LexaSpacing.l) {
                    ScreenTitle(title: "Profil")
                    accountCard
                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle("Öğrenme Tercihlerim").padding(.bottom, 4)
                        SettingRow(symbol: "globe", label: "Öğrenme Dili", value: preferences.language.name) { preferences.sheet = .language }
                        Divider().overlay(LexaColor.line.opacity(0.5))
                        SettingRow(symbol: "chart.bar", label: "Kelime Seviyesi", value: preferences.level.rawValue) { preferences.sheet = .level }
                        Divider().overlay(LexaColor.line.opacity(0.5))
                        SettingRow(symbol: "target", label: "Öğrenme Amacı", value: preferences.goalLabel) { preferences.sheet = .goal }
                    }
                    .lexaCard(padding: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle("Uygulama Ayarları").padding(.bottom, 4)
                        Menu {
                            Picker("Görünüm", selection: $appearance) {
                                ForEach(AppAppearance.allCases) { mode in
                                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                                }
                            }
                        } label: {
                            rowLabel(symbol: "circle.lefthalf.filled", label: "Görünüm", value: appearance.title)
                        }
                        Divider().overlay(LexaColor.line.opacity(0.5))
                        NavigationLink(value: ProfileRoute.notifications) {
                            rowLabel(symbol: "bell", label: "Bildirimler", value: app.data.notifyOn ? "Açık" : "Kapalı")
                        }
                        Divider().overlay(LexaColor.line.opacity(0.5))
                        NavigationLink(value: ProfileRoute.help) { rowLabel(symbol: "bubble.left", label: "Yardım ve Destek") }
                        Divider().overlay(LexaColor.line.opacity(0.5))
                        NavigationLink(value: ProfileRoute.about) { rowLabel(symbol: "info.circle", label: "Hakkında") }
                    }
                    .buttonStyle(.plain)
                    .lexaCard(padding: 18)

                    if app.isSignedIn {
                        Button("Çıkış Yap") { confirmSignOut = true }
                            .buttonStyle(.lexaSecondary)
                        Button("Hesabı Sil") { showDeleteAccount = true }
                            .font(LexaFont.ui(15, weight: .semibold))
                            .foregroundStyle(LexaColor.dangerInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    Text("LEXA · Sürüm 1.0")
                        .font(LexaFont.ui(13))
                        .foregroundStyle(LexaColor.ink2)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, LexaSpacing.gutter)
                .padding(.top, LexaSpacing.s)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .lexaScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ProfileRoute.self) { route in
                Group {
                    switch route {
                    case .notifications: NotificationsView(app: app)
                    case .help: HelpView()
                    case .about: AboutView()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .sheet(item: $preferences.sheet) { sheet in
            PreferenceSheet(viewModel: preferences, sheet: sheet)
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthFlowView(app: app, initial: .signup(keepProgress: true)) { showAuth = false }
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountSheet(app: app)
        }
        .confirmationDialog("Hesabından çıkmak istiyor musun?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Çıkış Yap", role: .destructive) { app.signOut() }
        }
    }

    private var accountCard: some View {
        VStack(spacing: LexaSpacing.s) {
            ZStack {
                Circle().fill(LexaColor.accentSoft.opacity(0.9))
                if app.isSignedIn {
                    Text(initial).font(LexaFont.ui(26, weight: .bold)).foregroundStyle(LexaColor.accent)
                } else {
                    Image(systemName: "person").font(.system(size: 24)).foregroundStyle(LexaColor.accent)
                }
            }
            .frame(width: 64, height: 64)
            Text(name).font(LexaFont.ui(21, weight: .bold)).foregroundStyle(LexaColor.ink)
            Text(detail).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
            if !app.isSignedIn {
                Button("Hesap Oluştur / Giriş Yap") { showAuth = true }
                    .buttonStyle(.lexaPrimary)
                    .padding(.top, LexaSpacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .lexaCard(padding: 20)
    }

    private var name: String {
        guard app.isSignedIn else { return "Misafir Kullanıcı" }
        return app.data.displayName ?? app.user?.displayName ?? "Hesabın"
    }

    private var detail: String {
        app.isSignedIn ? (app.user?.email ?? "") : "Hesabın olmadan devam ediyorsun."
    }

    private var initial: String {
        String(name.prefix(1)).uppercased(with: Locale(identifier: "tr_TR"))
    }

    private func rowLabel(symbol: String, label: String, value: String? = nil) -> some View {
        HStack(spacing: LexaSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LexaColor.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(LexaColor.glass.opacity(0.7)))
            Text(label).font(LexaFont.ui(16, weight: .semibold)).foregroundStyle(LexaColor.ink)
            Spacer()
            if let value { Text(value).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(LexaColor.ink2)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

/// Hesap silme onayı: kalıcı olduğunu anlatır ve güvenlik için şifre ister.
private struct DeleteAccountSheet: View {
    let app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var confirmFinal = false
    @State private var pendingReauth: ReauthMethod?
    @FocusState private var focus: AuthViewModel.Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hesabını Sil").font(LexaFont.ui(28, weight: .bold)).foregroundStyle(LexaColor.ink)
                    Text("Bu işlem geri alınamaz. Hesabınla birlikte şunlar kalıcı olarak silinir:")
                        .font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink2)
                }

                VStack(alignment: .leading, spacing: 10) {
                    bullet("Kaydettiğin ve öğrendiğin kelimeler")
                    bullet("Oluşturduğun desteler ve kendi kelimelerin")
                    bullet("Öğrenme tercihlerin ve pratik ilerlemen")
                }
                .lexaCard(padding: 18)

                if provider == .apple || provider == .google {
                    Text("Güvenliğin için devam etmeden önce \(provider == .apple ? "Apple" : "Google") ile kimliğini doğrula.")
                        .font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                } else {
                    AuthTextField(
                        label: "Devam etmek için şifreni gir",
                        text: $password,
                        error: nil,
                        content: .password,
                        secure: true,
                        focus: $focus,
                        field: .password,
                        onCommit: {}
                    )
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(LexaFont.ui(14, weight: .medium))
                        .foregroundStyle(LexaColor.dangerInk)
                }

                if isDeleting {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 52)
                } else if provider == .apple {
                    AppleSignInButton(title: "Apple ile doğrula") { result, nonce in
                        handleApple(result, nonce: nonce)
                    }
                } else if provider == .google {
                    GoogleButton(title: "Google ile doğrula") { Task { await handleGoogle() } }
                } else {
                    Button("Hesabımı Kalıcı Olarak Sil") {
                        focus = nil
                        pendingReauth = .password(password)
                        confirmFinal = true
                    }
                    .buttonStyle(.lexaPrimary)
                    .disabled(password.isEmpty)
                }

                Button("Vazgeç") { dismiss() }
                    .buttonStyle(.lexaSecondary)
                    .disabled(isDeleting)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.l)
        }
        .lexaScreenBackground()
        .interactiveDismissDisabled(isDeleting)
        .confirmationDialog("Hesabın ve tüm verilerin silinecek. Emin misin?", isPresented: $confirmFinal, titleVisibility: .visible) {
            Button("Hesabı Sil", role: .destructive) { Task { await delete() } }
            Button("Vazgeç", role: .cancel) { pendingReauth = nil }
        }
    }

    private var provider: AuthProvider { app.user?.provider ?? .password }

    private func handleGoogle() async {
        errorMessage = nil
        do {
            pendingReauth = .google(try await GoogleSignInFlow.run())
            confirmFinal = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>, nonce: AppleNonce) {
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard let credential = AppleCredential(authorization: authorization, rawNonce: nonce.raw) else {
                errorMessage = "Apple ile doğrulanamadı. Lütfen tekrar dene."
                return
            }
            pendingReauth = .apple(credential)
            confirmFinal = true
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Apple ile doğrulanamadı. Lütfen tekrar dene."
        }
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "minus.circle")
            .font(LexaFont.ui(15))
            .foregroundStyle(LexaColor.ink)
    }

    private func delete() async {
        guard let method = pendingReauth else { return }
        pendingReauth = nil
        isDeleting = true
        errorMessage = nil
        do {
            try await app.deleteAccount(reauth: method)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

#Preview {
    ProfileView(app: .preview)
}
