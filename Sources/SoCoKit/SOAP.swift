import Foundation

/// An exception encapsulating a SOAP Fault is represented by `SoapFault` in `Errors.swift`.
///
/// Sonos uses SOAP to send commands in RPC form. A complete RPC SOAP message looks
/// broadly like this (see http://www.w3.org/TR/2000/NOTE-SOAP-20000508/):
///
/// ```text
/// POST Endpoint URL HTTP/1.1
/// HOST: Host of Endpoint URL:port
/// CONTENT-LENGTH: bytes in body
/// CONTENT-TYPE: text/xml; charset="utf-8"
/// SOAPACTION: URI
///
/// <?xml version="1.0"?>
/// <s:Envelope
///   xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
///   s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
///   <s:Header>
///       ...Header elements go here...
///   </s:Header>
///   <s:Body>
///       <ns:MethodName xmlns:ns="MethodNamespace">
///           <param1>value</param1>
///           ...
///       </ns:MethodName>
///   </s:Body>
/// </s:Envelope>
/// ```
///
/// The original SoCo implementation intentionally did not use a general-purpose SOAP
/// library. Sonos only uses basic SOAP features, while third-party music services have
/// historically exposed buggy/incomplete WSDL implementations. This Swift port keeps
/// that deliberately small SOAP implementation.
public struct SoapMessage {
    public var endpoint: URL
    public var method: String
    public var parameters: [(String, String)]
    public var httpHeaders: [String: String]
    public var soapAction: String?
    public var soapHeader: String?
    public var namespace: String?
    public var timeout: TimeInterval
    public var httpClient: HTTPClient

    public init(
        endpoint: URL,
        method: String,
        parameters: [(String, String)] = [],
        httpHeaders: [String: String] = [:],
        soapAction: String? = nil,
        soapHeader: String? = nil,
        namespace: String? = nil,
        timeout: TimeInterval = SoCoConfig.requestTimeout,
        httpClient: HTTPClient = URLSessionHTTPClient.shared
    ) {
        self.endpoint = endpoint
        self.method = method
        self.parameters = parameters
        self.httpHeaders = httpHeaders
        self.soapAction = soapAction
        self.soapHeader = soapHeader
        self.namespace = namespace
        self.timeout = timeout
        self.httpClient = httpClient
    }

    /// Prepare the HTTP headers for sending, adding the `SOAPACTION` header to the others.
    public func prepareHeaders() -> [String: String] {
        var headers = ["Content-Type": "text/xml; charset=\"utf-8\""]
        if let soapAction {
            // FIXME from the original SoCo source: successful auth was with SOAP-Action.
            headers["SOAPACTION"] = "\"\(soapAction)\""
        }
        httpHeaders.forEach { headers[$0] = $1 }
        return headers
    }

    /// Wrap a SOAP header in the appropriate envelope tags.
    public func prepareSoapHeader() -> String {
        soapHeader.map { "<s:Header>\($0)</s:Header>" } ?? ""
    }

    /// Prepare the SOAP method body and escape parameter values.
    public func prepareSoapBody() -> String {
        let wrappedParameters = parameters.map { name, value in
            "<\(name)>\(xmlEscape(value))</\(name)>"
        }.joined()

        if let namespace {
            return "<\(method) xmlns=\"\(namespace)\">\(wrappedParameters)</\(method)>"
        }
        return "<\(method)>\(wrappedParameters)</\(method)>"
    }

    /// Wrap the prepared header and body in a SOAP 1.1 envelope.
    public func prepareSoapEnvelope() -> String {
        let template =
            "<?xml version=\"1.0\"?>" +
            "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"" +
            " s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" +
            prepareSoapHeader() +
            "<s:Body>" + prepareSoapBody() + "</s:Body>" +
            "</s:Envelope>"
        return template
    }

    /// Prepare the complete HTTP headers and SOAP XML payload.
    public func prepare() -> (headers: [String: String], body: String) {
        (prepareHeaders(), prepareSoapEnvelope())
    }

    /// Call the SOAP method on the server and return the de-capsulated method response.
    ///
    /// - Throws: `SoapFault` if the response contains a SOAP Fault, `SoCoError.http`
    ///   for HTTP failures without a SOAP Fault, and XML errors for malformed responses.
    public func call() throws -> SoCoXMLElement {
        let prepared = prepare()
        let response = try httpClient.request(
            method: "POST",
            url: endpoint,
            headers: prepared.headers,
            body: Data(prepared.body.utf8),
            timeout: timeout
        )

        let tree = try XMLTree(response.text)
        guard let body = tree.root?.descendants(named: "Body").first else {
            throw SoCoError.xml("SOAP response has no Body")
        }

        // SOAP servers commonly return an XML Fault together with HTTP 500. Always
        // inspect the body before reducing the failure to a generic HTTP error.
        if let fault = body.descendants(named: "Fault").first {
            let code = fault.firstChild(named: "faultcode")?.text ?? "SOAP-ENV:Server"
            let string = fault.firstChild(named: "faultstring")?.text ?? "SOAP fault"
            let detail = fault.firstChild(named: "detail")?.xmlString
            throw SoapFault(faultCode: code, faultString: string, detailXML: detail)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw SoCoError.http(status: response.statusCode, body: response.text)
        }

        guard let methodResponse = body.children?.compactMap({ $0 as? SoCoXMLElement }).first else {
            throw SoCoError.xml("SOAP Body is empty")
        }
        return methodResponse
    }
}
