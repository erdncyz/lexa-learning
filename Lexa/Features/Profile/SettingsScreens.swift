import SwiftUI
import UserNotifications

// MARK: - Bildirimler

@MainActor
@Observable
final class NotificationsViewModel {
    private let app: AppState
    private(set) var permissionDenied = false
    private(set) var isRequesting = false

    init(app: AppState) {
        self.app = app
    }

    var isOn: Bool { app.data.notifyOn }

    var time: Date {
        Calendar.current.date(from: DateComponents(hour: app.data.notifyHour, minute: app.data.notifyMinute)) ?? .now
    }

    func refreshPermission() async {
        let status = await app.notifications.authorizationStatus()
        permissionDenied = status == .denied
        if permissionDenied, app.data.notifyOn {
            app.update { $0.notifyOn = false }
        }
    }

    func setOn(_ on: Bool) async {
        guard on else {
            app.update { $0.notifyOn = false }
            app.rescheduleNotification()
            return
        }
        isRequesting = true
        let granted = await app.notifications.requestPermission()
        isRequesting = false
        permissionDenied = !granted
        app.update { $0.notifyOn = granted }
        app.rescheduleNotification()
    }

    func setTime(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        app.update {
            $0.notifyHour = parts.hour ?? 9
            $0.notifyMinute = parts.minute ?? 0
        }
        app.rescheduleNotification()
    }
}

struct NotificationsView: View {
    @State private var viewModel: NotificationsViewModel
    @Environment(\.openURL) private var openURL

    init(app: AppState) {
        _viewModel = State(initialValue: NotificationsViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                PageHeader(title: "Bildirimler")
                VStack(alignment: .leading, spacing: LexaSpacing.s) {
                    Toggle(isOn: Binding(get: { viewModel.isOn }, set: { on in Task { await viewModel.setOn(on) } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Günün Kelimesi").font(LexaFont.ui(17, weight: .semibold)).foregroundStyle(LexaColor.ink)
                            Text("Her gün seçtiğin saatte yeni bir kelimeyle tanış.").font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
                        }
                    }
                    .tint(LexaColor.accent)
                    .disabled(viewModel.isRequesting)

                    if viewModel.permissionDenied && !viewModel.isOn {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Bildirim izni kapalı. Günün kelimesi gönderilemez.")
                                .font(LexaFont.ui(14)).foregroundStyle(LexaColor.dangerInk)
                            Button("Ayarları Aç") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .font(LexaFont.ui(14, weight: .semibold))
                        }
                    }
                }
                .lexaCard(padding: 18)

                DatePicker(selection: Binding(get: { viewModel.time }, set: { viewModel.setTime($0) }), displayedComponents: .hourAndMinute) {
                    Text("Bildirim Saati").font(LexaFont.ui(17, weight: .semibold)).foregroundStyle(LexaColor.ink)
                }
                .environment(\.locale, Locale(identifier: "tr_TR"))
                .disabled(!viewModel.isOn)
                .opacity(viewModel.isOn ? 1 : 0.55)
                .lexaCard(padding: 18)

                Text("Günün kelimesi bildirimi, seçtiğin öğrenme diline göre her gün belirlediğin saatte gönderilir.")
                    .font(LexaFont.ui(14)).foregroundStyle(LexaColor.ink2)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .lexaScreenBackground()
        .task { await viewModel.refreshPermission() }
    }
}

// MARK: - Yardım

struct HelpView: View {
    private struct FAQ: Identifiable {
        let id: String
        let question: String
        let answer: String
    }

    private let items: [FAQ] = [
        FAQ(id: "how", question: "LEXA nasıl çalışır?", answer: "Her gün bir kelimeyle karşılaşırsın. Keşfet’te kelime kaydedip kendi desteni oluşturabilir, Pratik’te günlük test ve alıştırmalarla tekrar edebilirsin. Widget, seçtiğin kelimeyi kilit veya ana ekranda da gösterir."),
        FAQ(id: "widget", question: "Widget’ı nasıl ekleyebilirim?", answer: "Widget’lar sekmesinde Nasıl Eklenir? adımlarını izle. Kilit ekranı ve ana ekran için ayrı adımlar vardır. iOS yenilemeyi pil ve sistem yüküne göre erteleyebilir; seçtiğin süre bir hedeftir, kelime her zaman tam o dakikada değişmeyebilir."),
        FAQ(id: "refresh", question: "Kelimeler ne sıklıkla değişir?", answer: "Sıklığı Widget Ayarları’ndan seçersin: 30 dakika, 1 saat, 3 saat veya 1 gün. iOS bu yenilemeyi sınırlayabildiği için kelime, seçtiğin aralıktan biraz geç de değişebilir."),
        FAQ(id: "lang", question: "Öğrenme dilimi değiştirebilir miyim?", answer: "Evet. Profil’de Öğrenme Tercihlerim altından dili değiştirirsin. İngilizce, Almanca ve İspanyolca, Widget’lar ekranıyla aynı kaydı kullanır. Almanca veya İspanyolcaya geçince sınav amacı taşınmaz."),
        FAQ(id: "saved", question: "Kaydettiğim kelimeleri nerede bulabilirim?", answer: "Kaydettiğin kelimeler Keşfet’teki Kelimelerim bölümündedir. Kendi oluşturduğun desteler Destelerim altında durur."),
        FAQ(id: "notify", question: "Günün kelimesi bildirimlerini nasıl açabilirim?", answer: "Profil’den Bildirimler’e girip Günün Kelimesi anahtarını aç. Saati Bildirim Saati kartından seçersin. Telefonun bildirim izni kapalıysa anahtar açık görünmez.")
    ]

    @State private var open: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                PageHeader(title: "Yardım ve Destek", subtitle: "LEXA hakkında merak ettiklerinin cevapları burada.")
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle("Sık Sorulan Sorular").padding(.bottom, LexaSpacing.s)
                    ForEach(items) { item in
                        DisclosureGroup(isExpanded: Binding(
                            get: { open.contains(item.id) },
                            set: { isOpen in if isOpen { open.insert(item.id) } else { open.remove(item.id) } }
                        )) {
                            Text(item.answer)
                                .font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, LexaSpacing.s)
                        } label: {
                            Text(item.question).font(LexaFont.ui(16, weight: .semibold)).foregroundStyle(LexaColor.ink)
                        }
                        .tint(LexaColor.ink2)
                        .padding(.vertical, 10)
                        if item.id != items.last?.id { Divider().overlay(LexaColor.line.opacity(0.5)) }
                    }
                }
                .lexaCard(padding: 18)

                VStack(alignment: .leading, spacing: LexaSpacing.s) {
                    SectionTitle("Yardıma mı ihtiyacın var?")
                    Text("Yanıtını bulamadığın bir konu varsa bizimle iletişime geçebilirsin.")
                        .font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                    // TODO: Destek e-posta adresini belirle.
                    Link("Bize Ulaş", destination: URL(string: "mailto:destek@lexa.app")!)
                        .buttonStyle(.lexaPrimary)
                        .padding(.top, 4)
                }
                .lexaCard(padding: 18)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .lexaScreenBackground()
    }
}

// MARK: - Hakkında

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LexaSpacing.l) {
                PageHeader(title: "Hakkında")
                VStack(spacing: 6) {
                    Image("LexaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .accessibilityLabel("LEXA logosu")
                    Text("LEXA").font(LexaFont.ui(24, weight: .bold)).foregroundStyle(LexaColor.ink)
                    Text("Kelimelerle her gün biraz daha ileri.").font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    fact("Uygulama Adı", "LEXA")
                    Divider().overlay(LexaColor.line.opacity(0.5))
                    fact("Sürüm", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Divider().overlay(LexaColor.line.opacity(0.5))
                    fact("Platform", "iOS")
                }
                .lexaCard(padding: 18)

                Text("LEXA; yeni kelimeler keşfetmeni, öğrendiklerini tekrar etmeni ve kelimeleri iPhone widget'ların aracılığıyla günlük hayatına taşımanı sağlayan bir kelime öğrenme uygulamasıdır.")
                    .font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
                    .lexaCard(padding: 18)

                Text("Kelime seviyeleri: CEFR-J Wordlist (Tono Laboratory, TUFS) ve Octanove Vocabulary Profile C1/C2 (CC BY-SA 4.0). Akademik kelimeler: New Academic Word List — Browne, Culligan ve Phillips (CC BY-SA 4.0). Sözlük verileri: Free Dictionary API, MyMemory. Yazı tipleri: Newsreader, IBM Plex Sans (SIL OFL).")
                    .font(LexaFont.ui(12)).foregroundStyle(LexaColor.ink2)
            }
            .padding(.horizontal, LexaSpacing.gutter)
            .padding(.vertical, LexaSpacing.s)
        }
        .lexaScreenBackground()
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(LexaFont.ui(15)).foregroundStyle(LexaColor.ink2)
            Spacer()
            Text(value).font(LexaFont.ui(15, weight: .semibold)).foregroundStyle(LexaColor.ink)
        }
        .padding(.vertical, 12)
    }
}
