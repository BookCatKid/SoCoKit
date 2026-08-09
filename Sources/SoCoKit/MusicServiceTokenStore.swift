import Foundation

/// This module implements token stores for music services.
///
/// Applications may provide their own token store depending on how authentication
/// secrets should be persisted, or use `JSONFileTokenStore`, which stores them in a
/// JSON file in the user's application-support/configuration directory.
public protocol MusicServiceTokenStore: AnyObject {
    var tokenCollection: String { get }
    func saveTokenPair(musicServiceID: Int, householdID: String, tokenPair: (String, String)) throws
    func loadTokenPair(musicServiceID: Int, householdID: String) throws -> (String, String)
    func hasToken(musicServiceID: Int, householdID: String) -> Bool
}

/// In-memory token store useful for ephemeral applications and tests.
public final class MemoryMusicServiceTokenStore: MusicServiceTokenStore {
    public let tokenCollection: String
    private let lock = NSLock()
    private var values: [String: (String, String)] = [:]

    public init(tokenCollection: String = "default") { self.tokenCollection = tokenCollection }
    private func key(_ musicServiceID: Int, _ householdID: String) -> String { "\(musicServiceID)#\(householdID)" }

    public func saveTokenPair(musicServiceID: Int, householdID: String, tokenPair: (String, String)) throws {
        lock.lock(); defer { lock.unlock() }
        values[key(musicServiceID, householdID)] = tokenPair
    }
    public func loadTokenPair(musicServiceID: Int, householdID: String) throws -> (String, String) {
        lock.lock(); defer { lock.unlock() }
        guard let pair = values[key(musicServiceID, householdID)] else {
            throw SoCoError.musicServiceAuth("No token stored for music service \(musicServiceID), household \(householdID)")
        }
        return pair
    }
    public func hasToken(musicServiceID: Int, householdID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return values[key(musicServiceID, householdID)] != nil
    }
}

/// JSON-file implementation of the music-service token store.
public final class JSONFileTokenStore: MusicServiceTokenStore {
    public let fileURL: URL
    public let tokenCollection: String
    private let lock = NSRecursiveLock()
    private var store: [String: [String: [String]]] = [:]

    public init(fileURL: URL, tokenCollection: String = "default") throws {
        self.fileURL = fileURL
        self.tokenCollection = tokenCollection
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            if !data.isEmpty {
                store = try JSONDecoder().decode([String: [String: [String]]].self, from: data)
            }
        }
    }

    /// Load from the platform-appropriate application support/configuration location.
    /// This is the Swift equivalent of Python SoCo's `appdirs.user_config_dir`.
    public static func fromConfigFile(tokenCollection: String = "default") throws -> JSONFileTokenStore {
        let manager = FileManager.default
        let base: URL
        #if os(Linux)
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg, isDirectory: true)
        } else {
            base = manager.homeDirectoryForCurrentUser.appendingPathComponent(".config", isDirectory: true)
        }
        #else
        base = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        #endif
        let directory = base.appendingPathComponent("SoCo", isDirectory: true)
        return try JSONFileTokenStore(fileURL: directory.appendingPathComponent("token_store.json"), tokenCollection: tokenCollection)
    }

    private func key(_ musicServiceID: Int, _ householdID: String) -> String {
        // JSON object keys must be strings. Upstream SoCo uses this exact separator.
        "\(musicServiceID)#\(householdID)"
    }

    /// Save the complete token collection to the configured JSON file.
    ///
    /// Upstream SoCo exposes `save_collection()` publicly; keep that surface
    /// available rather than only persisting as a side effect of saveTokenPair.
    public func saveCollection() throws {
        lock.lock(); defer { lock.unlock() }
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(store)
        try data.write(to: fileURL, options: .atomic)
    }

    public func saveTokenPair(musicServiceID: Int, householdID: String, tokenPair: (String, String)) throws {
        lock.lock(); defer { lock.unlock() }
        var collection = store[tokenCollection] ?? [:]
        collection[key(musicServiceID, householdID)] = [tokenPair.0, tokenPair.1]
        store[tokenCollection] = collection
        try saveCollection()
    }

    public func loadTokenPair(musicServiceID: Int, householdID: String) throws -> (String, String) {
        lock.lock(); defer { lock.unlock() }
        guard let pair = store[tokenCollection]?[key(musicServiceID, householdID)], pair.count == 2 else {
            throw SoCoError.musicServiceAuth("No token stored for music service \(musicServiceID), household \(householdID)")
        }
        return (pair[0], pair[1])
    }

    public func hasToken(musicServiceID: Int, householdID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return store[tokenCollection]?[key(musicServiceID, householdID)]?.count == 2
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

// Python/source-compatibility spelling. Swift style keeps the implementation
// name as `JSONFileTokenStore`, while SoCo calls the class `JsonFileTokenStore`.
public typealias JsonFileTokenStore = JSONFileTokenStore

// The Python base class is represented by a Swift protocol so applications can
// supply their own token persistence without subclassing a concrete base type.
public typealias TokenStoreBase = MusicServiceTokenStore
