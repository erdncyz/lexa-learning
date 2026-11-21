import Foundation
import Observation

@MainActor
@Observable
final class PracticeViewModel {
    enum Pane: Hashable { case daily, drills }

    struct WeekDay: Identifiable {
        let id: String
        let short: String
        let isDone: Bool
        let isToday: Bool
    }

    /// Her alıştırma adımı bu kadar yeni kelime tanıtır.
    static let wordsPerStep = 5
    /// Kelime az olsa da yol en az bu kadar adım (fazlası tekrar adımıdır).
    static let minimumSteps = 10

    /// Yolun yatay konumları: ilk 10 adım tasarımdaki gibi, sonrası aynı zikzakla devam eder.
    private static let designedX: [CGFloat] = [0.16, 0.40, 0.64, 0.80, 0.64, 0.40, 0.16, 0.40, 0.64, 0.40]
    private static let zigzagX: [CGFloat] = [0.16, 0.40, 0.64, 0.80, 0.64, 0.40]

    static func journeyX(_ step: Int) -> CGFloat {
        step < designedX.count ? designedX[step] : zigzagX[(step - designedX.count) % zigzagX.count]
    }

    var pane: Pane = .daily
    var activeSession: QuizSessionViewModel?

    private let app: AppState

    init(app: AppState) {
        self.app = app
        #if DEBUG
        if UserDefaults.standard.string(forKey: "lexaDemo") == "drills" { pane = .drills }
        #endif
    }

    // MARK: Günlük pratik

    var todayKey: String { DateKey.string(Date()) }
    var todayScore: Int? { app.data.dailyPractice[todayKey] }
    var isDoneToday: Bool { todayScore != nil }
    var dailyTotal: Int { 5 }

    var streak: Int {
        let days = app.data.dailyPractice
        let calendar = Calendar.current
        var cursor = Date()
        if days[DateKey.string(cursor)] == nil {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
            if days[DateKey.string(cursor)] == nil { return 0 }
        }
        var count = 0
        while days[DateKey.string(cursor)] != nil, count < 400 {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    var week: [WeekDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let today = Date()
        let monday = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let labels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        return labels.enumerated().map { offset, label in
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let key = DateKey.string(day)
            return WeekDay(id: key, short: label, isDone: app.data.dailyPractice[key] != nil, isToday: calendar.isDate(day, inSameDayAs: today))
        }
    }

    var successRateText: String {
        guard let score = todayScore else { return "—" }
        return "%\(Int((Double(score) / Double(dailyTotal) * 100).rounded()))"
    }

    func startDaily() {
        guard !isDoneToday else { return }
        // Alıştırmalarla aynı kural: seçilen seviye, az ise en yakın seviyeler.
        let pool = app.words.levelPool(lang: app.data.effectiveLang, level: app.data.effectiveLevel)
        let questions = QuizBuilder.daily(pool: pool)
        guard !questions.isEmpty else { return }
        let key = todayKey
        activeSession = QuizSessionViewModel(kind: .daily, questions: questions) { [weak app] correct, _ in
            app?.update { $0.dailyPractice[key] = correct }
        }
    }

    // MARK: Alıştırmalar

    var journeyDone: Int { min(app.data.journeyDone, journeyCount) }

    /// Alıştırma kelimeleri (seçilen seviye; az ise en yakın seviyeler).
    private var drillPool: [Word] {
        app.words.levelPool(lang: app.data.effectiveLang, level: app.data.effectiveLevel)
    }

    /// Adım sayısı kelime miktarına göre: her adımda 5 yeni kelime, en az 10 adım.
    var journeyCount: Int {
        let wordSteps = (drillPool.count + Self.wordsPerStep - 1) / Self.wordsPerStep
        return max(Self.minimumSteps, wordSteps)
    }

    enum StepStatus { case done, active, locked }

    func status(of step: Int) -> StepStatus {
        step < journeyDone ? .done : step == journeyDone ? .active : .locked
    }

    func startDrill(step: Int) {
        let count = journeyCount
        guard step <= journeyDone, step < count else { return }
        let questions = QuizBuilder.drill(pool: drillPool, step: step, wordsPerStep: Self.wordsPerStep)
        guard !questions.isEmpty else { return }
        activeSession = QuizSessionViewModel(kind: .drill(step: step), questions: questions) { [weak app] correct, _ in
            guard correct >= QuizSessionViewModel.drillPassMark else { return }
            app?.update { data in
                if step == data.journeyDone, data.journeyDone < count {
                    data.journeyDone += 1
                }
            }
        }
    }

    func canContinue(after step: Int) -> Bool {
        step + 1 < journeyCount && journeyDone >= step + 1
    }

    func speak(_ text: String) {
        app.speech.speak(text, lang: app.data.effectiveLang)
    }
}

enum DateKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
}
