import AVFoundation
import Foundation
import UserNotifications
import WidgetKit

/// Telaffuz: AVSpeechSynthesizer (cihazda, ücretsiz, çevrim dışı).
@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, lang: LearningLanguage, rate: Float = 0.45) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang.speechCode)
        utterance.rate = rate
        synthesizer.speak(utterance)
    }
}

/// "Günün kelimesi" yerel bildirimi. Sunucu (FCM) gerekmez.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "lexa-daily-word"

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleDaily(hour: Int, minute: Int, word: Word?) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Lexa"
        if let word {
            content.body = "Günün kelimesi: \(word.term) — \(word.meaning)"
        } else {
            content.body = "Bugünün kelimesi seni bekliyor."
        }
        content.sound = .default
        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

/// Widget'a gösterilecek kelimeleri App Group'a yazar ve zaman çizelgesini yeniler.
enum WidgetBridge {
    static func publish(words: [Word], refresh: RefreshOption, lang: LearningLanguage) {
        let snapshot = WidgetSnapshot(
            entries: words.prefix(24).map(\.widgetEntry),
            refreshMinutes: refresh.rawValue,
            languageName: lang.name
        )
        guard snapshot != SharedStore.read() else { return }
        SharedStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
