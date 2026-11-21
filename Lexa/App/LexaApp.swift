import FirebaseCore
import GoogleSignIn
import SwiftUI
import UserNotifications

/// Uygulama içi yönlendirmeler (bildirime basılınca gidilecek yer).
/// Soğuk açılışta AppState henüz yokken de çalışsın diye ayrı tutulur.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    /// Günün kelimesi bildirimine basıldı → Pratik › Günlük Pratik › günün kelimesi kartı.
    var showDailyWord = false
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier.hasPrefix("lexa-daily-word") else { return }
        await MainActor.run { AppRouter.shared.showDailyWord = true }
    }

    /// Uygulama açıkken de bildirim gösterilsin.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct LexaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app: AppState?
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            Group {
                if let app {
                    RootView(app: app)
                } else {
                    PastelBackground()
                }
            }
            // Google giriş penceresi kapandıktan sonra sonucu uygulamaya geri verir.
            .onOpenURL { url in _ = GIDSignIn.sharedInstance.handle(url) }
            .onAppear { appearance.apply() }
            .onChange(of: appearance) { _, mode in mode.apply() }
            .task {
                // Firebase, AppDelegate'te yapılandırıldıktan sonra servisler oluşturulur.
                guard app == nil else { return }
                let state = AppState(
                    auth: FirebaseAuthService(),
                    repository: FirestoreUserRepository(),
                    dictionary: DictionaryService()
                )
                app = state
                // Kelime setini her açılışta (QA modunda da) arka planda güncelle.
                Task { await state.refreshWords() }
                #if DEBUG
                if state.applyDebugLaunchArguments() { return }
                #endif
                await state.bootstrap()
            }
        }
    }
}
