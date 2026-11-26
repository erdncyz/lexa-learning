import SwiftUI

/// Tanıtım slaytları + giriş seçenekleri (açık / koyu temaya uyar).
struct LandingView: View {
    let app: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var page = 0
    @State private var authScreen: AuthScreen?

    private let slideCount = 4
    private var isPad: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            LandingBackground()
            VStack(spacing: 0) {
                header
                TabView(selection: $page) {
                    slide(title: "Kilit ekranında yeni bir kelime.",
                          lead: "Seçtiğin dilde yeni kelimeler keşfet, öğrenmeyi günlük hayatının bir parçası haline getir.") {
                        LockScreenSample(word: app.words.word(id: "en:thrive") ?? .preview)
                    }.tag(0)
                    slide(title: "Kelimeler hep ana ekranında.",
                          lead: "Widget'ını ana ekranına ekle, seçtiğin dilde yeni kelimeler gün boyu seninle olsun.") {
                        HomeScreenSample()
                    }.tag(1)
                    slide(title: "Keşfet, öğren, kaydet.",
                          lead: "Merak ettiğin kelimeleri ara, anlamlarını öğren ve kendi kelime kartlarını oluştur.") {
                        DictionarySample()
                    }.tag(2)
                    slide(title: "Öğrendiklerini pekiştir.",
                          lead: "Kısa testlerle kelimelerini tekrar et, öğrendiklerini kalıcı hale getir.") {
                        QuizSample()
                    }.tag(3)
                    authOptions.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if !isPad, page < slideCount {
                    PageDots(count: slideCount, current: page)
                        .padding(.bottom, LexaSpacing.l)
                    continueButton
                        .padding(.horizontal, LexaSpacing.gutter)
                        .padding(.bottom, LexaSpacing.l)
                }
            }
        }
        .fullScreenCover(item: $authScreen) { screen in
            AuthFlowView(app: app, initial: screen) { authScreen = nil }
        }
        #if DEBUG
        .onAppear {
            // QA: `-lexaSlide <0–4>` tanıtım slaytını, `-lexaAuth login|signup` giriş/kayıt ekranını açar.
            if UserDefaults.standard.object(forKey: "lexaSlide") != nil {
                page = min(max(UserDefaults.standard.integer(forKey: "lexaSlide"), 0), slideCount)
            }
            switch UserDefaults.standard.string(forKey: "lexaAuth") {
            case "login": authScreen = .login
            case "signup": authScreen = .signup(keepProgress: false)
            default: break
            }
        }
        #endif
    }

    private var header: some View {
        HStack {
            Text("LEXA").font(LexaFont.ui(14, weight: .bold)).tracking(2)
            Spacer()
            if page < slideCount {
                Button("Atla") { withAnimation(LexaMotion.base) { page = slideCount } }
                    .font(LexaFont.ui(15, weight: .semibold))
            }
        }
        .foregroundStyle(LexaColor.ink.opacity(0.85))
        .padding(.horizontal, isPad ? 48 : LexaSpacing.gutter)
        .padding(.top, LexaSpacing.s)
    }

    private var continueButton: some View {
        Button("Devam et") { withAnimation(LexaMotion.base) { page += 1 } }
            .buttonStyle(LandingButtonStyle(prominent: true))
    }

    private func slide<Stage: View>(title: String, lead: String, @ViewBuilder stage: () -> Stage) -> some View {
        Group {
            if isPad {
                HStack(alignment: .center, spacing: 56) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(title).font(LexaFont.ui(40, weight: .bold)).foregroundStyle(LexaColor.ink)
                        Text(lead).font(LexaFont.ui(18)).foregroundStyle(LexaColor.ink.opacity(0.72))
                        PageDots(count: slideCount, current: page)
                            .padding(.top, 8)
                        continueButton.frame(maxWidth: 280)
                    }
                    .frame(maxWidth: 440, alignment: .leading)
                    stage()
                        .frame(width: 340, height: 640)
                }
                .padding(.horizontal, 48)
            } else {
                IntroSlide(title: title, lead: lead) { stage() }
            }
        }
    }

    private var authOptions: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.l) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("Hazır mısın?").font(LexaFont.ui(34, weight: .bold))
                Text("Hesabınla giriş yap ya da yeni bir hesap oluştur.").font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink.opacity(0.75))
            }
            .foregroundStyle(LexaColor.ink)
            Spacer()
            VStack(spacing: LexaSpacing.m) {
                Button { authScreen = .login } label: { Label("Giriş yap", systemImage: "person") }
                    .buttonStyle(LandingButtonStyle(prominent: true))
                Button("Hesap oluştur") { authScreen = .signup(keepProgress: false) }
                    .buttonStyle(LandingButtonStyle(prominent: false))
                Button("Misafir olarak devam et") { app.continueAsGuest() }
                    .font(LexaFont.ui(16, weight: .semibold))
                    .foregroundStyle(LexaColor.ink.opacity(0.85))
                    .frame(minHeight: 44)
            }
            .padding(.bottom, LexaSpacing.xl)
        }
        .padding(.horizontal, LexaSpacing.gutter)
    }
}

extension AuthScreen: Identifiable {
    var id: String {
        switch self {
        case .login: "login"
        case .signup(let keep): "signup-\(keep)"
        case .reset: "reset"
        }
    }
}

private struct LandingBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark { GlowBackground(intensity: .vivid) } else { PastelBackground() }
    }
}

private struct IntroSlide<Stage: View>: View {
    let title: String
    let lead: String
    @ViewBuilder let stage: Stage

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.xxl) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(LexaFont.ui(30, weight: .bold)).foregroundStyle(LexaColor.ink)
                Text(lead).font(LexaFont.ui(16)).foregroundStyle(LexaColor.ink.opacity(0.72))
            }
            .padding(.top, 40)
            stage.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, LexaSpacing.gutter)
    }
}

private struct GlassDark: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.primary.opacity(0.12)))
    }
}

// MARK: - Telefon maketi (kilit ekranı / ana ekran slaytları)

/// Lavanta-mavi ekranlı iPhone maketi. Alt kısmı sayfaya doğru yumuşakça kaybolur;
/// içerik üstten başlar, böylece küçük ekranlarda da taşmadan kesilir.
private struct PhoneMockup<Screen: View>: View {
    @ViewBuilder let screen: (_ innerWidth: CGFloat) -> Screen
    @Environment(\.colorScheme) private var scheme

    private let radius: CGFloat = 46
    private let bezel: CGFloat = 7
    private let inset: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 32, 300)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(screenFill)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(bezelColor, lineWidth: bezel)
                Capsule().fill(Color.black.opacity(scheme == .dark ? 0.85 : 0.7))
                    .frame(width: 84, height: 24)
                    .padding(.top, 16)
                VStack(spacing: 0) {
                    statusBar
                        .padding(.top, 20)
                        .padding(.horizontal, 30)
                    screen(width - inset * 2)
                        .padding(.horizontal, inset)
                        .padding(.top, 22)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: width, height: proxy.size.height)
            .frame(maxWidth: .infinity)
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var statusBar: some View {
        HStack {
            Text("9:41").font(.system(size: 14, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
    }

    private var bezelColor: Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color(hex: 0x8B8CC9).opacity(0.5)
    }

    private var screenFill: some ShapeStyle {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(hex: 0x3B3668), Color(hex: 0x2B3F66), Color(hex: 0x1E2333)]
                : [Color(hex: 0xA9A4E4), Color(hex: 0x9DBEF0), Color(hex: 0xE4E8F5)],
            startPoint: .topLeading, endPoint: .bottom
        )
    }
}

/// Maketlerdeki "Günün Kelimesi" widget kartı.
private struct WordWidgetCard: View {
    let term: String
    let ipa: String?
    let meaning: String
    var level: Level?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("GÜNÜN KELİMESİ")
                .font(LexaFont.ui(10, weight: .bold)).tracking(1.4)
                .foregroundStyle(LexaColor.accent)
            Text(term)
                .font(LexaFont.display(32))
                .foregroundStyle(LexaColor.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
            if let ipa {
                Text(ipa).font(LexaFont.ui(13)).foregroundStyle(LexaColor.ink2).padding(.top, 2)
            }
            Text(meaning)
                .font(LexaFont.ui(15, weight: .semibold))
                .foregroundStyle(LexaColor.ink)
                .lineLimit(2)
                .padding(.top, 2)
            if let level { LevelTag(level: level).padding(.top, 6) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LexaColor.glass.opacity(0.75)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LexaColor.glass.opacity(0.9)))
                .shadow(color: Color(hex: 0x14171C).opacity(0.12), radius: 16, y: 8)
        }
    }
}

private struct LockScreenSample: View {
    let word: Word

    var body: some View {
        PhoneMockup { _ in
            VStack(spacing: 0) {
                Text(Date.now, format: .dateTime.day().month(.wide).weekday(.wide).locale(Locale(identifier: "tr_TR")))
                    .font(LexaFont.ui(14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("9:41")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, -4)
                WordWidgetCard(term: word.term, ipa: word.ipa, meaning: word.meaning, level: word.level)
                    .padding(.top, 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kilit ekranı kelime widget örneği: \(word.term), \(word.meaning)")
    }
}

private struct HomeScreenSample: View {
    private let spacing: CGFloat = 16

    var body: some View {
        PhoneMockup { innerWidth in
            let icon = (innerWidth - spacing * 3) / 4
            VStack(spacing: 18) {
                WordWidgetCard(term: "serendipity", ipa: "/ˌserənˈdɪpəti/", meaning: "mutlu tesadüf")
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(icon), spacing: spacing), count: 4), spacing: spacing) {
                    ForEach(SampleAppIcon.Kind.allCases, id: \.self) { kind in
                        SampleAppIcon(kind: kind, size: icon)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ana ekran kelime widget örneği: serendipity, mutlu tesadüf")
    }
}

/// iOS ana ekranını andıran sade uygulama ikonları (etiketsiz).
private struct SampleAppIcon: View {
    enum Kind: CaseIterable { case safari, photos, messages, notes, music, calendar, maps, health }

    let kind: Kind
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(background)
            glyph
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .shadow(color: Color(hex: 0x14171C).opacity(0.1), radius: 6, y: 3)
    }

    private var background: LinearGradient {
        let colors: [UInt32]
        switch kind {
        case .safari, .maps: colors = [0x7DBDF7, 0x3E8EF0]
        case .messages: colors = [0x7EDC8A, 0x45BF5C]
        case .music: colors = [0xF6A1AE, 0xEC7489]
        case .photos, .notes, .calendar, .health: colors = [0xFFFFFF, 0xF1F1F4]
        }
        return LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder
    private var glyph: some View {
        switch kind {
        case .safari: symbol("safari", .white)
        case .messages: symbol("message.fill", .white)
        case .music: symbol("music.note", .white)
        case .maps: symbol("mappin.and.ellipse", .white)
        case .calendar: symbol("calendar", Color(hex: 0xEC7489))
        case .health: symbol("heart.fill", Color(hex: 0xEF6F8A))
        case .photos: photosFlower
        case .notes: notesPage
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.46, weight: .regular))
            .foregroundStyle(color)
    }

    private var photosFlower: some View {
        let petals: [UInt32] = [0xF5B53F, 0xF08A3E, 0xE9576A, 0xB85FC9, 0x6E7FE0, 0x4BB4E6, 0x5CC77A, 0xB6D650]
        return ZStack {
            ForEach(petals.indices, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: petals[i]).opacity(0.85))
                    .frame(width: size * 0.2, height: size * 0.36)
                    .offset(y: -size * 0.15)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }

    private var notesPage: some View {
        VStack(spacing: 0) {
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0xFBDB6E), Color(hex: 0xF5C842)], startPoint: .top, endPoint: .bottom))
                .frame(height: size * 0.3)
            VStack(spacing: size * 0.14) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(Color(hex: 0xC9CBD2)).frame(height: 1)
                }
            }
            .padding(.top, size * 0.14)
            Spacer(minLength: 0)
        }
    }
}

private struct DictionarySample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "magnifyingglass"); Text("explore") }
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GlassDark())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("explore").font(LexaFont.display(32))
                    Spacer()
                    Label("Kaydet", systemImage: "bookmark").font(LexaFont.ui(13, weight: .semibold))
                }
                Text("/ɪkˈsplɔːr/").font(LexaFont.ui(13)).opacity(0.7)
                Text("keşfetmek, araştırmak").font(LexaFont.ui(16, weight: .semibold))
                Text("\"Explore new possibilities.\"").font(LexaFont.displayItalic(15)).opacity(0.75)
            }
            .modifier(GlassDark())
            HStack(spacing: 8) {
                ForEach([("bloom", "çiçeklenmek"), ("thrive", "gelişmek"), ("explore", "keşfetmek")], id: \.0) { w, m in
                    VStack(alignment: .leading) {
                        Text(w).font(LexaFont.display(17))
                        Text(m).font(.system(size: 11)).opacity(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.primary.opacity(0.07)))
                }
            }
        }
        .foregroundStyle(LexaColor.ink)
        .accessibilityHidden(true)
    }
}

private struct QuizSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kelime Alıştırması").font(LexaFont.ui(13, weight: .semibold)).opacity(0.75)
                Spacer()
                Text("3 / 5").font(LexaFont.ui(13, weight: .semibold))
            }
            Capsule().fill(.primary.opacity(0.12)).frame(height: 4)
                .overlay(alignment: .leading) { Capsule().fill(LexaColor.accent).frame(width: 160, height: 4) }
            (Text("Thrive").font(LexaFont.display(24)) + Text(" ne anlama gelir?").font(LexaFont.ui(17)))
            ForEach(Array(["Unutmak", "Gelişmek, başarılı olmak", "Beklemek", "Araştırmak"].enumerated()), id: \.offset) { i, text in
                HStack {
                    Text(["A", "B", "C", "D"][i]).font(LexaFont.ui(13, weight: .bold)).frame(width: 24)
                    Text(text).font(LexaFont.ui(15))
                    Spacer()
                    if i == 1 { Image(systemName: "checkmark") }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(i == 1 ? LexaColor.mint : .primary.opacity(0.06)))
            }
        }
        .foregroundStyle(LexaColor.ink)
        .modifier(GlassDark())
        .accessibilityHidden(true)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? LexaColor.accent : LexaColor.ink.opacity(0.3))
                    .frame(width: i == current ? 18 : 6, height: 6)
            }
        }
        .animation(LexaMotion.base, value: current)
        .accessibilityElement()
        .accessibilityLabel("Tanıtım, \(count) adımdan \(current + 1).")
    }
}

private struct LandingButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LexaFont.ui(16, weight: .semibold))
            .foregroundStyle(prominent ? LexaColor.onAccent : LexaColor.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(prominent ? (configuration.isPressed ? LexaColor.accentPress : LexaColor.accent) : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(prominent ? 0 : 0.2)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
