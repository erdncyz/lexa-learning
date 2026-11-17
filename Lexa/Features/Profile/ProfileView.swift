import SwiftUI

enum ProfileRoute: Hashable { case notifications, help, about }

struct ProfileView: View {
    @State private var preferences: PreferencesViewModel
    @State private var showAuth = false
    @State private var confirmSignOut = false

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
                .background(Circle().fill(Color.white.opacity(0.7)))
            Text(label).font(LexaFont.ui(16, weight: .semibold)).foregroundStyle(LexaColor.ink)
            Spacer()
            if let value { Text(value).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(LexaColor.ink2)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView(app: .preview)
}
