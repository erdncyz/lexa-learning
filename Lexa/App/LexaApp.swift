import FirebaseCore
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct LexaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app: AppState?

    var body: some Scene {
        WindowGroup {
            Group {
                if let app {
                    RootView(app: app)
                } else {
                    PastelBackground()
                }
            }
            .task {
                // Firebase, AppDelegate'te yapılandırıldıktan sonra servisler oluşturulur.
                guard app == nil else { return }
                let state = AppState(
                    auth: FirebaseAuthService(),
                    repository: FirestoreUserRepository(),
                    dictionary: DictionaryService()
                )
                app = state
                #if DEBUG
                if state.applyDebugLaunchArguments() { return }
                #endif
                await state.bootstrap()
            }
        }
    }
}
