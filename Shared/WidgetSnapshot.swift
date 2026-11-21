import Foundation

/// Uygulama ile widget arasında App Group üzerinden paylaşılan veri.
/// Widget ağ çağrısı yapmaz; uygulama her değişiklikte bu dosyayı günceller.
///
/// `entries` bir **takvimdir**: her kelimenin gösterilmeye başladığı an (`start`) bellidir.
/// Uygulama (Bugün kartı) ve widget hangi kelimenin gösterileceğini aynı fonksiyonla
/// (`current(at:)`) hesaplar; böylece widget'a basınca uygulamada aynı kelime görünür.
struct WidgetSnapshot: Codable, Equatable {
    struct Entry: Codable, Equatable, Hashable {
        let word: String
        let ipa: String?
        let meaning: String
        let level: String?
        /// Kelime kimliği (ör. "en:thrive") — uygulama takvimdeki kelimeyi bulmak için kullanır.
        var id: String? = nil
        /// Bu kelimenin gösterilmeye başladığı an.
        var start: Date? = nil
    }

    var entries: [Entry]
    var refreshMinutes: Int
    var languageName: String
    /// Takvimin hangi ayarlarla oluşturulduğu (dil|seviye|sınav|sıklık). Ayar değişince yeni takvim kurulur.
    var scheduleKey: String? = nil

    var interval: TimeInterval { TimeInterval(max(refreshMinutes, 15) * 60) }

    /// Verilen anda gösterilecek kelime ve o kelimenin başladığı an.
    /// Takvim biterse son kelimeden itibaren aynı aralıkla listede dönmeye devam eder.
    func current(at date: Date) -> (entry: Entry, start: Date)? {
        guard !entries.isEmpty else { return nil }
        let dated = entries.compactMap { entry in entry.start.map { (entry, $0) } }
        guard let first = dated.first else {
            // Eski biçim (zaman bilgisi yok): zaman dilimine göre döndür.
            let slot = Int(date.timeIntervalSince1970 / interval)
            return (entries[slot % entries.count], Date(timeIntervalSince1970: TimeInterval(slot) * interval))
        }
        if date < first.1 { return first }
        let lastIndex = dated.count - 1
        if let index = dated.lastIndex(where: { $0.1 <= date }), index < lastIndex {
            return dated[index]
        }
        let (last, lastStart) = dated[lastIndex]
        let steps = Int(date.timeIntervalSince(lastStart) / interval)
        guard steps > 0 else { return (last, lastStart) }
        return (dated[(lastIndex + steps) % dated.count].0, lastStart.addingTimeInterval(TimeInterval(steps) * interval))
    }

    static let placeholder = WidgetSnapshot(
        entries: [Entry(word: "thrive", ipa: "/θraɪv/", meaning: "gelişmek, serpilmek", level: "B2")],
        refreshMinutes: 60,
        languageName: "İngilizce"
    )
}

enum SharedStore {
    static let appGroup = "group.com.lexa-learning.app"
    private static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
