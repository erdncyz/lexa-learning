import SwiftUI

/// "LEXA hazır!" — onboarding sonu, hesap oluşturma teklifi.
struct ReadyView: View {
    let app: AppState
    @State private var authScreen: AuthScreen?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: LexaSpacing.l) {
            HStack {
                CircleIconButton(symbol: "chevron.left", label: "Geri") { app.startOnboarding() }
                Spacer()
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(LexaColor.accent)
                .frame(width: 100, height: 100)
                .background(Circle().fill(LexaColor.glass.opacity(0.7)))
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            VStack(spacing: 8) {
                Text("LEXA hazır!").font(LexaFont.ui(32, weight: .bold)).foregroundStyle(LexaColor.ink)
                Text("Öğrenme yolculuğun başlıyor. Yeni kelimeler keşfetmeye hazırsın!")
                    .font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink2)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: LexaSpacing.s) {
                Button("Hesap Oluştur") { authScreen = .signup(keepProgress: true) }
                    .buttonStyle(.lexaPrimary)
                Button("Misafir Olarak Devam Et") { app.completeOnboarding() }
                    .buttonStyle(LexaButtonStyle(kind: .ghost))
                HStack(spacing: 4) {
                    Text("Zaten hesabın var mı?").foregroundStyle(LexaColor.ink2)
                    Button("Giriş Yap") { authScreen = .login }.fontWeight(.semibold).foregroundStyle(LexaColor.accent)
                }
                .font(LexaFont.ui(14))
            }
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .padding(.vertical, LexaSpacing.l)
        .background(PastelBackground())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { appeared = true }
        }
        .fullScreenCover(item: $authScreen) { screen in
            AuthFlowView(app: app, initial: screen) {
                authScreen = nil
                // Kayıt sonrası onboarding verisi taşındı; ana ekrana geç.
                if app.isSignedIn, app.phase != .main { app.completeOnboarding() }
            }
        }
    }
}
