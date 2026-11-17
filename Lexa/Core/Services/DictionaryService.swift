import Foundation

/// Çevrim içi sözlük araması.
///
/// Seçilen ücretsiz API'ler (anahtar gerektirmez):
/// - **Free Dictionary API** (dictionaryapi.dev): İngilizce okunuş (IPA), kelime türü, örnek cümle, eş anlamlılar.
/// - **MyMemory** (api.mymemory.translated.net): EN/DE/ES → TR çeviri. Anonim kota: günde ~5.000 karakter.
///
/// İki istek `async let` ile paralel atılır, sonuçlar bellekte önbelleğe alınır.
protocol DictionaryServicing: Sendable {
    func lookup(_ term: String, lang: LearningLanguage) async throws -> Word
}

enum DictionaryError: LocalizedError {
    case notFound
    case network

    var errorDescription: String? {
        switch self {
        case .notFound: "Bu kelime için sonuç bulunamadı."
        case .network: "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene."
        }
    }
}

actor DictionaryService: DictionaryServicing {
    private let session: URLSession
    private var cache: [String: Word] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 2_000_000, diskCapacity: 20_000_000)
        session = URLSession(configuration: config)
    }

    func lookup(_ rawTerm: String, lang: LearningLanguage) async throws -> Word {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { throw DictionaryError.notFound }
        let key = "\(lang.rawValue):\(term)"
        if let hit = cache[key] { return hit }

        async let translation = translate(term, from: lang)
        async let entry: FreeDictionaryEntry? = lang == .en ? (try? define(term)) : nil

        let meaning = try await translation
        let dict = await entry

        guard let meaning, meaning.lowercased() != term else { throw DictionaryError.notFound }

        let firstMeaning = dict?.meanings.first
        let example = dict?.meanings.lazy.flatMap(\.definitions).compactMap(\.example).first
        let word = Word(
            id: key,
            lang: lang,
            term: term,
            ipa: dict?.phonetic ?? dict?.phonetics.compactMap(\.text).first,
            pos: firstMeaning.map { Self.turkishPartOfSpeech($0.partOfSpeech) },
            level: nil,
            meaning: meaning,
            example: example,
            exampleTr: nil,
            usage: firstMeaning?.definitions.first?.definition,
            synonyms: Array((firstMeaning?.synonyms ?? []).prefix(4))
        )
        cache[key] = word
        return word
    }

    // MARK: - MyMemory

    private struct MyMemoryResponse: Decodable {
        struct Data: Decodable { let translatedText: String }
        let responseData: Data
        let responseStatus: Int
    }

    private func translate(_ term: String, from lang: LearningLanguage) async throws -> String? {
        var comps = URLComponents(string: "https://api.mymemory.translated.net/get")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "langpair", value: "\(lang.rawValue)|tr")
        ]
        do {
            let (data, response) = try await session.data(from: comps.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DictionaryError.network }
            let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
            guard decoded.responseStatus == 200 else { return nil }
            let text = decoded.responseData.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text.lowercased(with: Locale(identifier: "tr"))
        } catch is DecodingError {
            return nil
        } catch {
            throw DictionaryError.network
        }
    }

    // MARK: - Free Dictionary API

    private struct FreeDictionaryEntry: Decodable {
        struct Phonetic: Decodable { let text: String? }
        struct Meaning: Decodable {
            struct Definition: Decodable {
                let definition: String
                let example: String?
            }
            let partOfSpeech: String
            let definitions: [Definition]
            let synonyms: [String]?
        }
        let phonetic: String?
        let phonetics: [Phonetic]
        let meanings: [Meaning]
    }

    private func define(_ term: String) async throws -> FreeDictionaryEntry? {
        let escaped = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? term
        let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(escaped)")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try JSONDecoder().decode([FreeDictionaryEntry].self, from: data).first
    }

    private static func turkishPartOfSpeech(_ pos: String) -> String {
        switch pos {
        case "noun": "isim"
        case "verb": "fiil"
        case "adjective": "sıfat"
        case "adverb": "zarf"
        case "pronoun": "zamir"
        case "preposition": "edat"
        case "conjunction": "bağlaç"
        case "interjection": "ünlem"
        default: pos
        }
    }
}
