import Foundation
import Observation

/// Günlük pratik ve alıştırmaların ortak soru akışı.
/// Çoktan seçmeli: seçim anında kontrol edilir. Eşleştirme: önce kelime, sonra anlam.
@MainActor
@Observable
final class QuizSessionViewModel {
    enum Kind: Equatable {
        case daily
        case drill(step: Int)
    }

    struct Flash: Equatable {
        let word: Int
        let meaning: Int
    }

    let kind: Kind
    private(set) var questions: [QuizQuestion]
    private(set) var index = 0
    private(set) var picked: Int?
    private(set) var matched: Set<Int> = []
    private(set) var wordPick: Int?
    private(set) var flash: Flash?
    private(set) var correct = 0
    private(set) var finished = false

    private let onFinish: (Int, Int) -> Void

    static let drillPassMark = 12

    init(kind: Kind, questions: [QuizQuestion], onFinish: @escaping (_ correct: Int, _ total: Int) -> Void) {
        self.kind = kind
        self.questions = questions
        self.onFinish = onFinish
    }

    var total: Int { questions.count }
    var current: QuizQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    var progress: Double { total == 0 ? 0 : Double(index + 1) / Double(total) }
    var isLast: Bool { index >= total - 1 }
    var passed: Bool { kind == .daily || correct >= Self.drillPassMark }

    var canAdvance: Bool {
        switch current {
        case .multipleChoice: picked != nil
        case .match(let q): matched.count == q.pairs.count
        case nil: false
        }
    }

    var nextLabel: String {
        if case .match = current, kind == .daily { return "Devam Et" }
        return isLast ? "Sonuçları Gör" : "Sonraki Soru"
    }

    // MARK: Çoktan seçmeli

    func pick(_ option: Int) {
        guard picked == nil, case .multipleChoice = current else { return }
        picked = option
    }

    func isPickedCorrect() -> Bool {
        guard let picked, case .multipleChoice(let q) = current else { return false }
        return q.options[picked] == q.answer
    }

    // MARK: Eşleştirme

    func selectWord(_ i: Int) {
        guard flash == nil, !matched.contains(i) else { return }
        wordPick = wordPick == i ? nil : i
    }

    func selectMeaning(at position: Int) {
        guard flash == nil, let word = wordPick, case .match(let q) = current else { return }
        let pairIndex = q.meaningOrder[position]
        if pairIndex == word {
            matched.insert(word)
            wordPick = nil
        } else {
            flash = Flash(word: word, meaning: position)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                self.flash = nil
                self.wordPick = nil
            }
        }
    }

    var matchHint: String? {
        guard case .match(let q) = current else { return nil }
        if flash != nil { return "Bu eşleşme değil. Yeniden dene." }
        if matched.count == q.pairs.count { return "Eşleşmeler tamam." }
        return wordPick == nil ? nil : "Şimdi anlamı seç."
    }

    // MARK: Akış

    func advance() {
        guard canAdvance else { return }
        switch current {
        case .multipleChoice: if isPickedCorrect() { correct += 1 }
        case .match: correct += 1
        case nil: break
        }
        if isLast {
            finished = true
            onFinish(correct, total)
            return
        }
        index += 1
        picked = nil
        matched = []
        wordPick = nil
        flash = nil
    }
}

/// Soru üretimi — uygulamayla gelen kelime havuzundan.
enum QuizBuilder {
    /// Günlük pratik: 5 soru (ÇS, eşleştir, ÇS, eşleştir, ÇS).
    static func daily(pool: [Word]) -> [QuizQuestion] {
        var bag = pool.shuffled()
        guard bag.count >= 9 else { return [] }
        func take(_ n: Int) -> [Word] {
            let out = Array(bag.prefix(n))
            bag.removeFirst(min(n, bag.count))
            return out
        }
        let plan: [Bool] = [true, false, true, false, true]
        return plan.compactMap { isMC in
            if isMC {
                guard let w = take(1).first else { return nil }
                return multipleChoice(prompt: w.term, answer: w.meaning, distractors: pool.map(\.meaning), speakable: true)
            }
            let words = take(3)
            guard words.count == 3 else { return nil }
            return match(words)
        }
    }

    /// Alıştırma: 15 soru (5 yabancı→TR, 5 TR→yabancı, 5 eşleştirme), karışık sırada.
    /// Her adım havuzdaki sıradaki `wordsPerStep` yeni kelimeye odaklanır; eşleştirmelerde
    /// önceki adımların kelimeleri tekrar edilir. Yeni kelime kalmadıysa adım karışık tekrardır.
    static func drill(pool: [Word], step: Int, wordsPerStep: Int) -> [QuizQuestion] {
        guard pool.count >= 8 else { return [] }
        var generator = SeededGenerator(seed: UInt64(step * 7919 + Int.random(in: 0...999)))
        let start = step * wordsPerStep
        let fresh = start < pool.count ? Array(pool[start..<min(start + wordsPerStep, pool.count)]) : []
        let review = Array(pool[..<min(start, pool.count)])
        let focus = fresh.isEmpty ? Array(pool.shuffled(using: &generator).prefix(wordsPerStep)) : fresh
        let matchSet = fresh.isEmpty ? pool : (fresh + review)

        var items: [QuizQuestion] = []
        let forward = focus.shuffled(using: &generator)
        for i in 0..<5 {
            let w = forward[i % forward.count]
            items.append(multipleChoice(prompt: w.term, answer: w.meaning, distractors: pool.map(\.meaning), speakable: true))
        }
        let backward = focus.shuffled(using: &generator)
        for i in 0..<5 {
            let w = backward[i % backward.count]
            items.append(multipleChoice(prompt: w.meaning, answer: w.term, distractors: pool.map(\.term), speakable: false))
        }
        for i in 0..<5 {
            // Her eşleştirmede bir odak kelime + iki farklı tekrar kelimesi.
            let anchor = focus[i % focus.count]
            let others = (matchSet.count >= 3 ? matchSet : pool)
                .filter { $0.id != anchor.id }
                .shuffled(using: &generator)
                .prefix(2)
            items.append(match([anchor] + others))
        }
        return items.shuffled(using: &generator)
    }

    private static func multipleChoice(prompt: String, answer: String, distractors: [String], speakable: Bool) -> QuizQuestion {
        let others = Array(Set(distractors.filter { $0 != answer })).shuffled().prefix(3)
        return .multipleChoice(.init(prompt: prompt, answer: answer, options: ([answer] + others).shuffled(), speakable: speakable))
    }

    private static func match(_ words: [Word]) -> QuizQuestion {
        .match(.init(pairs: words.map { ($0.term, $0.meaning) }, meaningOrder: Array(0..<words.count).shuffled()))
    }
}

/// Tekrarlanabilir karıştırma için basit üreteç.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
