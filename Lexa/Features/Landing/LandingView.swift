import SwiftUI

/// Tanıtım slaytları + giriş seçenekleri (koyu tema).
struct LandingView: View {
    let app: AppState
    @State private var page = 0
    @State private var authScreen: AuthScreen?

    private let slideCount = 4

    var body: some View {
        ZStack {
            LandingBackground()
            VStack(spacing: 0) {
                HStack {
                    Text("LEXA").font(LexaFont.ui(14, weight: .bold)).tracking(2)
                    Spacer()
                    if page < slideCount {
                        Button("Atla") { withAnimation(LexaMotion.base) { page = slideCount } }
                            .font(LexaFont.ui(15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, LexaSpacing.gutter)
                .padding(.top, LexaSpacing.s)

                TabView(selection: $page) {
                    IntroSlide(title: "Kilit ekranında yeni bir kelime.",
                               lead: "Seçtiğin dilde yeni kelimeler keşfet, öğrenmeyi günlük hayatının bir parçası haline getir.") {
                        LockScreenSample(word: app.words.word(id: "en:thrive") ?? .preview)
                    }.tag(0)
                    IntroSlide(title: "Kelimeler hep ana ekranında.",
                               lead: "Widget'ını ana ekranına ekle, seçtiğin dilde yeni kelimeler gün boyu seninle olsun.") {
                        HomeScreenSample()
                    }.tag(1)
                    IntroSlide(title: "Keşfet, öğren, kaydet.",
                               lead: "Merak ettiğin kelimeleri ara, anlamlarını öğren ve kendi kelime kartlarını oluştur.") {
                        DictionarySample()
                    }.tag(2)
                    IntroSlide(title: "Öğrendiklerini pekiştir.",
                               lead: "Kısa testlerle kelimelerini tekrar et, öğrendiklerini kalıcı hale getir.") {
                        QuizSample()
                    }.tag(3)
                    authOptions.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if page < slideCount {
                    PageDots(count: slideCount, current: page)
                        .padding(.bottom, LexaSpacing.l)
                    Button("Devam et") { withAnimation(LexaMotion.base) { page += 1 } }
                        .buttonStyle(LandingButtonStyle(prominent: true))
                        .padding(.horizontal, LexaSpacing.gutter)
                        .padding(.bottom, LexaSpacing.l)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $authScreen) { screen in
            AuthFlowView(app: app, initial: screen) { authScreen = nil }
                .preferredColorScheme(.light)
        }
    }

    private var authOptions: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.l) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("Hazır mısın?").font(LexaFont.ui(34, weight: .bold))
                Text("Hesabınla giriş yap ya da yeni bir hesap oluştur.").font(LexaFont.ui(16)).foregroundStyle(.white.opacity(0.75))
            }
            .foregroundStyle(.white)
            Spacer()
            VStack(spacing: LexaSpacing.m) {
                Button { authScreen = .login } label: { Label("Giriş yap", systemImage: "person") }
                    .buttonStyle(LandingButtonStyle(prominent: true))
                Button("Hesap oluştur") { authScreen = .signup(keepProgress: false) }
                    .buttonStyle(LandingButtonStyle(prominent: false))
                Button("Hesapsız devam") { app.continueAsGuest() }
                    .font(LexaFont.ui(16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
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
    var body: some View {
        ZStack {
            LexaColor.wall
            Circle().fill(Color(hex: 0xC86A8E).opacity(0.35)).frame(width: 340).blur(radius: 90).offset(x: -140, y: -260)
            Circle().fill(Color(hex: 0xE5C46B).opacity(0.22)).frame(width: 300).blur(radius: 90).offset(x: 160, y: -60)
            Circle().fill(Color(hex: 0x2F8A86).opacity(0.35)).frame(width: 360).blur(radius: 100).offset(x: -40, y: 320)
        }
        .ignoresSafeArea()
    }
}

private struct IntroSlide<Stage: View>: View {
    let title: String
    let lead: String
    @ViewBuilder let stage: Stage

    var body: some View {
        VStack(alignment: .leading, spacing: LexaSpacing.xxl) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(LexaFont.ui(30, weight: .bold)).foregroundStyle(.white)
                Text(lead).font(LexaFont.ui(16)).foregroundStyle(.white.opacity(0.72))
            }
            .padding(.top, 40)
            stage.frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LexaSpacing.gutter)
    }
}

private struct GlassDark: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.14)))
    }
}

private struct LockScreenSample: View {
    let word: Word

    var body: some View {
        VStack(spacing: 4) {
            Text("9:41").font(.system(size: 64, weight: .semibold, design: .rounded))
            Text(Date.now, format: .dateTime.day().month(.wide).weekday(.wide).locale(Locale(identifier: "tr_TR")))
                .font(LexaFont.ui(14, weight: .medium))
            VStack(alignment: .leading, spacing: 4) {
                Text("GÜNÜN KELİMESİ").font(LexaFont.ui(11, weight: .bold)).tracking(1.4).opacity(0.7)
                Text(word.term).font(LexaFont.display(44))
                if let ipa = word.ipa { Text(ipa).font(LexaFont.ui(14)).opacity(0.75) }
                Text(word.meaning).font(LexaFont.ui(16, weight: .semibold))
                LevelTag(level: word.level).colorScheme(.light).padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassDark())
            .padding(.top, 12)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeScreenSample: View {
    private let apps: [(String, String, [Color])] = [
        ("safari", "Safari", [Color(hex: 0x5AC8FA), Color(hex: 0x007AFF)]),
        ("photo", "Fotoğraflar", [Color(hex: 0xFF6482), Color(hex: 0xFF2D55)]),
        ("message", "Mesajlar", [Color(hex: 0x34C759), Color(hex: 0x30B350)]),
        ("note.text", "Notlar", [Color(hex: 0xFF9F0A), Color(hex: 0xFF6B00)])
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Günün kelimesi").font(LexaFont.ui(11, weight: .bold)).opacity(0.7)
                Text("serendipity").font(LexaFont.display(24)).minimumScaleFactor(0.7).lineLimit(1)
                Text("/ˌserənˈdɪpəti/").font(LexaFont.ui(12)).opacity(0.7)
                Spacer(minLength: 0)
                Text("mutlu tesadüf").font(LexaFont.ui(14, weight: .semibold))
            }
            .frame(width: 150, height: 150, alignment: .topLeading)
            .modifier(GlassDark())
            LazyVGrid(columns: [GridItem(.fixed(60)), GridItem(.fixed(60))], spacing: 14) {
                ForEach(apps, id: \.1) { symbol, name, colors in
                    VStack(spacing: 4) {
                        Image(systemName: symbol)
                            .font(.system(size: 22))
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)))
                        Text(name).font(.system(size: 10)).lineLimit(1)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ana ekran kelime widget örneği: serendipity, mutlu tesadüf")
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
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                }
            }
        }
        .foregroundStyle(.white)
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
            Capsule().fill(.white.opacity(0.15)).frame(height: 4)
                .overlay(alignment: .leading) { Capsule().fill(LexaColor.mint).frame(width: 160, height: 4) }
            (Text("Thrive").font(LexaFont.display(24)) + Text(" ne anlama gelir?").font(LexaFont.ui(17)))
            ForEach(Array(["Unutmak", "Gelişmek, başarılı olmak", "Beklemek", "Araştırmak"].enumerated()), id: \.offset) { i, text in
                HStack {
                    Text(["A", "B", "C", "D"][i]).font(LexaFont.ui(13, weight: .bold)).frame(width: 24)
                    Text(text).font(LexaFont.ui(15))
                    Spacer()
                    if i == 1 { Image(systemName: "checkmark") }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(i == 1 ? LexaColor.mint.opacity(0.3) : .white.opacity(0.07)))
            }
        }
        .foregroundStyle(.white)
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
                    .fill(.white.opacity(i == current ? 0.95 : 0.35))
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
            .foregroundStyle(prominent ? LexaColor.wall : .white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(prominent ? Color.white.opacity(configuration.isPressed ? 0.75 : 0.9) : Color.white.opacity(configuration.isPressed ? 0.2 : 0.12)))
            .overlay(Capsule().strokeBorder(.white.opacity(prominent ? 0 : 0.25)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
