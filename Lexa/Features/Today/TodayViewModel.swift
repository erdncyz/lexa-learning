import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    enum Decision { case known, learn }

    private let app: AppState
    private(set) var word: Word?

    init(app: AppState) {
        self.app = app
    }

    var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM EEEE"
        return f.string(from: Date()).uppercased(with: Locale(identifier: "tr_TR"))
    }

    var chipText: String { "\(app.data.effectiveLang.name) · \(app.data.effectiveLevel.rawValue)" }
    var flag: String { app.data.effectiveLang.flag }

    var isSaved: Bool { word.map { app.data.saved.contains($0.id) } ?? false }

    var status: Decision? {
        guard let id = word?.id else { return nil }
        if app.data.known.contains(id) { return .known }
        if app.data.learning.contains(id) { return .learn }
        return nil
    }

    /// Görünüm açıldığında ve uygulama öne geldiğinde çağrılır.
    func refresh() {
        word = app.syncTodayWord()
    }

    func decide(_ decision: Decision) {
        guard let word else { return }
        app.setDecision(decision, for: word)
    }

    func toggleSave() {
        guard let word else { return }
        app.toggleSaved(word)
    }

    func speak() {
        guard let word else { return }
        app.speech.speak(word.term, lang: word.lang)
    }

    func openWidgets() {
        app.selectedTab = .widgets
    }
}
