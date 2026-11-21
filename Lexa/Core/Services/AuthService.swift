import Foundation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

struct AuthUser: Equatable, Sendable {
    let uid: String
    let email: String?
    let displayName: String?
    /// Hesabın giriş yöntemi — hesap silmeden önce yeniden doğrulama buna göre yapılır.
    var provider: AuthProvider = .password
}

enum AuthProvider: Sendable {
    case password, apple, google
}

/// Google'dan dönen tokenlar; Firebase'e giriş ve yeniden doğrulama için.
struct GoogleCredential: Sendable {
    let idToken: String
    let accessToken: String
}

/// Google giriş penceresini açar. Kullanıcı vazgeçerse `CancellationError` fırlatır.
enum GoogleSignInFlow {
    @MainActor
    static func run() async throws -> GoogleCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthFailure.message("Google ile giriş yapılandırılmamış.")
        }
        guard let presenter = topViewController() else {
            throw AuthFailure.message("Google ile giriş açılamadı. Lütfen tekrar dene.")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthFailure.message("Google ile giriş yapılamadı. Lütfen tekrar dene.")
            }
            return GoogleCredential(idToken: idToken, accessToken: result.user.accessToken.tokenString)
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue {
            throw CancellationError()
        } catch let failure as AuthFailure {
            throw failure
        } catch {
            throw AuthFailure.message("Google ile giriş yapılamadı. Lütfen tekrar dene.")
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Apple'dan dönen kimlik bilgisi; Firebase'e giriş ve hesap silme öncesi doğrulama için.
struct AppleCredential: Sendable {
    let idToken: String
    let rawNonce: String
    let authorizationCode: String?
    let fullName: PersonNameComponents?

    init?(authorization: ASAuthorization, rawNonce: String) {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = apple.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else { return nil }
        idToken = token
        self.rawNonce = rawNonce
        authorizationCode = apple.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        fullName = apple.fullName
    }
}

/// Apple isteğine eklenen tek kullanımlık rastgele değer (replay saldırılarına karşı).
struct AppleNonce {
    let raw: String

    init() {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        raw = String(bytes.map { charset[Int($0) % charset.count] })
    }

    var sha256: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Hesap silme gibi hassas işlemlerden önce kimliği yeniden doğrulama yolu.
enum ReauthMethod: Sendable {
    case password(String)
    case apple(AppleCredential)
    case google(GoogleCredential)
}

protocol AuthServicing: AnyObject {
    var currentUser: AuthUser? { get }
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(name: String, email: String, password: String) async throws -> AuthUser
    /// Apple ile giriş; `isNew` ilk kez hesap açıldıysa true döner.
    func signInWithApple(_ credential: AppleCredential) async throws -> (user: AuthUser, isNew: Bool)
    /// Google ile giriş; `isNew` ilk kez hesap açıldıysa true döner.
    func signInWithGoogle(_ credential: GoogleCredential) async throws -> (user: AuthUser, isNew: Bool)
    func sendPasswordReset(email: String) async throws
    func signOut() throws
    /// Firebase hassas işlemler için yakın zamanda giriş ister; şifre ya da Apple ile doğrular.
    func reauthenticate(_ method: ReauthMethod) async throws
    /// Oturumdaki Firebase Auth hesabını kalıcı olarak siler. Apple hesaplarında
    /// `appleAuthorizationCode` ile Apple tarafındaki erişim de iptal edilir.
    func deleteCurrentUser(appleAuthorizationCode: String?) async throws
}

/// Firebase Authentication — e-posta / şifre (Spark planında ücretsiz).
final class FirebaseAuthService: AuthServicing {
    var currentUser: AuthUser? {
        Auth.auth().currentUser.map(Self.map)
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return Self.map(result.user)
        } catch {
            throw AuthFailure(error)
        }
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try? await change.commitChanges()
            return AuthUser(uid: result.user.uid, email: result.user.email, displayName: name)
        } catch {
            throw AuthFailure(error)
        }
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> (user: AuthUser, isNew: Bool) {
        do {
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: credential.idToken,
                rawNonce: credential.rawNonce,
                fullName: credential.fullName
            )
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            // Apple adı yalnızca ilk girişte verir; profile kaydet.
            let name = credential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
            if let name, !name.isEmpty, result.user.displayName?.isEmpty ?? true {
                let change = result.user.createProfileChangeRequest()
                change.displayName = name
                try? await change.commitChanges()
            }
            return (Self.map(result.user), result.additionalUserInfo?.isNewUser ?? false)
        } catch {
            throw AuthFailure(error)
        }
    }

    func signInWithGoogle(_ credential: GoogleCredential) async throws -> (user: AuthUser, isNew: Bool) {
        do {
            let firebaseCredential = GoogleAuthProvider.credential(withIDToken: credential.idToken, accessToken: credential.accessToken)
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            return (Self.map(result.user), result.additionalUserInfo?.isNewUser ?? false)
        } catch {
            throw AuthFailure(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            Auth.auth().languageCode = "tr"
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthFailure(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func reauthenticate(_ method: ReauthMethod) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFailure.message("Oturum bulunamadı. Lütfen tekrar giriş yap.")
        }
        let credential: AuthCredential
        switch method {
        case .password(let password):
            guard let email = user.email else {
                throw AuthFailure.message("Oturum bulunamadı. Lütfen tekrar giriş yap.")
            }
            credential = EmailAuthProvider.credential(withEmail: email, password: password)
        case .apple(let apple):
            credential = OAuthProvider.appleCredential(withIDToken: apple.idToken, rawNonce: apple.rawNonce, fullName: nil)
        case .google(let google):
            credential = GoogleAuthProvider.credential(withIDToken: google.idToken, accessToken: google.accessToken)
        }
        do {
            try await user.reauthenticate(with: credential)
        } catch {
            throw AuthFailure(error)
        }
    }

    func deleteCurrentUser(appleAuthorizationCode: String?) async throws {
        guard let user = Auth.auth().currentUser else { return }
        if let code = appleAuthorizationCode {
            // Apple, hesap silinirken uygulamanın Apple erişiminin de iptal edilmesini ister.
            try? await Auth.auth().revokeToken(withAuthorizationCode: code)
        }
        do {
            try await user.delete()
        } catch {
            throw AuthFailure(error)
        }
        // Google hesabındaki LEXA erişim iznini de kaldır (Google kullanıcısı değilse etkisiz).
        try? await GIDSignIn.sharedInstance.disconnect()
    }

    private static func map(_ user: User) -> AuthUser {
        AuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            provider: provider(of: user)
        )
    }

    private static func provider(of user: User) -> AuthProvider {
        let ids = Set(user.providerData.map(\.providerID))
        if ids.contains("apple.com") { return .apple }
        if ids.contains("google.com") { return .google }
        return .password
    }
}

/// Firebase hata kodlarını kullanıcıya gösterilecek Türkçe mesajlara çevirir.
struct AuthFailure: LocalizedError {
    let message: String

    init(_ error: Error) {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidEmail: message = "Geçerli bir e-posta adresi yaz."
        case .emailAlreadyInUse: message = "Bu e-posta ile kayıtlı bir hesap zaten var."
        case .weakPassword: message = "Şifre en az 6 karakter olmalı."
        case .wrongPassword, .invalidCredential, .userNotFound: message = "E-posta veya şifre hatalı."
        case .requiresRecentLogin: message = "Güvenliğin için şifreni tekrar girmen gerekiyor."
        case .tooManyRequests: message = "Çok fazla deneme yapıldı. Biraz sonra tekrar dene."
        case .networkError: message = "Bağlantı kurulamadı. İnternetini kontrol et."
        case .operationNotAllowed: message = "Bu giriş yöntemi şu an kapalı."
        case .credentialAlreadyInUse, .accountExistsWithDifferentCredential:
            message = "Bu e-posta başka bir giriş yöntemiyle kayıtlı. O yöntemle giriş yap."
        default: message = "Bir sorun oluştu. Lütfen tekrar dene."
        }
    }

    private init(text: String) { message = text }
    static func message(_ text: String) -> AuthFailure { AuthFailure(text: text) }

    var errorDescription: String? { message }
}
