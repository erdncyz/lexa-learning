import SwiftUI

struct PracticeView: View {
    @State private var viewModel: PracticeViewModel
    private let router = AppRouter.shared

    init(app: AppState) {
        _viewModel = State(initialValue: PracticeViewModel(app: app))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: LexaSpacing.l) {
                    ScreenTitle(title: "Pratik", lead: "Her gün biraz daha ilerle.")
                    SegmentedTabs(options: [(.daily, "Günlük Pratik"), (.drills, "Alıştırmalar")], selection: $viewModel.pane)

                    switch viewModel.pane {
                    case .daily: DailyPracticePane(viewModel: viewModel)
                    case .drills: JourneyPane(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, LexaSpacing.gutter)
                .padding(.top, LexaSpacing.s)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            // Günün kelimesi bildirimine basıldıysa: Günlük Pratik'i aç, kartına kaydır.
            .onChange(of: router.showDailyWord, initial: true) { _, show in
                guard show else { return }
                viewModel.pane = .daily
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(LexaMotion.base) { proxy.scrollTo(DailyWordSection.anchor, anchor: .top) }
                    router.showDailyWord = false
                }
            }
        }
        .lexaScreenBackground()
        .fullScreenCover(item: $viewModel.activeSession) { session in
            QuizSessionView(session: session, practice: viewModel)
        }
    }
}

extension QuizSessionViewModel: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

// MARK: - Günlük pratik

private struct DailyPracticePane: View {
    let viewModel: PracticeViewModel

    var body: some View {
        VStack(spacing: LexaSpacing.l) {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                HStack {
                    Text("Günlük Pratik")
                        .font(LexaFont.ui(19, weight: .semibold))
                        .foregroundStyle(LexaColor.ink)
                    Spacer()
                    StreakBadge(days: viewModel.streak)
                }
                WeekStrip(days: viewModel.week)

                if viewModel.isDoneToday {
                    Label("Bugünkü Pratik Tamamlandı", systemImage: "checkmark")
                        .font(LexaFont.ui(16, weight: .semibold))
                        .foregroundStyle(LexaColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(LexaColor.accentSoft.opacity(0.7)))
                } else {
                    Text(viewModel.streak > 0 ? "Serini korumak için bugünkü pratiği tamamla." : "Bugünkü pratiğini tamamla, serini başlat.")
                        .font(LexaFont.ui(15))
                        .foregroundStyle(LexaColor.ink2)
                    Button("Günlük Pratiğe Başla") { viewModel.startDaily() }
                        .buttonStyle(.lexaPrimary)
                }
            }
            .lexaCard(padding: 18)

            if viewModel.isDoneToday {
                VStack(alignment: .leading, spacing: LexaSpacing.m) {
                    HStack {
                        Text("Bugünkü Sonucun").font(LexaFont.ui(18, weight: .semibold))
                        Spacer()
                        Image(systemName: "chart.bar").foregroundStyle(LexaColor.accent)
                    }
                    HStack(spacing: LexaSpacing.m) {
                        StatBox(value: "\(viewModel.todayScore ?? 0)/\(viewModel.dailyTotal)", caption: "Doğru cevap", tint: LexaColor.mint)
                        StatBox(value: viewModel.successRateText, caption: "Başarı oranı", tint: LexaColor.lavender)
                    }
                }
                .foregroundStyle(LexaColor.ink)
                .lexaCard(padding: 18)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Yarın görüşürüz!", systemImage: "sparkle")
                        .font(LexaFont.ui(17, weight: .semibold))
                        .foregroundStyle(LexaColor.ink)
                    Text("Yarın da pratiğini tamamlayarak serini devam ettirebilirsin.")
                        .font(LexaFont.ui(15))
                        .foregroundStyle(LexaColor.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lexaCard(padding: 18)
            }

            DailyWordSection(viewModel: viewModel)
        }
    }
}

/// Günün kelimesi: bildirim saatinde gelen kelime (widget kelimesinden bağımsız).
private struct DailyWordSection: View {
    static let anchor = "daily-word"
    let viewModel: PracticeViewModel

    var body: some View {
        if let word = viewModel.dailyWord {
            VStack(spacing: LexaSpacing.m) {
                WordCard(word: word, label: "GÜNÜN KELİMESİ", isSaved: viewModel.isDailySaved, status: viewModel.dailyStatus,
                         onSave: viewModel.toggleDailySave, onSpeak: viewModel.speakDaily,
                         onSwipe: { viewModel.decideDaily($0) })
                DecisionButtons(status: viewModel.dailyStatus) { viewModel.decideDaily($0) }
            }
            .id(Self.anchor)
        }
    }
}

struct WeekStrip: View {
    let days: [PracticeViewModel.WeekDay]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(day.isDone ? LexaColor.accent : LexaColor.glass.opacity(0.6))
                        if day.isToday && !day.isDone {
                            Circle().strokeBorder(LexaColor.accent, lineWidth: 2)
                        }
                        if day.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LexaColor.onAccent)
                        }
                    }
                    .frame(width: 32, height: 32)
                    Text(day.short)
                        .font(LexaFont.ui(12, weight: .semibold))
                        .foregroundStyle(LexaColor.ink2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.short), \(day.isDone ? "pratik tamam" : day.isToday ? "bugün" : "boş")")
            }
        }
    }
}

struct StatBox: View {
    let value: String
    let caption: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(LexaFont.display(28))
            Text(caption).font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.55)))
    }
}

// MARK: - Alıştırma yolu

private struct JourneyPane: View {
    let viewModel: PracticeViewModel
    private let tints: [Color] = [LexaColor.pink, LexaColor.cream, LexaColor.lavender, LexaColor.mint, LexaColor.blue]
    private let rowHeight: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.s) {
            HStack {
                Text("Alıştırmalar").font(LexaFont.ui(19, weight: .semibold))
                Spacer()
                Text("\(viewModel.journeyDone) / \(viewModel.journeyCount) tamamlandı")
                    .font(LexaFont.ui(13, weight: .semibold))
                    .foregroundStyle(LexaColor.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(LexaColor.accentSoft.opacity(0.8)))
            }
            .foregroundStyle(LexaColor.ink)
            Text("Kendi hızında ilerle, her adımda yeni kelimeler öğren.")
                .font(LexaFont.ui(15))
                .foregroundStyle(LexaColor.ink2)

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    Path { path in
                        for i in 0..<(viewModel.journeyCount - 1) {
                            let a = point(i, width: width)
                            let b = point(i + 1, width: width)
                            path.move(to: a)
                            path.addCurve(to: b, control1: CGPoint(x: a.x, y: a.y + rowHeight * 0.6), control2: CGPoint(x: b.x, y: b.y - rowHeight * 0.4))
                        }
                    }
                    .stroke(LexaColor.ink3.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                    ForEach(0..<viewModel.journeyCount, id: \.self) { step in
                        JourneyNode(
                            number: step + 1,
                            status: viewModel.status(of: step),
                            tint: tints[step % tints.count]
                        ) {
                            viewModel.startDrill(step: step)
                        }
                        .position(point(step, width: width))
                    }
                }
            }
            .frame(height: rowHeight * CGFloat(viewModel.journeyCount - 1) + 80)
            .padding(.top, LexaSpacing.s)
        }
    }

    private func point(_ i: Int, width: CGFloat) -> CGPoint {
        CGPoint(x: width * PracticeViewModel.journeyX(i), y: 40 + CGFloat(i) * rowHeight)
    }
}

private struct JourneyNode: View {
    let number: Int
    let status: PracticeViewModel.StepStatus
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Text("\(number)")
                    .font(LexaFont.display(24))
                    .foregroundStyle(LexaColor.ink)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(tint.opacity(status == .locked ? 0.55 : 0.95)))
                    .overlay(Circle().strokeBorder(LexaColor.glass.opacity(0.9), lineWidth: status == .active ? 4 : 1.5))
                    .shadow(color: .black.opacity(status == .active ? 0.15 : 0.05), radius: status == .active ? 10 : 4, y: 3)
                if status != .active {
                    Image(systemName: status == .done ? "checkmark" : "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(status == .done ? LexaColor.onAccent : LexaColor.ink2)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(status == .done ? LexaColor.accent : LexaColor.glass))
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(status == .locked)
        .accessibilityLabel("Adım \(number), \(status == .done ? "tamamlandı" : status == .active ? "açık adım" : "kilitli")")
    }
}

#Preview {
    PracticeView(app: .preview)
}
