import Foundation

/// Uygulamayla gelen kelime veri seti (Resources/words.json).
/// Ağ gerektirmez; Bugün, Pratik ve Widget anında çalışır.
final class WordRepository: Sendable {
    let all: [Word]
    private let byId: [String: Word]

    init(bundle: Bundle = .main) {
        let words: [Word]
        if let url = bundle.url(forResource: "words", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Word].self, from: data) {
            words = decoded
        } else {
            words = []
        }
        all = words
        byId = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func word(id: String, custom: [Word] = []) -> Word? {
        byId[id] ?? custom.first { $0.id == id }
    }

    /// Bugün kartı ve widget için: seçilen dil ve seviyedeki zengin içerikli kelimeler.
    /// Seviyede kelime kalmazsa bir alt / üst seviyelere genişler.
    func todayPool(lang: LearningLanguage, level: Level) -> [Word] {
        let rich = all.filter { $0.lang == lang && $0.example != nil }
        let exact = rich.filter { $0.level == level }
        if exact.count >= 3 { return exact }
        return rich.sorted { abs(($0.level?.index ?? 0) - level.index) < abs(($1.level?.index ?? 0) - level.index) }
    }

    /// Pratik soruları için kelime–anlam çiftleri (A1 temel kelimeler + seviyeye kadar olanlar).
    func practicePool(lang: LearningLanguage, upTo level: Level) -> [Word] {
        all.filter { $0.lang == lang && ($0.level ?? .a1) <= level }
    }

    func basicPool(lang: LearningLanguage) -> [Word] {
        all.filter { $0.lang == lang && $0.level == .a1 }
    }

    /// Yerel arama: terim ya da Türkçe anlam içinde geçenler.
    func search(_ query: String, lang: LearningLanguage, custom: [Word]) -> [Word] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr"))
        guard !q.isEmpty else { return [] }
        return (all + custom).filter { word in
            word.lang == lang && (
                word.term.lowercased().contains(q) ||
                word.meaning.lowercased(with: Locale(identifier: "tr")).contains(q)
            )
        }
    }
}
