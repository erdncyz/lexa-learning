import Foundation
import Observation

enum ExploreRoute: Hashable {
    case collection(CollectionKind)
    case newDeck
    case deck(String)
    case deckCard(String)
    case deckStudy(String)
}

enum CollectionKind: Hashable {
    case saved, toLearn

    var title: String { self == .saved ? "Kelimelerim" : "Öğreneceklerim" }
    var subtitle: String { self == .saved ? "Kaydettiğin kelimeler" : "Öğrenmek istediğin kelimeler" }
    var emptyMessage: String {
        self == .saved
            ? "Aramada veya Bugün kartında kaydettiğin kelimeler burada birikir."
            : "Bugün ekranında “Öğreneceğim” dediğin kelimeler burada birikir."
    }
}

@MainActor
@Observable
final class ExploreViewModel {
    enum RemoteState: Equatable {
        case idle
        case loading
        case found(Word)
        case failed(String)
    }

    var path: [ExploreRoute] = []
    var query = "" {
        didSet { scheduleSearch() }
    }
    private(set) var localResults: [Word] = []
    private(set) var remote: RemoteState = .idle

    let app: AppState
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(app: AppState) {
        self.app = app
    }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var lang: LearningLanguage { app.data.effectiveLang }

    // MARK: Arama

    /// Yerel sonuçlar anında; tam eşleşme yoksa 400 ms sonra çevrim içi sözlüğe sorulur.
    private func scheduleSearch() {
        searchTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        localResults = app.words.search(term, lang: lang, custom: app.data.customWords)
        guard term.count >= 2 else {
            remote = .idle
            return
        }
        let exact = localResults.contains { $0.term.lowercased() == term.lowercased() }
        guard !exact else {
            remote = .idle
            return
        }
        remote = .loading
        let lang = lang
        searchTask = Task { [weak self, dictionary = app.dictionary] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                let word = try await dictionary.lookup(term, lang: lang)
                guard !Task.isCancelled else { return }
                self?.remote = .found(word)
            } catch {
                guard !Task.isCancelled else { return }
                self?.remote = .failed(error.localizedDescription)
            }
        }
    }

    func clearSearch() {
        query = ""
    }

    // MARK: Kaydetme

    func isSaved(_ word: Word) -> Bool { app.data.saved.contains(word.id) }

    func toggleSave(_ word: Word) {
        let wasSaved = isSaved(word)
        app.update { data in
            if wasSaved {
                data.saved.removeAll { $0 == word.id }
            } else {
                // Çevrim içi sözlükten gelen kelimeyi kalıcı hale getir.
                if app.words.word(id: word.id) == nil, !data.customWords.contains(where: { $0.id == word.id }) {
                    data.customWords.append(word)
                }
                data.saved.append(word.id)
            }
        }
    }

    func speak(_ word: Word) {
        app.speech.speak(word.term, lang: word.lang)
    }

    // MARK: Koleksiyonlar

    func words(in kind: CollectionKind) -> [Word] {
        let ids = kind == .saved ? app.data.saved : app.data.learning
        var seen = Set<String>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return app.word(id: id)
        }
    }

    func remove(_ word: Word, from kind: CollectionKind) {
        app.update { data in
            if kind == .saved { data.saved.removeAll { $0 == word.id } } else { data.learning.removeAll { $0 == word.id } }
        }
    }

    // MARK: Desteler

    var decks: [Deck] { app.data.decks }

    func deck(_ id: String) -> Deck? { app.data.decks.first { $0.id == id } }

    func cards(of deck: Deck) -> [Word] { deck.wordIds.compactMap(app.word(id:)) }

    func createDeck(named name: String) -> String? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !clean.isEmpty else { return nil }
        let deck = Deck(name: String(clean.prefix(40)))
        app.update { $0.decks.append(deck) }
        app.showToast(ToastMessage(title: "“\(deck.name)” destesi oluşturuldu", symbol: "square.stack"))
        return deck.id
    }

    func addCard(to deckId: String, draft: CardDraft) {
        let word = Word(
            id: "custom:\(UUID().uuidString)",
            lang: lang,
            term: draft.word.trimmingCharacters(in: .whitespaces),
            pos: draft.pos.isEmpty ? nil : draft.pos.lowercased(with: Locale(identifier: "tr")),
            meaning: draft.meaning.trimmingCharacters(in: .whitespaces),
            example: draft.example.isEmpty ? nil : draft.example,
            exampleTr: draft.exampleTr.isEmpty ? nil : draft.exampleTr,
            isCustom: true
        )
        app.update { data in
            data.customWords.append(word)
            if let i = data.decks.firstIndex(where: { $0.id == deckId }) {
                data.decks[i].wordIds.append(word.id)
            }
        }
        app.showToast(ToastMessage(title: "Kelime kartı kaydedildi", detail: word.term, symbol: "checkmark"))
    }

    func deleteDeck(_ id: String) {
        app.update { $0.decks.removeAll { $0.id == id } }
    }
}

struct CardDraft {
    static let partsOfSpeech = ["İsim", "Fiil", "Sıfat", "Zarf", "Diğer"]

    var word = ""
    var meaning = ""
    var pos = ""
    var example = ""
    var exampleTr = ""

    var isReady: Bool {
        !word.trimmingCharacters(in: .whitespaces).isEmpty && !meaning.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
