import Foundation

public enum SoCoError: Error, LocalizedError, Equatable {
    case unknown(String)
    case invalidArgument(String)
    case missingArgument(String)
    case unsupported(String)
    case slaveOperation(String)
    case notVisible(String)
    case didlMetadata(String)
    case musicService(String)
    case musicServiceAuth(String)
    case eventParse(String)
    case xml(String)
    case http(status: Int, body: String)
    case upnp(code: String, description: String, xml: String)
    case timeout
    case noDeviceFound

    public var errorDescription: String? {
        switch self {
        case .unknown(let s), .invalidArgument(let s), .missingArgument(let s), .unsupported(let s),
             .slaveOperation(let s), .notVisible(let s), .didlMetadata(let s), .musicService(let s),
             .musicServiceAuth(let s), .eventParse(let s), .xml(let s): return s
        case .http(let status, let body): return "HTTP \(status): \(body)"
        case .upnp(let code, let description, _): return "UPnP Error \(code): \(description)"
        case .timeout: return "The operation timed out"
        case .noDeviceFound: return "No Sonos device was found"
        }
    }
}

public struct SoapFault: Error, CustomStringConvertible, Equatable {
    public let faultCode: String
    public let faultString: String
    public let detailXML: String?
    public init(faultCode: String, faultString: String, detailXML: String? = nil) {
        self.faultCode = faultCode; self.faultString = faultString; self.detailXML = detailXML
    }
    public var description: String { "\(faultCode): \(faultString)" }
}
