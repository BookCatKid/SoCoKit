import Foundation

/// Common cache interface used by UPnP service calls.
public protocol SoCoCache: AnyObject {
    var enabled: Bool { get set }
    func put(_ value: Any, keyParts: [AnyHashable], timeout: TimeInterval?)
    func get(keyParts: [AnyHashable]) -> Any?
    func delete(keyParts: [AnyHashable])
    func clear()
}

/// A no-op cache. SoCo returns this when caching is globally disabled.
public final class NullCache: SoCoCache {
    public var enabled = false
    public init() {}
    public func put(_ value: Any, keyParts: [AnyHashable], timeout: TimeInterval? = nil) {}
    public func get(keyParts: [AnyHashable]) -> Any? { nil }
    public func delete(keyParts: [AnyHashable]) {}
    public func clear() {}
}

/// A simple in-memory cache whose entries expire after a configurable interval.
///
/// The Python implementation serializes argument tuples with pickle to obtain a
/// stable key even when arguments contain mutable containers and Unicode. Swift
/// service arguments are already normalized before reaching this cache; the key
/// builder still preserves type information via `String(reflecting:)`.
public final class TimedCache: SoCoCache {
    private struct Entry {
        let expires: Date
        let value: Any
    }

    private var storage: [String: Entry] = [:]
    private let lock = NSLock()

    public var defaultTimeout: TimeInterval
    public var enabled = true

    public init(defaultTimeout: TimeInterval = 0) {
        self.defaultTimeout = defaultTimeout
    }

    /// Generate a unique representation of cache key components.
    public static func makeKey(_ parts: [AnyHashable]) -> String {
        parts.map { String(reflecting: $0) }.joined(separator: "|")
    }

    public func put(_ value: Any, keyParts: [AnyHashable], timeout: TimeInterval? = nil) {
        guard enabled else { return }
        let ttl = timeout ?? defaultTimeout
        // Python SoCo stores zero-timeout values but they are immediately expired.
        // Avoiding the write is behaviorally equivalent and cheaper.
        guard ttl > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        storage[Self.makeKey(keyParts)] = Entry(expires: Date().addingTimeInterval(ttl), value: value)
    }

    public func get(keyParts: [AnyHashable]) -> Any? {
        guard enabled else { return nil }
        let key = Self.makeKey(keyParts)
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key] else { return nil }
        if entry.expires >= Date() { return entry.value }
        // An expired item is present - delete it.
        storage.removeValue(forKey: key)
        return nil
    }

    public func delete(keyParts: [AnyHashable]) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: Self.makeKey(keyParts))
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

/// Factory equivalent of Python SoCo's `Cache` class.
public enum Cache {
    public static func make(defaultTimeout: TimeInterval = 0) -> SoCoCache {
        SoCoConfig.cacheEnabled ? TimedCache(defaultTimeout: defaultTimeout) : NullCache()
    }
}
