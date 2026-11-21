import Foundation
import Observation
import AuthenticationServices

enum AuthScreen: Hashable {
    case login
    case signup(keepProgress: Bool)
    case reset
}

@MainActor
@Observable
final class AuthViewModel {
    enum Field: Hashable { case name, email, password, password2 }

    var name = ""
    var email = ""
    var password = ""
    var password2 = ""
    var touched: Set<Field> = []

    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var infoMessage: String?

    private let app: AppState
    private let onSuccess: () -> Void

    init(app: AppState, onSuccess: @escaping () -> Void) {
        self.app = app
        self.onSuccess = onSuccess
    }

    // MARK: Doğrulama

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }

    func error(for field: Field, screen: AuthScreen) -> String? {
        guard touched.contains(field) else { return nil }
        switch field {
        case .name:
            return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Adını yaz." : nil
        case .email:
            if trimmedEmail.isEmpty { return "E-posta adresini yaz." }
            return Self.isValidEmail(trimmedEmail) ? nil : "Geçerli bir e-posta adresi yaz."
        case .password:
            if password.isEmpty { return "Şifreni yaz." }
            if case .signup = screen, password.count < 6 { return "Şifre en az 6 karakter olmalı." }
            return nil
        case .password2:
            return password2 == password ? nil : "Şifreler eşleşmiyor."
        }
    }

    func canSubmit(_ screen: AuthScreen) -> Bool {
        guard !isLoading else { return false }
        switch screen {
        case .login:
            return Self.isValidEmail(trimmedEmail) && !password.isEmpty
        case .signup:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && Self.isValidEmail(trimmedEmail)
                && password.count >= 6 && password == password2
        case .reset:
            return Self.isValidEmail(trimmedEmail)
        }
    }

    // MARK: Apple ile giriş

    func signInWithApple(_ result: Result<ASAuthorization, Error>, nonce: AppleNonce) async {
        errorMessage = nil
        infoMessage = nil
        switch result {
        case .failure(let error):
            // Kullanıcı Apple penceresini kapattıysa hata gösterme.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Apple ile giriş yapılamadı. Lütfen tekrar dene."
        case .success(let authorization):
            guard let credential = AppleCredential(authorization: authorization, rawNonce: nonce.raw) else {
                errorMessage = "Apple ile giriş yapılamadı. Lütfen tekrar dene."
                return
            }
            await completeSocialSignIn { try await self.app.auth.signInWithApple(credential) }
        }
    }

    // MARK: Google ile giriş

    func signInWithGoogle() async {
        errorMessage = nil
        infoMessage = nil
        let credential: GoogleCredential
        do {
            credential = try await GoogleSignInFlow.run()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await completeSocialSignIn { try await self.app.auth.signInWithGoogle(credential) }
    }

    /// Apple / Google girişinden sonra ortak adımlar: adı kaydet, misafir ilerlemesini taşı.
    private func completeSocialSignIn(_ signIn: () async throws -> (user: AuthUser, isNew: Bool)) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (user, isNew) = try await signIn()
            if isNew, let name = user.displayName, !name.isEmpty {
                app.update { $0.displayName = name }
            }
            await app.didAuthenticate(user, isNewAccount: isNew)
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#, options: .regularExpression) != nil
    }

    func resetMessages() {
        errorMessage = nil
        infoMessage = nil
        touched = []
    }

    // MARK: Gönderim

    func submit(_ screen: AuthScreen) async {
        guard canSubmit(screen) else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }
        do {
            switch screen {
            case .login:
                let user = try await app.auth.signIn(email: trimmedEmail, password: password)
                await app.didAuthenticate(user, isNewAccount: false)
                onSuccess()
            case .signup:
                let cleanName = name.trimmingCharacters(in: .whitespaces)
                let user = try await app.auth.signUp(name: cleanName, email: trimmedEmail, password: password)
                app.update { $0.displayName = cleanName }
                await app.didAuthenticate(user, isNewAccount: true)
                onSuccess()
            case .reset:
                try await app.auth.sendPasswordReset(email: trimmedEmail)
                infoMessage = "Sıfırlama bağlantısını \(trimmedEmail) adresine gönderdik. Gelen kutunu kontrol et."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
