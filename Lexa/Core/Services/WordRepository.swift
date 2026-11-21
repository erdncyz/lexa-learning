import Foundation

/// Kelime veri seti. Asıl kaynak Firebase Hosting'deki `words/v1.json` (bkz. `WordSync`);
/// en son indirilen kopya cihazda tutulur. Hiç indirilmediyse uygulamadaki yedek
/// (`Resources/words.json`) kullanılır. Böylece Bugün, Pratik ve Widget internetsiz de çalışır.
final class WordRepository: Sendable {
    let all: [Word]
    private let byId: [String: Word]

    /// Cihazdaki son kopya → yoksa uygulamadaki yedek.
    convenience init(bundle: Bundle = .main) {
        self.init(words: WordSync.cachedWords() ?? Self.bundled(bundle))
    }

    init(words: [Word]) {
        all = words
        byId = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func bundled(_ bundle: Bundle) -> [Word] {
        guard let url = bundle.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Word].self, from: data)) ?? []
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

    /// Pratik ve alıştırma kelimeleri: kullanıcının seçtiği seviye. O seviyede `minimum`'dan az
    /// kelime varsa en yakın seviyeler sırayla eklenir (eşit uzaklıkta önce kolay olan).
    /// Örn. İngilizce C2 (3 kelime) → C2 + C1 + B2 + B1.
    func levelPool(lang: LearningLanguage, level: Level, minimum: Int = 15) -> [Word] {
        let inLang = all.filter { $0.lang == lang }
        let byDistance = Level.allCases.sorted {
            let d0 = abs($0.index - level.index), d1 = abs($1.index - level.index)
            return d0 == d1 ? $0.index < $1.index : d0 < d1
        }
        var pool: [Word] = []
        for candidate in byDistance {
            if pool.count >= minimum { break }
            pool += inLang.filter { ($0.level ?? .a1) == candidate }
        }
        return pool
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

/// Kelime setini Firebase Hosting'den indirir ve cihaza kaydeder.
/// ETag ile yalnızca dosya değiştiyse indirilir (değişmediyse sunucu 304 döner).
enum WordSync {
    /// Şema değişirse yeni sürüm (v2…) yayınlanır; eski uygulamalar v1'i okumaya devam eder.
    static let url = URL(string: "https://lexa-learning.web.app/words/v1.json")!

    private static let etagKey = "lexa.words.etag"

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lexa-words-v1.json")
    }

    static func cachedWords() -> [Word]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let words = try? JSONDecoder().decode([Word].self, from: data),
              !words.isEmpty else { return nil }
        return words
    }

    /// Yeni bir set indirildiyse onu döner; değişiklik yoksa ya da hata olursa nil.
    static func refresh() async -> [Word]? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        if cachedWords() != nil, let etag = UserDefaults.standard.string(forKey: etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let words = try? JSONDecoder().decode([Word].self, from: data),
              !words.isEmpty else { return nil }
        try? data.write(to: cacheURL, options: .atomic)
        UserDefaults.standard.set(http.value(forHTTPHeaderField: "ETag"), forKey: etagKey)
        return words
    }
}
