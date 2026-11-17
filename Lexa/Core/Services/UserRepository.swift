import Foundation
import FirebaseFirestore

protocol UserRepositing: Sendable {
    func load(uid: String) async throws -> UserData?
    func save(_ data: UserData, uid: String) async throws
}

/// Firestore: `users/{uid}` — kullanıcı başına tek doküman.
/// Kayıtlar 1,5 sn gecikmeyle birleştirilerek yazılır (bkz. AppState), böylece
/// ücretsiz kotadaki günlük 20.000 yazma limiti rahatça yeter.
final class FirestoreUserRepository: UserRepositing {
    private var db: Firestore { Firestore.firestore() }

    func load(uid: String) async throws -> UserData? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UserData.self)
    }

    func save(_ data: UserData, uid: String) async throws {
        try db.collection("users").document(uid).setData(from: data)
    }
}

/// Cihazdaki yerel kopya (misafir kullanıcı + çevrim dışı önbellek).
enum LocalStore {
    private static func url(for key: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lexa-\(key).json")
    }

    static func load(key: String) -> UserData? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? JSONDecoder().decode(UserData.self, from: data)
    }

    static func save(_ value: UserData, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    static func remove(key: String) {
        try? FileManager.default.removeItem(at: url(for: key))
    }

    /// Hangi oturumun açık olduğu (misafir / uid)
    static var lastSessionKey: String? {
        get { UserDefaults.standard.string(forKey: "lexa.session") }
        set { UserDefaults.standard.set(newValue, forKey: "lexa.session") }
    }
}
