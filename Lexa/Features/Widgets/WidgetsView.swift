import SwiftUI

struct WidgetsView: View {
    @State private var preferences: PreferencesViewModel
    @State private var showGuide = false

    init(app: AppState) {
        _preferences = State(initialValue: PreferencesViewModel(app: app))
    }

    private var app: AppState { preferences.app }

    private var modeBinding: Binding<UserData.WidgetMode> {
        Binding(get: { app.data.widgetMode }, set: { mode in app.update { $0.widgetMode = mode } })
    }

    private var sampleWord: Word {
        app.data.todayWordId.flatMap(app.word(id:))
            ?? app.words.todayPool(lang: preferences.language, level: preferences.level).first
            ?? .preview
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                ScreenTitle(title: "Widget’lar", lead: "Kelimelerin her zaman seninle.")
                SegmentedTabs(options: [(.lock, "Kilit Ekranı"), (.home, "Ana Ekran")], selection: modeBinding)

                WidgetPreviewStage(mode: app.data.widgetMode, word: sampleWord)

                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle("Widget Ayarları").padding(.bottom, 4)
                    SettingRow(label: "Öğrenme Dili", value: preferences.language.name) { preferences.sheet = .language }
                    Divider().overlay(LexaColor.line.opacity(0.5))
                    SettingRow(label: "Kelime Seviyesi", value: preferences.level.rawValue) { preferences.sheet = .level }
                    Divider().overlay(LexaColor.line.opacity(0.5))
                    SettingRow(label: "Kelime Değişim Sıklığı", value: preferences.refresh.shortName) { preferences.sheet = .frequency }
                }
                .lexaCard(padding: 18)

                VStack(alignment: .leading, spacing: LexaSpacing.s) {
                    SectionTitle("Widget’ını Ekle")
                    Text("LEXA’yı kilit ekranına veya ana ekranına eklemek için adımları takip et.")
                        .font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                    Button("Nasıl Eklenir?") { showGuide = true }
                        .buttonStyle(.lexaPrimary)
                        .padding(.top, 4)
                }
                .lexaCard(padding: 18)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.top, LexaSpacing.s)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .lexaScreenBackground()
        .sheet(item: $preferences.sheet) { sheet in
            PreferenceSheet(viewModel: preferences, sheet: sheet)
        }
        .sheet(isPresented: $showGuide) {
            WidgetGuideView(initial: app.data.widgetMode)
        }
    }
}

/// Kilit ekranı / ana ekran önizlemesi.
struct WidgetPreviewStage: View {
    let mode: UserData.WidgetMode
    let word: Word

    var body: some View {
        VStack(spacing: LexaSpacing.m) {
            if mode == .lock {
                Text(Date.now, format: .dateTime.day().month(.wide).weekday(.wide).locale(Locale(identifier: "tr_TR")))
                    .font(LexaFont.ui(15, weight: .semibold))
                Text("9:41").font(.system(size: 64, weight: .bold, design: .rounded))
                VStack(spacing: 4) {
                    Text("LEXA").font(LexaFont.ui(11, weight: .bold)).tracking(1.4).foregroundStyle(LexaColor.accent)
                    Text(word.term).font(LexaFont.display(30))
                    Text(word.meaning).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.75)))
            } else {
                HStack(alignment: .top, spacing: LexaSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Günün kelimesi").font(LexaFont.ui(11, weight: .bold)).foregroundStyle(LexaColor.accent)
                        Text(word.term).font(LexaFont.display(26)).minimumScaleFactor(0.6).lineLimit(1)
                        if let ipa = word.ipa { Text(ipa).font(LexaFont.ui(12)).foregroundStyle(LexaColor.ink2) }
                        Spacer(minLength: 0)
                        Text(word.meaning).font(LexaFont.ui(13, weight: .semibold)).lineLimit(2)
                    }
                    .padding(14)
                    .frame(width: 150, height: 150, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.85)))
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 14), count: 2), spacing: 14) {
                        ForEach(["safari", "photo", "message", "note.text"], id: \.self) { symbol in
                            Image(systemName: symbol)
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(RoundedRectangle(cornerRadius: 14).fill(LexaColor.accent.opacity(0.75)))
                        }
                    }
                }
            }
        }
        .foregroundStyle(LexaColor.ink)
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [LexaColor.pink.opacity(0.8), LexaColor.lavender.opacity(0.8), LexaColor.mint.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .lexaCard(padding: 10, radius: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .lock ? "Kilit ekranı önizlemesi. Kelime \(word.term), anlamı \(word.meaning)." : "Ana ekran önizlemesi. Kelime \(word.term), anlamı \(word.meaning).")
        .animation(LexaMotion.base, value: mode)
    }
}

struct WidgetGuideView: View {
    @State var place: UserData.WidgetMode
    @Environment(\.dismiss) private var dismiss

    init(initial: UserData.WidgetMode) {
        _place = State(initialValue: initial)
    }

    private var steps: [String] {
        place == .lock
            ? ["Kilit ekranını basılı tut.", "Özelleştir seçeneğine dokun.", "Kilit Ekranı’nı seç.", "Saatin altındaki widget alanına dokun.", "LEXA widget’ını seç ve Bitti’ye dokun."]
            : ["Ana ekranda boş bir alana basılı tut.", "Düzenleme menüsünden Widget Ekle’yi aç.", "LEXA’yı bul.", "Widget boyutunu seç ve ekle.", "Widget’ı yerleştirerek işlemi tamamla."]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                HStack {
                    Spacer()
                    CircleIconButton(symbol: "xmark", label: "Kapat") { dismiss() }
                }
                ScreenTitle(title: "Widget Nasıl Eklenir?", lead: "LEXA kelimelerini ekranına taşımak için aşağıdaki adımları izle.")
                SegmentedTabs(options: [(.lock, "Kilit ekranı"), (.home, "Ana ekran")], selection: $place)
                VStack(spacing: LexaSpacing.s) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(spacing: LexaSpacing.m) {
                            Text("\(i + 1)")
                                .font(LexaFont.ui(15, weight: .bold))
                                .foregroundStyle(LexaColor.onAccent)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(LexaColor.accent))
                            Text(step).font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink)
                            Spacer(minLength: 0)
                        }
                        .lexaCard(padding: 14, radius: LexaRadius.tile)
                    }
                }
            }
            .padding(LexaSpacing.gutter)
        }
        .background(PastelBackground())
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    WidgetsView(app: .preview)
}
