#if DEBUG
import Foundation

/// QA / ekran görüntüsü için başlatma parametreleri (yalnızca Debug derleme).
///
///     xcrun simctl launch <cihaz> com.yelizakdag.lexa -lexaDemo practice
///     xcrun simctl launch <cihaz> com.yelizakdag.lexa -lexaOnboarding
///
/// `-lexaDemo <sekme>`: misafir + örnek verilerle doğrudan sekmeyi açar
/// (today, explore, practice, drills, widgets, profile).
/// `-lexaOnboarding <adım>`: kurulum akışını açar (0–4).
extension AppState {
    func applyDebugLaunchArguments() -> Bool {
        let defaults = UserDefaults.standard
        if let tab = defaults.string(forKey: "lexaDemo") {
            continueAsGuest()
            update {
                $0 = UserData()
                $0.onboarded = true
                $0.learnLang = .en
                $0.level = .b1
                $0.goal = .dailyConversation
                $0.refresh = .hourly
                $0.saved = ["en:thrive", "en:journey"]
                $0.learning = ["en:deadline"]
                if tab == "done" {
                    $0.dailyPractice[DateKey.string(Date())] = 4
                }
                $0.journeyDone = 2
                $0.decks = [Deck(name: "Seyahat", wordIds: ["en:ticket", "en:luggage", "en:itinerary"])]
            }
            completeOnboarding()
            switch tab {
            case "explore": selectedTab = .explore
            case "practice", "drills", "done": selectedTab = .practice
            case "widgets": selectedTab = .widgets
            case "profile": selectedTab = .profile
            default: selectedTab = .today
            }
            return true
        }
        if defaults.object(forKey: "lexaOnboarding") != nil {
            continueAsGuest()
            update { $0 = UserData() }
            startOnboarding()
            return true
        }
        return false
    }
}
#endif
