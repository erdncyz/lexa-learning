import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(app: AppState) {
        _viewModel = State(initialValue: OnboardingViewModel(app: app))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: LexaSpacing.xl) {
                    stepContent
                        .id(viewModel.step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .padding(.horizontal, LexaSpacing.gutter)
                .padding(.top, 40)
                .padding(.bottom, LexaSpacing.l)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .background(PastelBackground())
        .animation(LexaMotion.base, value: viewModel.step)
        .sheet(isPresented: $viewModel.showTimePicker) {
            TimeWheelSheet(time: viewModel.notifyTime) { viewModel.setNotifyTime($0) }
        }
    }

    private var topBar: some View {
        HStack(spacing: LexaSpacing.m) {
            Button(action: viewModel.back) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(LexaColor.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Geri")
            StepProgressBar(value: viewModel.progress)
            Text("\(viewModel.stepNumber)/\(viewModel.stepCount)")
                .font(LexaFont.ui(14, weight: .semibold))
                .foregroundStyle(LexaColor.ink2)
                .monospacedDigit()
        }
        .padding(.horizontal, LexaSpacing.l)
        .padding(.top, LexaSpacing.s)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .language:
            StepHeader(title: "Hangi dili öğrenmek istersin?", subtitle: "Bir dil seç, yeni kelimeler keşfetmeye başlayalım.")
            VStack(spacing: LexaSpacing.m) {
                ForEach(LearningLanguage.allCases) { lang in
                    ChoiceCard(title: lang.name, subtitle: lang.nativeName, emoji: lang.flag, cardTint: lang.tint,
                               isSelected: viewModel.language == lang) { viewModel.selectLanguage(lang) }
                }
            }
            Text("Kelime anlamları Türkçe gösterilir.")
                .font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
                .frame(maxWidth: .infinity)

        case .level:
            StepHeader(title: "Bu dilde seviyen nedir?", subtitle: "Sana uygun kelimelerle başlayalım. Seviyeni daha sonra değiştirebilirsin.")
            LevelGrid(selection: viewModel.level) { viewModel.selectLevel($0) }

        case .goal:
            StepHeader(title: "Ne için öğreniyorsun?", subtitle: "Hedefine uygun kelimelerle öğrenme deneyimini kişiselleştirelim.")
            GoalPicker(
                language: viewModel.app.data.effectiveLang,
                goal: Binding(get: { viewModel.goal }, set: { if let g = $0 { viewModel.selectGoal(g) } }),
                exam: Binding(get: { viewModel.exam }, set: { if let e = $0 { viewModel.selectExam(e) } })
            )

        case .frequency:
            StepHeader(title: "Kelimeler ne sıklıkla değişsin?", subtitle: "Yeni kelimelerle ne kadar sık karşılaşmak istediğini seç.")
            VStack(spacing: LexaSpacing.m) {
                ForEach(RefreshOption.allCases) { option in
                    ChoiceCard(title: option.name, subtitle: option.subtitle, symbol: option.symbol, iconTint: option.tint,
                               isSelected: viewModel.refresh == option) { viewModel.selectRefresh(option) }
                }
            }
            Label("Kelimeler, ana ekran ve kilit ekranında seçtiğin sıklıkta yenilenir.", systemImage: "info.circle")
                .font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)

        case .notify:
            StepHeader(title: "Hatırlatıcı ister misin?", subtitle: "Seçtiğin saatte günün kelimesini gönderelim. İstediğin zaman kapatabilirsin.")
            NotificationPreview(word: viewModel.previewWord)
            VStack(alignment: .leading, spacing: LexaSpacing.s) {
                Text("Hatırlatma saati").font(LexaFont.ui(19, weight: .semibold)).foregroundStyle(LexaColor.ink)
                Button { viewModel.showTimePicker = true } label: {
                    HStack(spacing: LexaSpacing.m) {
                        Image(systemName: "clock").foregroundStyle(LexaColor.accent)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(LexaColor.mint.opacity(0.7)))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Her gün").font(LexaFont.ui(13, weight: .semibold)).foregroundStyle(LexaColor.ink)
                            Text(viewModel.app.data.notifyTimeText).font(LexaFont.ui(17, weight: .bold)).foregroundStyle(LexaColor.accent)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(LexaColor.ink2)
                    }
                    .lexaCard(padding: 14, radius: LexaRadius.tile)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Hatırlatma saati, her gün \(viewModel.app.data.notifyTimeText)")
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: LexaSpacing.s) {
            if viewModel.step == .notify {
                Button("Bildirimlere izin ver") { Task { await viewModel.allowNotifications() } }
                    .buttonStyle(.lexaPrimary)
                Button("Şimdi değil", action: viewModel.skipNotifications)
                    .buttonStyle(LexaButtonStyle(kind: .ghost))
            } else {
                Button("Devam et", action: viewModel.next)
                    .buttonStyle(.lexaPrimary)
                    .disabled(!viewModel.canContinue)
            }
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .padding(.bottom, LexaSpacing.l)
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(LexaFont.ui(30, weight: .bold))
                .foregroundStyle(LexaColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink2)
        }
    }
}

private struct NotificationPreview: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("L").font(LexaFont.ui(13, weight: .bold)).foregroundStyle(LexaColor.onAccent)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7).fill(LexaColor.accent))
                Text("Lexa").font(LexaFont.ui(15, weight: .semibold))
                Spacer()
                Text("şimdi").font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2)
            }
            (Text("Günün kelimesi: ") + Text(word.term).bold())
                .font(LexaFont.ui(16))
            Text(word.meaning).font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
        }
        .foregroundStyle(LexaColor.ink)
        .lexaCard(padding: 16, radius: LexaRadius.tile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bildirim örneği. Günün kelimesi: \(word.term), \(word.meaning)")
    }
}

/// Saat seçici (iOS çark görünümü).
struct TimeWheelSheet: View {
    @State var time: Date
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: LexaSpacing.l) {
            Text("Hatırlatma saati").font(LexaFont.ui(20, weight: .bold)).padding(.top, LexaSpacing.xl)
            DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "tr_TR"))
            Button("Kaydet") {
                onSave(time)
                dismiss()
            }
            .buttonStyle(.lexaPrimary)
        }
        .padding(.horizontal, LexaSpacing.gutter)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}
