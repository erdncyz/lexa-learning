import Foundation

/// SwiftUI önizlemeleri için ağ ve Firebase gerektirmeyen sahte servisler.
final class PreviewAuthService: AuthServicing {
    var currentUser: AuthUser? { nil }
    func signIn(email: String, password: String) async throws -> AuthUser { AuthUser(uid: "preview", email: email, displayName: "Ada") }
    func signUp(name: String, email: String, password: String) async throws -> AuthUser { AuthUser(uid: "preview", email: email, displayName: name) }
    func sendPasswordReset(email: String) async throws {}
    func signOut() throws {}
    func signInWithApple(_ credential: AppleCredential) async throws -> (user: AuthUser, isNew: Bool) {
        (AuthUser(uid: "preview", email: nil, displayName: "Ada", provider: .apple), false)
    }
    func signInWithGoogle(_ credential: GoogleCredential) async throws -> (user: AuthUser, isNew: Bool) {
        (AuthUser(uid: "preview", email: "ada@gmail.com", displayName: "Ada", provider: .google), false)
    }
    func reauthenticate(_ method: ReauthMethod) async throws {}
    func deleteCurrentUser(appleAuthorizationCode: String?) async throws {}
}

struct PreviewUserRepository: UserRepositing {
    func load(uid: String) async throws -> UserData? { nil }
    func save(_ data: UserData, uid: String) async throws {}
    func delete(uid: String) async throws {}
}

struct PreviewDictionary: DictionaryServicing {
    func lookup(_ term: String, lang: LearningLanguage) async throws -> Word {
        Word(lang: lang, term: term, meaning: "örnek anlam")
    }
}

extension AppState {
    @MainActor
    static var preview: AppState {
        let state = AppState(auth: PreviewAuthService(), repository: PreviewUserRepository(), dictionary: PreviewDictionary())
        state.update {
            $0.onboarded = true
            $0.learnLang = .en
            $0.level = .b1
            $0.goal = .dailyConversation
            $0.refresh = .hourly
            $0.saved = ["en:thrive", "en:journey"]
            $0.learning = ["en:deadline"]
        }
        return state
    }
}
