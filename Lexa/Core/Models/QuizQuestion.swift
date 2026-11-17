import Foundation

/// Günlük pratik ve alıştırmalarda kullanılan soru tipleri.
enum QuizQuestion: Identifiable, Equatable {
    case multipleChoice(MultipleChoice)
    case match(Match)

    struct MultipleChoice: Equatable {
        let id = UUID()
        /// Gösterilen kelime (EN→TR'de yabancı kelime, TR→EN'de Türkçe anlam)
        let prompt: String
        let answer: String
        let options: [String]
        /// Kelime kartındaki dil (seslendirme için)
        let speakable: Bool
    }

    struct Match: Equatable {
        let id = UUID()
        /// (kelime, anlam) çiftleri
        let pairs: [(String, String)]
        /// Anlam sütununun karıştırılmış sırası (pairs indeksleri)
        let meaningOrder: [Int]

        static func == (lhs: Match, rhs: Match) -> Bool { lhs.id == rhs.id }
    }

    var id: UUID {
        switch self {
        case .multipleChoice(let q): q.id
        case .match(let q): q.id
        }
    }
}
