import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(app: AppState) {
        _viewModel = State(initialValue: TodayViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                header
                if let word = viewModel.word {
                    WordCard(word: word, isSaved: viewModel.isSaved, status: viewModel.status,
                             onSave: viewModel.toggleSave, onSpeak: viewModel.speak,
                             onSwipe: { viewModel.decide($0) })
                    DecisionButtons(status: viewModel.status) { viewModel.decide($0) }
                } else {
                    EmptyStateCard(
                        title: "Bugünlük kelimeler bitti",
                        message: "Seviyendeki tüm kelimelere karar verdin. Seviyeni Profil’den değiştirebilirsin."
                    )
                }
                WidgetSetupLink(action: viewModel.openWidgets)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.top, LexaSpacing.s)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .lexaScreenBackground()
        .onAppear { viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.dateText)
                    .font(LexaFont.ui(13, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(LexaColor.ink2)
                Spacer()
                HStack(spacing: 6) {
                    Text(viewModel.flag)
                    Text(viewModel.chipText).font(LexaFont.ui(14, weight: .semibold))
                }
                .foregroundStyle(LexaColor.ink)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(LexaColor.glass.opacity(0.65)))
            }
            ScreenTitle(title: "Bugün")
        }
    }
}

/// Kaydırılabilir kelime kartı: sağa = Biliyorum, sola = Öğreneceğim.
struct WordCard: View {
    let word: Word
    /// Kartın üst etiketi: Bugün'de widget kelimesi, Pratik'te günün kelimesi.
    var label = "WIDGET KELİMEN"
    let isSaved: Bool
    let status: TodayViewModel.Decision?
    let onSave: () -> Void
    let onSpeak: () -> Void
    let onSwipe: (TodayViewModel.Decision) -> Void

    @State private var drag: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(LexaFont.ui(12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LexaColor.accent)
                Spacer()
                CircleIconButton(symbol: "bookmark", label: isSaved ? "Kelimelerim destesinden çıkar" : "Kelimelerim destesine kaydet", isOn: isSaved, action: onSave)
            }
            if let pos = word.pos {
                Text(pos).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
            }
            Button(action: onSpeak) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(word.term)
                        .font(LexaFont.display(word.term.count > 10 ? 40 : 48))
                        .foregroundStyle(LexaColor.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 15))
                        .foregroundStyle(LexaColor.ink2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(word.term), dinle")

            if let ipa = word.ipa {
                Text(ipa).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
            }
            Text(word.meaning)
                .font(LexaFont.ui(20, weight: .semibold))
                .foregroundStyle(LexaColor.ink)
            if let example = word.example {
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(example)”")
                        .font(LexaFont.displayItalic(19))
                        .foregroundStyle(LexaColor.ink)
                    if let tr = word.exampleTr {
                        Text(tr).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                    }
                }
                .padding(.top, LexaSpacing.m)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lexaCard(padding: 20)
        .overlay(alignment: .top) { stamp }
        .offset(x: drag)
        .rotationEffect(.degrees(Double(drag) / 40))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { drag = $0.translation.width }
                .onEnded { value in
                    if value.translation.width > 110 { onSwipe(.known) }
                    if value.translation.width < -110 { onSwipe(.learn) }
                    withAnimation(LexaMotion.spring) { drag = 0 }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Biliyorum") { onSwipe(.known) }
        .accessibilityAction(named: "Öğreneceğim") { onSwipe(.learn) }
    }

    @ViewBuilder
    private var stamp: some View {
        if abs(drag) > 40 {
            Text(drag > 0 ? "Biliyorum" : "Öğreneceğim")
                .font(LexaFont.ui(15, weight: .bold))
                .foregroundStyle(LexaColor.accent)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(drag > 0 ? LexaColor.mint : LexaColor.lavender))
                .padding(.top, -14)
                .transition(.opacity)
        }
    }
}

struct DecisionButtons: View {
    let status: TodayViewModel.Decision?
    let decide: (TodayViewModel.Decision) -> Void

    var body: some View {
        HStack(spacing: LexaSpacing.m) {
            button(.learn, title: "Öğreneceğim", symbol: "book", tint: LexaColor.lavender)
            button(.known, title: "Biliyorum", symbol: "checkmark.circle", tint: LexaColor.mint)
        }
    }

    private func button(_ kind: TodayViewModel.Decision, title: String, symbol: String, tint: Color) -> some View {
        let on = status == kind
        return Button { decide(kind) } label: {
            Label(title, systemImage: on ? "\(symbol).fill" : symbol)
                .font(LexaFont.ui(16, weight: .semibold))
                .foregroundStyle(on ? LexaColor.accentInk : LexaColor.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? tint : LexaColor.glass.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? LexaColor.accent.opacity(0.4) : LexaColor.glass.opacity(0.8)))
                .scaleEffect(on ? 1.02 : 1)
                .animation(LexaMotion.spring, value: on)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}

struct WidgetSetupLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LexaSpacing.m) {
                Image(systemName: "iphone")
                    .font(.system(size: 17))
                    .foregroundStyle(LexaColor.ink)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LexaColor.glass.opacity(0.7)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widget'ını kur").font(LexaFont.ui(16, weight: .semibold)).foregroundStyle(LexaColor.ink)
                    Text("Kelimeleri kilit ekranında ve ana ekranda gör.").font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(LexaColor.ink2)
            }
            .lexaCard(padding: 14, radius: LexaRadius.tile)
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview {
    TodayView(app: .preview)
}
