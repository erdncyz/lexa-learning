#if DEBUG
import Foundation

/// QA / ekran görüntüsü için başlatma parametreleri (yalnızca Debug derleme).
///
///     xcrun simctl launch <cihaz> com.lexa-learning.app -lexaDemo practice
///     xcrun simctl launch <cihaz> com.lexa-learning.app -lexaOnboarding
///
/// `-lexaDemo <sekme>`: misafir + örnek verilerle doğrudan sekmeyi açar
/// (today, explore, practice, drills, widgets, profile).
/// `-lexaOnboarding <adım>`: kurulum akışını açar (0–4).
/// `-lexaExam ielts|toefl|yds` (+ `-lexaDemo`): öğrenme amacını o sınav yapar.
/// `-lexaDailyWord YES` (+ `-lexaDemo`): günün kelimesi bildirimine basılmış gibi açar.
/// `-lexaAuth login|signup` (+ `-lexa.session ""`): giriş / kayıt ekranını açar (LandingView).
/// `-lexaSlide <0–4>` (+ `-lexa.session ""`): tanıtım slaytını açar (LandingView).
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
                if let raw = defaults.string(forKey: "lexaExam"), let exam = Exam(rawValue: raw) {
                    $0.goal = .exam
                    $0.exam = exam
                }
            }
            completeOnboarding()
            if defaults.bool(forKey: "lexaDailyWord") { AppRouter.shared.showDailyWord = true }
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
