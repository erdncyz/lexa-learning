import SwiftUI
import AuthenticationServices

/// Giriş / kayıt / şifre sıfırlama akışı.
struct AuthFlowView: View {
    @State private var viewModel: AuthViewModel
    @State private var path: [AuthScreen] = []
    let initial: AuthScreen
    let onClose: () -> Void

    init(app: AppState, initial: AuthScreen, onClose: @escaping () -> Void) {
        self.initial = initial
        self.onClose = onClose
        _viewModel = State(initialValue: AuthViewModel(app: app, onSuccess: onClose))
    }

    var body: some View {
        NavigationStack(path: $path) {
            AuthFormView(screen: initial, viewModel: viewModel, onBack: onClose, navigate: navigate)
                .navigationDestination(for: AuthScreen.self) { screen in
                    AuthFormView(screen: screen, viewModel: viewModel, onBack: { path.removeLast() }, navigate: navigate)
                }
        }
    }

    private func navigate(_ screen: AuthScreen) {
        viewModel.resetMessages()
        if screen == initial {
            path.removeAll()
        } else if path.last != screen {
            path.append(screen)
        }
    }
}

private struct AuthFormView: View {
    let screen: AuthScreen
    @Bindable var viewModel: AuthViewModel
    let onBack: () -> Void
    let navigate: (AuthScreen) -> Void
    @FocusState private var focus: AuthViewModel.Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                CircleIconButton(symbol: "chevron.left", label: "Geri", action: onBack)

                Image("LexaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(LexaFont.ui(30, weight: .bold)).foregroundStyle(LexaColor.ink)
                    Text(lead).font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink2)
                }

                fields

                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(LexaFont.ui(14, weight: .medium))
                        .foregroundStyle(LexaColor.dangerInk)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if let info = viewModel.infoMessage {
                    Label(info, systemImage: "envelope")
                        .font(LexaFont.ui(14, weight: .medium))
                        .foregroundStyle(LexaColor.accent)
                }

                Button {
                    Task { await viewModel.submit(screen) }
                } label: {
                    if viewModel.isLoading { ProgressView().tint(LexaColor.onAccent) } else { Text(submitTitle) }
                }
                .buttonStyle(.lexaPrimary)
                .disabled(!viewModel.canSubmit(screen))

                if screen != .reset {
                    orDivider
                    AppleSignInButton(label: screen == .login ? .signIn : .continue, isDisabled: viewModel.isLoading) { result, nonce in
                        Task { await viewModel.signInWithApple(result, nonce: nonce) }
                    }
                }

                switchLine
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PastelBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onSubmit(advanceFocus)
    }

    private var title: String {
        switch screen {
        case .login: "Tekrar hoş geldin"
        case .signup(let keep): keep ? "Öğrendiklerini kaybetme" : "LEXA'ya katıl"
        case .reset: "Şifreni sıfırla"
        }
    }

    private var lead: String {
        switch screen {
        case .login: "Kaldığın yerden öğrenmeye devam et."
        case .signup(let keep): keep ? "Hesap oluşturarak öğrenme ilerlemeni koru." : "Kelimelerle öğrenme yolculuğuna başla."
        case .reset: "Hesabının e-posta adresini yaz."
        }
    }

    private var submitTitle: String {
        switch screen {
        case .login: "Giriş Yap"
        case .signup: "Hesap Oluştur"
        case .reset: "Sıfırlama Bağlantısı Gönder"
        }
    }

    @ViewBuilder
    private var fields: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.m) {
            if case .signup = screen {
                AuthTextField(label: "Ad", text: $viewModel.name, error: viewModel.error(for: .name, screen: screen),
                              content: .name, focus: $focus, field: .name) { viewModel.touched.insert(.name) }
            }
            AuthTextField(label: "E-posta adresi", text: $viewModel.email, error: viewModel.error(for: .email, screen: screen),
                          content: .emailAddress, keyboard: .emailAddress, focus: $focus, field: .email) { viewModel.touched.insert(.email) }
            if screen != .reset {
                AuthTextField(label: "Şifre", text: $viewModel.password, error: viewModel.error(for: .password, screen: screen),
                              content: screen == .login ? .password : .newPassword, secure: true, focus: $focus, field: .password) { viewModel.touched.insert(.password) }
            }
            if case .signup = screen {
                AuthTextField(label: "Şifre tekrar", text: $viewModel.password2, error: viewModel.error(for: .password2, screen: screen),
                              content: .newPassword, secure: true, focus: $focus, field: .password2) { viewModel.touched.insert(.password2) }
            }
            if screen == .login {
                Button("Şifremi Unuttum") { navigate(.reset) }
                    .font(LexaFont.ui(15, weight: .semibold))
                    .foregroundStyle(LexaColor.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var orDivider: some View {
        HStack(spacing: LexaSpacing.s) {
            Rectangle().fill(LexaColor.line.opacity(0.6)).frame(height: 1)
            Text("veya").font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
            Rectangle().fill(LexaColor.line.opacity(0.6)).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var switchLine: some View {
        switch screen {
        case .login:
            HStack(spacing: 4) {
                Text("Hesabın yok mu?").foregroundStyle(LexaColor.ink2)
                Button("Hesap Oluştur") { navigate(.signup(keepProgress: false)) }.fontWeight(.semibold).foregroundStyle(LexaColor.accent)
            }
            .font(LexaFont.ui(15))
            .frame(maxWidth: .infinity)
        case .signup:
            HStack(spacing: 4) {
                Text("Zaten hesabın var mı?").foregroundStyle(LexaColor.ink2)
                Button("Giriş Yap") { navigate(.login) }.fontWeight(.semibold).foregroundStyle(LexaColor.accent)
            }
            .font(LexaFont.ui(15))
            .frame(maxWidth: .infinity)
        case .reset:
            EmptyView()
        }
    }

    private func advanceFocus() {
        switch focus {
        case .name: focus = .email
        case .email: focus = screen == .reset ? nil : .password
        case .password: if case .signup = screen { focus = .password2 } else { focus = nil }
        default: focus = nil
        }
        if focus == nil { Task { await viewModel.submit(screen) } }
    }
}

struct AuthTextField: View {
    let label: String
    @Binding var text: String
    let error: String?
    var content: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var secure = false
    var focus: FocusState<AuthViewModel.Field?>.Binding
    let field: AuthViewModel.Field
    let onCommit: () -> Void

    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(LexaFont.ui(15, weight: .semibold)).foregroundStyle(LexaColor.ink)
            HStack {
                Group {
                    if secure && !reveal {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .font(LexaFont.ui(16))
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(field == .name ? .words : .never)
                .autocorrectionDisabled()
                .focused(focus, equals: field)
                .submitLabel(.next)
                .accessibilityLabel(label)

                if secure {
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(LexaColor.ink2)
                    }
                    .accessibilityLabel(reveal ? "Şifreyi gizle" : "Şifreyi göster")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(error == nil ? Color.white.opacity(0.9) : LexaColor.danger, lineWidth: error == nil ? 1 : 1.5))
            .onChange(of: focus.wrappedValue) { old, new in
                if old == field && new != field { onCommit() }
            }

            if let error {
                Text(error).font(LexaFont.ui(13)).foregroundStyle(LexaColor.dangerInk)
            }
        }
    }
}

/// Apple'ın resmi "Apple ile Giriş" butonu; her istekte yeni nonce üretir.
struct AppleSignInButton: View {
    var label: SignInWithAppleButton.Label = .continue
    var isDisabled = false
    let onCompletion: (Result<ASAuthorization, Error>, AppleNonce) -> Void

    @State private var nonce = AppleNonce()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SignInWithAppleButton(label) { request in
            nonce = AppleNonce()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce.sha256
        } onCompletion: { result in
            onCompletion(result, nonce)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}
