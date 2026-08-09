import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The small HTTP response surface SoCo needs from its transport.
public struct HTTPResponse {
    public let statusCode: Int
    public let headers: [AnyHashable: Any]
    public let data: Data

    public init(statusCode: Int, headers: [AnyHashable: Any], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }

    /// Interpret the response bytes as UTF-8 text, matching requests' normal
    /// behavior for the Sonos XML endpoints used by SoCo.
    public var text: String { String(data: data, encoding: .utf8) ?? "" }
}

/// Injectable synchronous HTTP transport used throughout SoCoKit.
///
/// Keeping this as a protocol is important for two reasons: it makes the port's
/// protocol behavior directly testable without a speaker, and it gives apps the
/// option to provide a transport with custom networking or logging behavior.
public protocol HTTPClient: AnyObject {
    func request(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) throws -> HTTPResponse
}

/// A lock-protected result box used to bridge URLSession's callback API to the
/// synchronous HTTP interface used by the original SoCo code.
///
/// A reference box is used instead of mutating a captured local variable. That
/// distinction matters under Swift 6's strict concurrency checking: URLSession
/// completion handlers are concurrently executing closures, so mutating a local
/// capture would be diagnosed as a data race even though the semaphore makes the
/// read happen after the callback.
private final class URLSessionResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<HTTPResponse, Error>?

    func store(_ result: Result<HTTPResponse, Error>) {
        lock.lock()
        value = result
        lock.unlock()
    }

    func load() -> Result<HTTPResponse, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Default HTTP implementation backed by URLSession.
public final class URLSessionHTTPClient: HTTPClient {
    public static let shared = URLSessionHTTPClient()

    public init() {}

    public func request(
        method: String,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = SoCoConfig.requestTimeout
    ) throws -> HTTPResponse {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.httpBody = body
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = URLSessionResultBox()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                resultBox.store(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                resultBox.store(.failure(SoCoError.unknown("Missing HTTP response")))
                return
            }

            resultBox.store(
                .success(
                    HTTPResponse(
                        statusCode: httpResponse.statusCode,
                        headers: httpResponse.allHeaderFields,
                        data: data ?? Data()
                    )
                )
            )
        }
        task.resume()

        // URLRequest already carries the requested timeout. The small extra
        // second here prevents the synchronous bridge itself from waiting
        // indefinitely if URLSession fails to call its completion handler.
        if semaphore.wait(timeout: .now() + timeout + 1) == .timedOut {
            task.cancel()
            throw SoCoError.timeout
        }

        guard let result = resultBox.load() else {
            throw SoCoError.unknown("URLSession completed without a result")
        }
        return try result.get()
    }
}
