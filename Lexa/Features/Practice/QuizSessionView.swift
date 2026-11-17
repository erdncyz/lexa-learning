import SwiftUI

/// Günlük pratik ve alıştırma ekranı (soru + sonuç).
struct QuizSessionView: View {
    let session: QuizSessionViewModel
    let practice: PracticeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLeave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: LexaSpacing.l) {
                    if session.finished {
                        QuizResultView(session: session, streak: practice.streak)
                    } else {
                        QuizProgress(session: session, streak: practice.streak)
                        question
                    }
                }
                .padding(.horizontal, LexaSpacing.gutter)
                .padding(.vertical, LexaSpacing.l)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .lexaScreenBackground()
        .animation(LexaMotion.base, value: session.index)
        .animation(LexaMotion.base, value: session.finished)
        .confirmationDialog(leaveTitle, isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Çık", role: .destructive) { dismiss() }
            Button("Devam et", role: .cancel) {}
        } message: {
            Text("İlerlemen kaydedilmeyecek.")
        }
    }

    private var title: String {
        switch session.kind {
        case .daily: "Günlük Pratik"
        case .drill(let step): "Alıştırma \(step + 1)"
        }
    }

    private var leaveTitle: String {
        session.kind == .daily ? "Pratikten çıkmak istiyor musun?" : "Alıştırmadan çıkmak istiyor musun?"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.m) {
            CircleIconButton(symbol: "chevron.left", label: "Geri") {
                if session.finished || (session.index == 0 && !session.canAdvance) {
                    dismiss()
                } else {
                    confirmLeave = true
                }
            }
            Text(title)
                .font(LexaFont.ui(30, weight: .bold))
                .foregroundStyle(LexaColor.ink)
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .padding(.top, LexaSpacing.s)
    }

    @ViewBuilder
    private var question: some View {
        switch session.current {
        case .multipleChoice(let q):
            MultipleChoiceView(question: q, session: session) { practice.speak(q.prompt) }
        case .match(let q):
            MatchView(question: q, session: session)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: LexaSpacing.s) {
            if session.finished {
                resultButtons
            } else {
                Button(session.nextLabel) { session.advance() }
                    .buttonStyle(.lexaPrimary)
                    .disabled(!session.canAdvance)
            }
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .padding(.bottom, LexaSpacing.l)
    }

    @ViewBuilder
    private var resultButtons: some View {
        switch session.kind {
        case .daily:
            Button("Pratik Sayfasına Dön") { dismiss() }.buttonStyle(.lexaPrimary)
        case .drill(let step):
            if session.passed {
                if practice.canContinue(after: step) {
                    Button("\(step + 2). Adıma Geç") {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            practice.startDrill(step: step + 1)
                        }
                    }
                    .buttonStyle(.lexaPrimary)
                    Button("Alıştırmalara Dön") { dismiss() }.buttonStyle(.lexaSecondary)
                } else {
                    Button("Alıştırmalara Dön") { dismiss() }.buttonStyle(.lexaPrimary)
                }
            } else {
                Button("Tekrar Dene") {
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        practice.startDrill(step: step)
                    }
                }
                .buttonStyle(.lexaPrimary)
                Button("Alıştırmalara Dön") { dismiss() }.buttonStyle(.lexaSecondary)
            }
        }
    }
}

// MARK: - Parçalar

private struct QuizProgress: View {
    let session: QuizSessionViewModel
    let streak: Int

    var body: some View {
        VStack(spacing: LexaSpacing.s) {
            HStack {
                Text("Soru \(session.index + 1) / \(session.total)")
                    .font(LexaFont.ui(15, weight: .semibold))
                    .foregroundStyle(LexaColor.ink)
                Spacer()
                if session.kind == .daily { StreakBadge(days: streak) }
            }
            StepProgressBar(value: session.progress)
        }
    }
}

private struct MultipleChoiceView: View {
    let question: QuizQuestion.MultipleChoice
    let session: QuizSessionViewModel
    let speak: () -> Void

    var body: some View {
        VStack(spacing: LexaSpacing.m) {
            Button(action: speak) {
                VStack(spacing: 6) {
                    Text(question.prompt)
                        .font(LexaFont.display(question.prompt.count > 12 ? 36 : 48, weight: .medium))
                        .foregroundStyle(LexaColor.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if question.speakable {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 14))
                            .foregroundStyle(LexaColor.ink2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 130)
                .lexaCard()
            }
            .buttonStyle(.plain)
            .disabled(!question.speakable)
            .accessibilityLabel("\(question.prompt)\(question.speakable ? ", dinlemek için dokun" : "")")

            ForEach(Array(question.options.enumerated()), id: \.element) { index, option in
                QuizOptionButton(label: option, state: optionState(index: index, option: option)) {
                    session.pick(index)
                }
            }

            if session.picked != nil {
                let ok = session.isPickedCorrect()
                Label(ok ? "Harika, doğru cevap!" : "Bir dahaki sefere!", systemImage: ok ? "checkmark" : "xmark")
                    .font(LexaFont.ui(15, weight: .semibold))
                    .foregroundStyle(ok ? LexaColor.accent : LexaColor.danger)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill((ok ? LexaColor.accentSoft : LexaColor.dangerSoft).opacity(0.8)))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private func optionState(index: Int, option: String) -> QuizOptionButton.State {
        guard let picked = session.picked else { return .idle }
        if option == question.answer { return .correct }
        if index == picked { return .wrong }
        return .dimmed
    }
}

struct QuizOptionButton: View {
    enum State { case idle, correct, wrong, dimmed }

    let label: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer(minLength: 24)
                Text(label)
                    .font(LexaFont.ui(17, weight: .semibold))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                Group {
                    switch state {
                    case .correct: Image(systemName: "checkmark")
                    case .wrong: Image(systemName: "xmark")
                    default: Color.clear
                    }
                }
                .frame(width: 24)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(stroke, lineWidth: state == .idle || state == .dimmed ? 1 : 2))
        }
        .buttonStyle(PressableStyle())
        .disabled(state != .idle)
        .opacity(state == .dimmed ? 0.6 : 1)
        .accessibilityValue(state == .correct ? "doğru cevap" : state == .wrong ? "yanlış" : "")
    }

    private var fill: Color {
        switch state {
        case .correct: LexaColor.accentSoft.opacity(0.9)
        case .wrong: LexaColor.dangerSoft.opacity(0.9)
        default: Color.white.opacity(0.55)
        }
    }

    private var stroke: Color {
        switch state {
        case .correct: LexaColor.accent
        case .wrong: LexaColor.danger
        default: Color.white.opacity(0.8)
        }
    }

    private var foreground: Color {
        switch state {
        case .wrong: LexaColor.dangerInk
        case .correct: LexaColor.accentInk
        default: LexaColor.ink
        }
    }
}

private struct MatchView: View {
    let question: QuizQuestion.Match
    let session: QuizSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kelimeyi anlamıyla eşleştir")
                    .font(LexaFont.ui(19, weight: .semibold))
                    .foregroundStyle(LexaColor.ink)
                Text("Önce kelimeyi, sonra anlamı seç.")
                    .font(LexaFont.ui(15))
                    .foregroundStyle(LexaColor.ink2)
            }
            HStack(alignment: .top, spacing: LexaSpacing.m) {
                column(title: "Kelime") {
                    ForEach(question.pairs.indices, id: \.self) { i in
                        MatchChip(
                            label: question.pairs[i].0,
                            isDone: session.matched.contains(i),
                            isPicked: session.wordPick == i,
                            isMiss: session.flash?.word == i,
                            serif: true
                        ) { session.selectWord(i) }
                    }
                }
                column(title: "Anlam") {
                    ForEach(question.meaningOrder.indices, id: \.self) { position in
                        let pairIndex = question.meaningOrder[position]
                        MatchChip(
                            label: question.pairs[pairIndex].1,
                            isDone: session.matched.contains(pairIndex),
                            isPicked: false,
                            isMiss: session.flash?.meaning == position,
                            serif: false
                        ) { session.selectMeaning(at: position) }
                        .disabled(session.wordPick == nil)
                    }
                }
            }
            if let hint = session.matchHint {
                Text(hint)
                    .font(LexaFont.ui(15, weight: .medium))
                    .foregroundStyle(session.flash != nil ? LexaColor.danger : LexaColor.ink2)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(LexaMotion.fast, value: session.matched)
        .animation(LexaMotion.fast, value: session.flash)
    }

    private func column<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: LexaSpacing.s) {
            Text(title)
                .font(LexaFont.ui(13, weight: .semibold))
                .foregroundStyle(LexaColor.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .frame(maxWidth: .infinity)
    }
}

struct MatchChip: View {
    let label: String
    let isDone: Bool
    let isPicked: Bool
    let isMiss: Bool
    let serif: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isDone { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                Text(label)
                    .font(serif ? LexaFont.display(19, weight: .medium) : LexaFont.ui(15, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isMiss ? LexaColor.dangerInk : isDone ? LexaColor.accentInk : LexaColor.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(stroke, lineWidth: isPicked || isMiss ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(isDone)
        .accessibilityAddTraits(isPicked ? [.isSelected] : [])
    }

    private var fill: Color {
        if isMiss { return LexaColor.dangerSoft.opacity(0.9) }
        if isDone { return LexaColor.accentSoft.opacity(0.85) }
        if isPicked { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.5)
    }

    private var stroke: Color {
        if isMiss { return LexaColor.danger }
        if isPicked { return LexaColor.accent }
        return Color.white.opacity(0.8)
    }
}

private struct QuizResultView: View {
    let session: QuizSessionViewModel
    let streak: Int

    var body: some View {
        VStack(spacing: LexaSpacing.l) {
            Image(systemName: session.passed ? "checkmark" : "arrow.counterclockwise")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(LexaColor.accent)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Color.white.opacity(0.7)))
                .padding(.top, 24)

            Text(title)
                .font(LexaFont.ui(24, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(LexaColor.ink)

            if session.kind == .daily {
                Text("Bugün de kelimelerini pekiştirdin.")
                    .font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                HStack(spacing: LexaSpacing.m) {
                    StatBox(value: "\(session.total)", caption: "soru tamamlandı", tint: LexaColor.mint)
                    StatBox(value: "\(session.correct)", caption: "doğru cevap", tint: LexaColor.lavender)
                }
                StreakBadge(days: streak)
            } else {
                let wrong = session.total - session.correct
                let rate = session.total == 0 ? 0 : Int((Double(session.correct) / Double(session.total) * 100).rounded())
                HStack(spacing: LexaSpacing.s) {
                    StatBox(value: "\(session.correct)", caption: "doğru cevap", tint: LexaColor.mint)
                    StatBox(value: "\(wrong)", caption: "yanlış cevap", tint: LexaColor.pink)
                    StatBox(value: "%\(rate)", caption: "başarı oranı", tint: LexaColor.lavender)
                }
                Text(cheer)
                    .font(LexaFont.ui(15, weight: .medium))
                    .foregroundStyle(session.passed ? LexaColor.accent : LexaColor.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch session.kind {
        case .daily: "Günlük pratiğini tamamladın!"
        case .drill(let step): session.passed ? "Alıştırma \(step + 1) Tamamlandı!" : "Çok Yaklaştın!"
        }
    }

    private var cheer: String {
        if session.passed { return "Harika! Bir sonraki adımın kilidi açıldı." }
        let need = QuizSessionViewModel.drillPassMark - session.correct
        return "Geçmek için \(need) doğru daha gerekiyor. Tekrar dene!"
    }
}
