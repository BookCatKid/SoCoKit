import XCTest
@testable import SoCoKit

final class SOAPTests: XCTestCase {
    private let dummyValidResponse = """
    <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetLEDStateResponse xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1"><CurrentLEDState>On</CurrentLEDState><Unicode>data</Unicode></u:GetLEDStateResponse></s:Body></s:Envelope>
    """

    func testPrepareHeaders() throws {
        let message = SoapMessage(
            endpoint: try XCTUnwrap(URL(string: "http://endpoint.example.com")),
            method: "method",
            httpHeaders: ["test1": "one", "test2": "two"]
        )
        XCTAssertEqual(message.prepareHeaders(), [
            "Content-Type": "text/xml; charset=\"utf-8\"",
            "test1": "one",
            "test2": "two"
        ])

        var withAction = message
        withAction.soapAction = "soapaction"
        XCTAssertEqual(withAction.prepareHeaders()["SOAPACTION"], "\"soapaction\"")
    }

    func testPrepareSoapHeader() throws {
        let endpoint = try XCTUnwrap(URL(string: "http://endpoint.example.com"))
        XCTAssertEqual(
            SoapMessage(endpoint: endpoint, method: "method", soapHeader: "<a><b></b></a>").prepareSoapHeader(),
            "<s:Header><a><b></b></a></s:Header>"
        )
        XCTAssertEqual(SoapMessage(endpoint: endpoint, method: "method").prepareSoapHeader(), "")
    }

    func testPrepareSoapBody() throws {
        let endpoint = try XCTUnwrap(URL(string: "http://endpoint.example.com"))
        XCTAssertEqual(SoapMessage(endpoint: endpoint, method: "a_method").prepareSoapBody(), "<a_method></a_method>")
        XCTAssertEqual(
            SoapMessage(endpoint: endpoint, method: "a_method", parameters: [("one", "1")]).prepareSoapBody(),
            "<a_method><one>1</one></a_method>"
        )
        XCTAssertEqual(
            SoapMessage(endpoint: endpoint, method: "a_method", parameters: [("one", "1"), ("two", "2")], namespace: "http://a_namespace").prepareSoapBody(),
            "<a_method xmlns=\"http://a_namespace\"><one>1</one><two>2</two></a_method>"
        )
    }

    func testPrepareWholeMessageMatchesPythonContract() throws {
        let message = SoapMessage(
            endpoint: try XCTUnwrap(URL(string: "http://endpoint.example.com")),
            method: "getData",
            parameters: [("one", "1")],
            httpHeaders: ["timeout": "3"],
            soapAction: "ACTION",
            soapHeader: "<a_header>data</a_header>",
            namespace: "http://namespace.com"
        )
        let prepared = message.prepare()
        XCTAssertEqual(
            prepared.body,
            "<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Header><a_header>data</a_header></s:Header><s:Body><getData xmlns=\"http://namespace.com\"><one>1</one></getData></s:Body></s:Envelope>"
        )
        XCTAssertEqual(prepared.headers["SOAPACTION"], "\"ACTION\"")
    }

    func testCallUsesHTTPClientAndDecapsulatesResponse() throws {
        let client = MockHTTPClient()
        client.enqueue(text: dummyValidResponse)
        let endpoint = try XCTUnwrap(URL(string: "http://endpoint.example.com"))
        let message = SoapMessage(
            endpoint: endpoint,
            method: "getData",
            parameters: [("one", "1")],
            httpHeaders: ["user-agent": "sonos"],
            soapAction: "ACTION",
            soapHeader: "<a_header>data</a_header>",
            namespace: "http://namespace.com",
            httpClient: client
        )

        let result = try message.call()
        XCTAssertEqual(result.localNameSafe, "GetLEDStateResponse")
        XCTAssertEqual(result.firstChild(named: "CurrentLEDState")?.text, "On")
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, "POST")
        XCTAssertEqual(client.requests[0].url, endpoint)
        XCTAssertEqual(client.requests[0].headers["SOAPACTION"], "\"ACTION\"")
    }

    func testSoapFault() throws {
        let faultResponse = """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError><errorCode>701</errorCode></UPnPError></detail></s:Fault></s:Body></s:Envelope>
        """
        let client = MockHTTPClient()
        client.enqueue(statusCode: 500, text: faultResponse)
        let message = SoapMessage(endpoint: try XCTUnwrap(URL(string: "http://endpoint.example.com")), method: "x", httpClient: client)
        XCTAssertThrowsError(try message.call()) { error in
            guard let fault = error as? SoapFault else { return XCTFail("Expected SoapFault, got \(error)") }
            XCTAssertEqual(fault.faultCode, "s:Client")
            XCTAssertEqual(fault.faultString, "UPnPError")
        }
    }
}
