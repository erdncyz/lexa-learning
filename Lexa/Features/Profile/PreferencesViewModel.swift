import Foundation
import Observation

/// Profil ve Widget'lar ekranlarının paylaştığı öğrenme tercihleri.
@MainActor
@Observable
final class PreferencesViewModel {
    enum Sheet: String, Identifiable {
        case language, level, frequency, goal
        var id: String { rawValue }
    }

    var sheet: Sheet?
    let app: AppState

    init(app: AppState) {
        self.app = app
    }

    var language: LearningLanguage { app.data.effectiveLang }
    var level: Level { app.data.effectiveLevel }
    var refresh: RefreshOption { app.data.effectiveRefresh }
    var goal: LearningGoal? { app.data.goal }
    var exam: Exam? { app.data.exam }

    var goalLabel: String {
        guard let goal else { return "Seçilmedi" }
        if goal == .exam, let exam { return exam.name }
        return goal == .dailyConversation ? "Günlük konuşma" : goal == .vocabularyGrowth ? "Kelime dağarcığı" : goal.name
    }

    func setLanguage(_ lang: LearningLanguage) {
        app.update { data in
            data.learnLang = lang
            // Almanca/İspanyolcada sınav hedefi yok.
            if lang != .en, data.goal == .exam {
                data.goal = nil
                data.exam = nil
            }
            data.todayWordShownAt = nil
        }
        sheet = nil
    }

    func setLevel(_ level: Level) {
        app.update {
            $0.level = level
            $0.todayWordShownAt = nil
        }
        sheet = nil
    }

    func setRefresh(_ option: RefreshOption) {
        app.update { $0.refresh = option }
        sheet = nil
    }

    func setGoal(_ goal: LearningGoal, exam: Exam?) {
        app.update {
            $0.goal = goal
            $0.exam = goal == .exam ? exam : nil
        }
        sheet = nil
    }
}
