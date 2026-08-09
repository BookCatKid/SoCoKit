import Foundation
@testable import SoCoKit
#if os(Linux)
import Glibc
#else
import Darwin
#endif

func systemBind(
    _ socket: Int32,
    _ address: UnsafePointer<sockaddr>,
    _ length: socklen_t
) -> Int32 {
    #if os(Linux)
    Glibc.bind(socket, address, length)
    #else
    Darwin.bind(socket, address, length)
    #endif
}

final class MockHTTPClient: HTTPClient {
    struct Request {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data?
        let timeout: TimeInterval
    }

    var requests: [Request] = []
    var queuedResponses: [Result<HTTPResponse, Error>] = []

    func enqueue(statusCode: Int = 200, headers: [AnyHashable: Any] = [:], text: String) {
        queuedResponses.append(.success(HTTPResponse(statusCode: statusCode, headers: headers, data: Data(text.utf8))))
    }

    func enqueue(error: Error) {
        queuedResponses.append(.failure(error))
    }

    func request(method: String, url: URL, headers: [String: String], body: Data?, timeout: TimeInterval) throws -> HTTPResponse {
        requests.append(Request(method: method, url: url, headers: headers, body: body, timeout: timeout))
        guard !queuedResponses.isEmpty else {
            throw SoCoError.unknown("MockHTTPClient has no queued response")
        }
        return try queuedResponses.removeFirst().get()
    }
}

func fixtureText(_ relativePath: String) throws -> String {
    let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}


func soapResponse(
    action: String,
    serviceType: String = "AVTransport",
    fields: [(String, String)] = []
) -> String {
    let body = fields.map { name, value in
        "<\(name)>\(xmlEscape(value))</\(name)>"
    }.joined()
    return """
    <?xml version="1.0" encoding="utf-8"?>
    <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <s:Body><u:\(action)Response xmlns:u="urn:schemas-upnp-org:service:\(serviceType):1">\(body)</u:\(action)Response></s:Body>
    </s:Envelope>
    """
}

func requestBodyText(_ request: MockHTTPClient.Request) -> String {
    String(data: request.body ?? Data(), encoding: .utf8) ?? ""
}
