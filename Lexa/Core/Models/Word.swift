import Foundation

/// Bir kelime kartı. Hem uygulamayla gelen veriler hem de kullanıcının oluşturduğu kartlar bu modeli kullanır.
struct Word: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var lang: LearningLanguage
    var term: String
    var ipa: String?
    var pos: String?
    var level: Level?
    /// Türkçe anlam
    var meaning: String
    var example: String?
    var exampleTr: String?
    var usage: String?
    var synonyms: [String]
    var topics: [String]
    var exams: [String]
    /// Kullanıcı tarafından oluşturulan kart mı?
    var isCustom: Bool

    init(
        id: String? = nil,
        lang: LearningLanguage,
        term: String,
        ipa: String? = nil,
        pos: String? = nil,
        level: Level? = nil,
        meaning: String,
        example: String? = nil,
        exampleTr: String? = nil,
        usage: String? = nil,
        synonyms: [String] = [],
        topics: [String] = [],
        exams: [String] = [],
        isCustom: Bool = false
    ) {
        self.id = id ?? "\(lang.rawValue):\(term.lowercased())"
        self.lang = lang
        self.term = term
        self.ipa = ipa
        self.pos = pos
        self.level = level
        self.meaning = meaning
        self.example = example
        self.exampleTr = exampleTr
        self.usage = usage
        self.synonyms = synonyms
        self.topics = topics
        self.exams = exams
        self.isCustom = isCustom
    }

    enum CodingKeys: String, CodingKey {
        case id, lang, term, ipa, pos, level, meaning, example, exampleTr, usage, synonyms, topics, exams, isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lang = try c.decode(LearningLanguage.self, forKey: .lang)
        let term = try c.decode(String.self, forKey: .term)
        self.init(
            id: try c.decodeIfPresent(String.self, forKey: .id),
            lang: lang,
            term: term,
            ipa: try c.decodeIfPresent(String.self, forKey: .ipa),
            pos: try c.decodeIfPresent(String.self, forKey: .pos),
            level: try c.decodeIfPresent(Level.self, forKey: .level),
            meaning: try c.decode(String.self, forKey: .meaning),
            example: try c.decodeIfPresent(String.self, forKey: .example),
            exampleTr: try c.decodeIfPresent(String.self, forKey: .exampleTr),
            usage: try c.decodeIfPresent(String.self, forKey: .usage),
            synonyms: try c.decodeIfPresent([String].self, forKey: .synonyms) ?? [],
            topics: try c.decodeIfPresent([String].self, forKey: .topics) ?? [],
            exams: try c.decodeIfPresent([String].self, forKey: .exams) ?? [],
            isCustom: try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        )
    }
}

extension Word {
    func widgetEntry(start: Date? = nil) -> WidgetSnapshot.Entry {
        WidgetSnapshot.Entry(word: term, ipa: ipa, meaning: meaning, level: level?.rawValue, id: id, start: start)
    }

    static let preview = Word(
        lang: .en, term: "cozy", ipa: "/ˈkoʊzi/", pos: "sıfat", level: .b1,
        meaning: "rahat, sıcacık",
        example: "We found a cozy café near the station.",
        exampleTr: "İstasyonun yakınında sıcacık bir kafe bulduk."
    )
}
