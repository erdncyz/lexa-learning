import Foundation

/// Uygulama ile widget arasında App Group üzerinden paylaşılan veri.
/// Widget ağ çağrısı yapmaz; uygulama her değişiklikte bu dosyayı günceller.
struct WidgetSnapshot: Codable, Equatable {
    struct Entry: Codable, Equatable, Hashable {
        let word: String
        let ipa: String?
        let meaning: String
        let level: String?
    }

    var entries: [Entry]
    var refreshMinutes: Int
    var languageName: String

    static let placeholder = WidgetSnapshot(
        entries: [Entry(word: "thrive", ipa: "/θraɪv/", meaning: "gelişmek, serpilmek", level: "B2")],
        refreshMinutes: 60,
        languageName: "İngilizce"
    )
}

enum SharedStore {
    static let appGroup = "group.com.lexa"
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
