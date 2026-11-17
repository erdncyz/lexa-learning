import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case language, level, goal, frequency, notify
    }

    private(set) var step: Step = .language
    var showTimePicker = false
    let app: AppState

    init(app: AppState) {
        self.app = app
    }

    var stepNumber: Int { step.rawValue + 1 }
    var stepCount: Int { Step.allCases.count }
    var progress: Double { Double(stepNumber) / Double(stepCount) }

    // Seçimler doğrudan kullanıcı verisine yazılır (prototipteki gibi).
    var language: LearningLanguage? { app.data.learnLang }
    var level: Level? { app.data.level }
    var goal: LearningGoal? { app.data.goal }
    var exam: Exam? { app.data.exam }
    var refresh: RefreshOption? { app.data.refresh }

    var canContinue: Bool {
        switch step {
        case .language: language != nil
        case .level: level != nil
        case .goal: goal != nil && (goal != .exam || exam != nil)
        case .frequency: refresh != nil
        case .notify: true
        }
    }

    var previewWord: Word {
        app.words.todayPool(lang: app.data.effectiveLang, level: app.data.effectiveLevel).first ?? .preview
    }

    func selectLanguage(_ lang: LearningLanguage) {
        app.update { data in
            data.learnLang = lang
            if lang != .en, data.goal == .exam {
                data.goal = nil
                data.exam = nil
            }
        }
    }

    func selectLevel(_ level: Level) { app.update { $0.level = level } }

    func selectGoal(_ goal: LearningGoal) {
        app.update {
            $0.goal = goal
            if goal != .exam { $0.exam = nil }
        }
    }

    func selectExam(_ exam: Exam) { app.update { $0.exam = exam } }

    func selectRefresh(_ option: RefreshOption) { app.update { $0.refresh = option } }

    var notifyTime: Date {
        Calendar.current.date(from: DateComponents(hour: app.data.notifyHour, minute: app.data.notifyMinute)) ?? .now
    }

    func setNotifyTime(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        app.update {
            $0.notifyHour = parts.hour ?? 9
            $0.notifyMinute = parts.minute ?? 0
        }
    }

    func next() {
        guard canContinue else { return }
        if let nextStep = Step(rawValue: step.rawValue + 1) {
            step = nextStep
        } else {
            app.finishOnboardingSteps()
        }
    }

    func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        } else if !app.isSignedIn {
            app.backToLanding()
        }
    }

    func allowNotifications() async {
        let granted = await app.notifications.requestPermission()
        app.update { $0.notifyOn = granted }
        if granted {
            app.syncTodayWord()
            app.rescheduleNotification()
        }
        app.finishOnboardingSteps()
    }

    func skipNotifications() {
        app.update { $0.notifyOn = false }
        app.finishOnboardingSteps()
    }
}
