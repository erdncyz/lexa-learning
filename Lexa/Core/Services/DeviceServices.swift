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
/// Widget kelimesinden bağımsızdır: her gün için ayrı bir bildirim, o günün kelimesiyle kurulur.
@MainActor
final class NotificationService {
    struct DailyItem: Equatable {
        let date: DateComponents   // yıl, ay, gün, saat, dakika
        let wordId: String?
        let body: String
    }

    private let center = UNUserNotificationCenter.current()
    /// Eski sürümdeki tek, her gün tekrar eden bildirim.
    private let legacyIdentifier = "lexa-daily-word"
    private let prefix = "lexa-daily-word-"
    private var lastPlan: [DailyItem] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Önümüzdeki günlerin bildirimlerini kurar. Plan değişmediyse hiçbir şey yapmaz.
    func scheduleDaily(_ plan: [DailyItem]) {
        guard plan != lastPlan else { return }
        lastPlan = plan
        Task {
            await removeScheduled()
            for item in plan {
                let content = UNMutableNotificationContent()
                content.title = "Lexa"
                content.body = item.body
                content.sound = .default
                if let wordId = item.wordId { content.userInfo = ["wordId": wordId] }
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.date, repeats: false)
                let id = prefix + String(format: "%04d-%02d-%02d", item.date.year ?? 0, item.date.month ?? 0, item.date.day ?? 0)
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    func cancel() {
        lastPlan = []
        Task { await removeScheduled() }
    }

    private func removeScheduled() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0 == legacyIdentifier || $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

/// Widget'ın takvimini App Group'a yazar; değiştiyse widget zaman çizelgesini yeniler.
enum WidgetBridge {
    static func publish(_ snapshot: WidgetSnapshot) {
        guard snapshot != SharedStore.read() else { return }
        SharedStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
