import SwiftUI

/// Tercih seçimi için alttan açılan sayfa.
struct PreferenceSheet: View {
    let viewModel: PreferencesViewModel
    let sheet: PreferencesViewModel.Sheet
    @State private var goalDraft: LearningGoal?
    @State private var examDraft: Exam?

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.l) {
            Text(title)
                .font(LexaFont.ui(22, weight: .bold))
                .foregroundStyle(LexaColor.ink)
                .padding(.top, LexaSpacing.xl)
            ScrollView {
                VStack(spacing: LexaSpacing.s) { content }
                    .padding(.bottom, LexaSpacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .background(PastelBackground())
        .presentationDetents(sheet == .level ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            goalDraft = viewModel.goal
            examDraft = viewModel.exam
        }
    }

    private var title: String {
        switch sheet {
        case .language: "Öğrenme Dili"
        case .level: "Kelime Seviyesi"
        case .frequency: "Kelime Değişim Sıklığı"
        case .goal: "Öğrenme Amacı"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch sheet {
        case .language:
            ForEach(LearningLanguage.allCases) { lang in
                ChoiceCard(title: lang.name, subtitle: lang.nativeName, emoji: lang.flag, cardTint: lang.tint,
                           isSelected: viewModel.language == lang) { viewModel.setLanguage(lang) }
            }
        case .level:
            LevelGrid(selection: viewModel.level) { viewModel.setLevel($0) }
        case .frequency:
            ForEach(RefreshOption.allCases) { option in
                ChoiceCard(title: option.name, subtitle: option.subtitle, symbol: option.symbol, iconTint: option.tint,
                           isSelected: viewModel.refresh == option) { viewModel.setRefresh(option) }
            }
            Label("iOS, pil durumuna göre widget yenilemesini biraz geciktirebilir.", systemImage: "info.circle")
                .font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
        case .goal:
            GoalPicker(language: viewModel.language, goal: $goalDraft, exam: $examDraft)
            Button("Kaydet") {
                if let goalDraft { viewModel.setGoal(goalDraft, exam: examDraft) }
            }
            .buttonStyle(.lexaPrimary)
            .disabled(goalDraft == nil || (goalDraft == .exam && examDraft == nil))
            .padding(.top, LexaSpacing.s)
        }
    }
}

/// 2 sütunlu seviye ızgarası (onboarding ve tercih sayfası ortak).
struct LevelGrid: View {
    let selection: Level?
    let onSelect: (Level) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(Level.allCases) { level in
                let on = selection == level
                Button { onSelect(level) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.rawValue).font(LexaFont.ui(26, weight: .bold))
                        Text(level.name).font(LexaFont.ui(15, weight: .semibold))
                    }
                    .foregroundStyle(LexaColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: LexaRadius.tile, style: .continuous).fill(level.tint.opacity(0.75)))
                    .overlay(RoundedRectangle(cornerRadius: LexaRadius.tile, style: .continuous).strokeBorder(on ? LexaColor.accent : Color.white.opacity(0.7), lineWidth: on ? 2.5 : 1))
                    .overlay(alignment: .topTrailing) {
                        if on { RadioMark(isOn: true).padding(10) }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(level.rawValue), \(level.name)")
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

/// Hedef + (İngilizcede) sınav seçimi.
struct GoalPicker: View {
    let language: LearningLanguage
    @Binding var goal: LearningGoal?
    @Binding var exam: Exam?

    var body: some View {
        VStack(spacing: LexaSpacing.s) {
            ForEach(LearningGoal.options(for: language)) { option in
                VStack(spacing: LexaSpacing.s) {
                    ChoiceCard(title: option.name, subtitle: option.subtitle, symbol: option.symbol, isSelected: goal == option) {
                        withAnimation(LexaMotion.base) { goal = option }
                    }
                    if option == .exam, goal == .exam {
                        examPanel
                    }
                }
            }
        }
    }

    private var examPanel: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.s) {
            Text("Hangi sınava hazırlanıyorsun?").font(LexaFont.ui(15, weight: .semibold)).foregroundStyle(LexaColor.ink)
            if exam == nil {
                Text("Devam etmek için bir sınav seç.").font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
            }
            HStack(spacing: LexaSpacing.s) {
                ForEach(Exam.allCases) { item in
                    let on = exam == item
                    Button { exam = item } label: {
                        HStack {
                            Text(item.name).font(LexaFont.ui(16, weight: .semibold))
                            Spacer()
                            RadioMark(isOn: on)
                        }
                        .foregroundStyle(LexaColor.ink)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(on ? 0.85 : 0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? LexaColor.accent : Color.white.opacity(0.8), lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
        }
        .padding(.leading, LexaSpacing.l)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
