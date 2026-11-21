import SwiftUI
import WidgetKit

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetSnapshot.Entry
}

/// Uygulamanın App Group'a yazdığı kelimeleri seçilen sıklıkta döndürür.
/// Ağ isteği yapılmaz → pil dostu ve anında.
struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: WidgetSnapshot.placeholder.entries[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        let snapshot = SharedStore.read() ?? .placeholder
        let word = snapshot.current(at: .now)?.entry ?? WidgetSnapshot.placeholder.entries[0]
        completion(WordEntry(date: .now, word: word))
    }

    /// Uygulamanın yazdığı takvimi izler; uygulama da Bugün kartında aynı hesabı (`current(at:)`) kullanır.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let snapshot = SharedStore.read() ?? .placeholder
        let now = Date()
        guard let current = snapshot.current(at: now) else {
            completion(Timeline(entries: [placeholder(in: context)], policy: .atEnd))
            return
        }
        var timeline = [WordEntry(date: now, word: current.entry)]
        for step in 1..<12 {
            let date = current.start.addingTimeInterval(TimeInterval(step) * snapshot.interval)
            if let next = snapshot.current(at: date) {
                timeline.append(WordEntry(date: date, word: next.entry))
            }
        }
        completion(Timeline(entries: timeline, policy: .atEnd))
    }
}

struct LexaWidgetView: View {
    let entry: WordEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.word.word)
                    .font(.custom("Newsreader", size: 20).weight(.semibold))
                    .widgetAccentable()
                    .minimumScaleFactor(0.7)
                if let ipa = entry.word.ipa {
                    Text(ipa).font(.system(size: 11)).opacity(0.8)
                }
                Text(entry.word.meaning).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("\(entry.word.word) · \(entry.word.meaning)")
        case .systemMedium:
            HStack(alignment: .top) {
                wordStack(size: 34)
                Spacer()
                if let level = entry.word.level {
                    Text(level)
                        .font(.custom("IBM Plex Sans", size: 12).weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.6)))
                }
            }
        default:
            wordStack(size: 26)
        }
    }

    private func wordStack(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("GÜNÜN KELİMESİ")
                .font(.custom("IBM Plex Sans", size: 10).weight(.bold))
                .tracking(1)
                .foregroundStyle(LexaColor.accent)
            Text(entry.word.word)
                .font(.custom("Newsreader", size: size).weight(.semibold))
                .foregroundStyle(LexaColor.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if let ipa = entry.word.ipa {
                Text(ipa).font(.custom("IBM Plex Sans", size: 12)).foregroundStyle(LexaColor.ink2)
            }
            Spacer(minLength: 0)
            Text(entry.word.meaning)
                .font(.custom("IBM Plex Sans", size: 14).weight(.semibold))
                .foregroundStyle(LexaColor.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LexaWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LexaWordWidget", provider: WordProvider()) { entry in
            LexaWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(hex: 0xF3E1E8), Color(hex: 0xF4EEDF), Color(hex: 0xDCEEE9)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Günün Kelimesi")
        .description("Seçtiğin sıklıkta yeni bir kelime göster.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LexaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LexaWordWidget()
    }
}

#Preview(as: .systemSmall) {
    LexaWordWidget()
} timeline: {
    WordEntry(date: .now, word: WidgetSnapshot.placeholder.entries[0])
}
