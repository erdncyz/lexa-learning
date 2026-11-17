import Foundation
import FirebaseAuth

struct AuthUser: Equatable, Sendable {
    let uid: String
    let email: String?
    let displayName: String?
}

protocol AuthServicing: AnyObject {
    var currentUser: AuthUser? { get }
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(name: String, email: String, password: String) async throws -> AuthUser
    func sendPasswordReset(email: String) async throws
    func signOut() throws
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
    }

    private static func map(_ user: User) -> AuthUser {
        AuthUser(uid: user.uid, email: user.email, displayName: user.displayName)
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
        case .tooManyRequests: message = "Çok fazla deneme yapıldı. Biraz sonra tekrar dene."
        case .networkError: message = "Bağlantı kurulamadı. İnternetini kontrol et."
        case .operationNotAllowed: message = "E-posta ile giriş şu an kapalı."
        default: message = "Bir sorun oluştu. Lütfen tekrar dene."
        }
    }

    var errorDescription: String? { message }
}
