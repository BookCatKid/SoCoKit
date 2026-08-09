import XCTest
@testable import SoCoKit

final class ServicesTests: XCTestCase {
    // Dummy known-good errors/responses etc. These are not necessarily valid as
    // actual commands, but are valid XML/UPnP. They also contain Unicode
    // characters to test Unicode handling, matching SoCo's original fixture.
    private let dummyError = """
    <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>607</errorCode><errorDescription>Oops μИⅠℂ☺ΔЄ💋</errorDescription></UPnPError></detail></s:Fault></s:Body></s:Envelope>
    """

    private let dummyErrorNoCode = """
    <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorDescription>Oops μИⅠℂ☺ΔЄ💋</errorDescription></UPnPError></detail></s:Fault></s:Body></s:Envelope>
    """

    private let dummyValidResponse = """
    <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetLEDStateResponse xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1"><CurrentLEDState>On</CurrentLEDState><Unicode>μИⅠℂ☺ΔЄ💋</Unicode></u:GetLEDStateResponse></s:Body></s:Envelope>
    """

    private let dummyValidAction = """
    <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:Service:1"><InstanceID>0</InstanceID><CurrentURI>URI</CurrentURI><CurrentURIMetaData></CurrentURIMetaData><Unicode>μИⅠℂ☺ΔЄ💋</Unicode></u:SetAVTransportURI></s:Body></s:Envelope>
    """

    private let scpd = """
    <?xml version="1.0"?>
    <scpd xmlns="urn:schemas-upnp-org:service-1-0">
      <actionList>
        <action>
          <name>Test</name>
          <argumentList>
            <argument><name>Argument1</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_One</relatedStateVariable></argument>
            <argument><name>Argument2</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Two</relatedStateVariable></argument>
            <argument><name>ReturnValue</name><direction>out</direction><relatedStateVariable>ResultType</relatedStateVariable></argument>
          </argumentList>
        </action>
      </actionList>
      <serviceStateTable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_One</name><dataType>string</dataType></stateVariable>
        <stateVariable sendEvents="no"><name>A_ARG_TYPE_Two</name><dataType>ui4</dataType><defaultValue>2</defaultValue><allowedValueRange><minimum>0</minimum><maximum>10</maximum><step>1</step></allowedValueRange></stateVariable>
        <stateVariable sendEvents="yes"><name>ResultType</name><dataType>string</dataType><allowedValueList><allowedValue>One</allowedValue><allowedValue>Two</allowedValue></allowedValueList></stateVariable>
      </serviceStateTable>
    </scpd>
    """

    private func makeService(client: MockHTTPClient = MockHTTPClient()) throws -> (SoCo, Service, MockHTTPClient) {
        let soco = try SoCo("192.168.1.101", httpClient: client)
        return (soco, Service(soco), client)
    }

    func testInitDefaults() throws {
        let (_, service, _) = try makeService()
        XCTAssertEqual(service.serviceType, "Service")
        XCTAssertEqual(service.version, 1)
        XCTAssertEqual(service.serviceID, "Service")
        XCTAssertEqual(service.baseURL.absoluteString, "http://192.168.1.101:1400")
        XCTAssertEqual(service.controlURL, "/Service/Control")
        XCTAssertEqual(service.scpdURL, "/xml/Service1.xml")
        XCTAssertEqual(service.eventSubscriptionURL, "/Service/Event")
    }

    func testSwiftRenamedServicesKeepPythonWireNames() throws {
        let soco = try SoCo("192.168.1.101", httpClient: MockHTTPClient())
        let mediaServer = MSConnectionManager(soco)
        XCTAssertEqual(mediaServer.serviceType, "ConnectionManager")
        XCTAssertEqual(mediaServer.serviceID, "MS_ConnectionManager")
        XCTAssertEqual(mediaServer.scpdURL, "/xml/MS_ConnectionManager1.xml")

        let mediaRenderer = MRConnectionManager(soco)
        XCTAssertEqual(mediaRenderer.serviceType, "ConnectionManager")
        XCTAssertEqual(mediaRenderer.serviceID, "MR_ConnectionManager")
        XCTAssertEqual(mediaRenderer.scpdURL, "/xml/MR_ConnectionManager1.xml")

        let queue = QueueService(soco)
        XCTAssertEqual(queue.serviceType, "Queue")
        XCTAssertEqual(queue.serviceID, "Queue")
        XCTAssertEqual(queue.scpdURL, "/xml/Queue1.xml")
    }

    func testWrapArguments() throws {
        XCTAssertEqual(Service.wrapArguments([("first", "one"), ("second", "2")]), "<first>one</first><second>2</second>")
        XCTAssertEqual(Service.wrapArguments(), "")
        XCTAssertEqual(Service.wrapArguments([("unicode", "μИⅠℂ☺ΔЄ💋")]), "<unicode>μИⅠℂ☺ΔЄ💋</unicode>")
        XCTAssertEqual(Service.wrapArguments([("weird", "&<\"2")]), "<weird>&amp;&lt;&quot;2</weird>")
    }

    func testUnwrapArguments() throws {
        XCTAssertEqual(try Service.unwrapArguments(dummyValidResponse), [
            "CurrentLEDState": "On",
            "Unicode": "μИⅠℂ☺ΔЄ💋",
        ])
    }

    func testUnwrapFiltersInvalidXMLCharacters() throws {
        let invalid = dummyValidResponse.replacingOccurrences(of: "μИⅠℂ☺ΔЄ💋", with: "A\u{4}B")
        XCTAssertEqual(try Service.unwrapArguments(invalid)["Unicode"], "AB")
    }

    func testParseSCPDActionsAndEventVariables() throws {
        let actions = try Service.parseSCPDActions(scpd)
        XCTAssertEqual(actions.count, 1)
        let action = try XCTUnwrap(actions.first)
        XCTAssertEqual(action.name, "Test")
        XCTAssertEqual(action.inputArguments.map(\.name), ["Argument1", "Argument2"])
        XCTAssertEqual(action.outputArguments.map(\.name), ["ReturnValue"])
        XCTAssertEqual(action.inputArguments[0].vartype.datatype, "string")
        XCTAssertEqual(action.inputArguments[1].vartype.defaultValue, "2")
        XCTAssertEqual(action.inputArguments[1].vartype.allowedRange, ["0", "10", "1"])
        XCTAssertEqual(action.outputArguments[0].vartype.allowedValues, ["One", "Two"])
        XCTAssertEqual(action.description, "Test(Argument1: string, Argument2=2: [0..10]) -> {ReturnValue: [One, Two]}")

        let eventVars = try Service.parseSCPDEventVariables(scpd)
        XCTAssertEqual(eventVars.count, 1)
        XCTAssertEqual(eventVars[0].0, "ResultType")
        XCTAssertEqual(eventVars[0].1, "string")
    }

    func testActionsAndEventVarsAreFetchedAndCached() throws {
        let client = MockHTTPClient()
        client.enqueue(text: scpd)
        let (_, service, _) = try makeService(client: client)
        XCTAssertEqual(try service.actions().count, 1)
        XCTAssertEqual(try service.actions().count, 1)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, "GET")
        XCTAssertEqual(client.requests[0].url.absoluteString, "http://192.168.1.101:1400/xml/Service1.xml")

        // Event variables intentionally have their own cache, matching SoCo.
        client.enqueue(text: scpd)
        XCTAssertEqual(try service.eventVariables().count, 1)
        XCTAssertEqual(try service.eventVariables().count, 1)
        XCTAssertEqual(client.requests.count, 2)
    }

    func testComposeArgumentsValidatesAndUsesDefaults() throws {
        let client = MockHTTPClient()
        client.enqueue(text: scpd)
        let (_, service, _) = try makeService(client: client)

        let composed = try service.composeArguments(action: "Test", values: ["Argument1": "1"])
        XCTAssertEqual(composed.map(\.0), ["Argument1", "Argument2"])
        XCTAssertEqual(composed.map(\.1), ["1", "2"])

        service.defaultArguments["Argument2"] = "7"
        let overriddenDefault = try service.composeArguments(action: "Test", values: ["Argument1": "3"])
        XCTAssertEqual(overriddenDefault.map(\.1), ["3", "7"])

        XCTAssertThrowsError(try service.composeArguments(action: "Test", values: ["Argument1": "1", "Error": "3"]))
        XCTAssertThrowsError(try service.composeArguments(action: "Missing", values: [:]))
    }

    func testBuildCommand() throws {
        let (_, service, _) = try makeService()
        let command = service.buildCommand(action: "SetAVTransportURI", arguments: [
            ("InstanceID", "0"),
            ("CurrentURI", "URI"),
            ("CurrentURIMetaData", ""),
            ("Unicode", "μИⅠℂ☺ΔЄ💋"),
        ])
        XCTAssertEqual(command.body, dummyValidAction)
        XCTAssertEqual(command.headers, [
            "Content-Type": "text/xml; charset=\"utf-8\"",
            "SOAPACTION": "urn:schemas-upnp-org:service:Service:1#SetAVTransportURI",
        ])
    }

    func testContentDirectoryHeadersAndURLs() throws {
        let soco = try SoCo("192.168.1.101", httpClient: MockHTTPClient())
        let service = ContentDirectory(soco)
        let command = service.buildCommand(action: "Browse")
        XCTAssertEqual(command.headers["USER-AGENT"], "Sonos/83.1-61210")
        XCTAssertEqual(service.controlURL, "/MediaServer/ContentDirectory/Control")
        XCTAssertEqual(service.eventSubscriptionURL, "/MediaServer/ContentDirectory/Event")
    }

    func testSendCommandUsesHTTPAndCache() throws {
        let client = MockHTTPClient()
        client.enqueue(text: dummyValidResponse)
        let (_, service, _) = try makeService(client: client)
        service.cache = TimedCache(defaultTimeout: 0)

        let args = [
            ("InstanceID", "0"),
            ("CurrentURI", "URI"),
            ("CurrentURIMetaData", ""),
            ("Unicode", "μИⅠℂ☺ΔЄ💋"),
        ]
        let result = try service.sendCommand("SetAVTransportURI", arguments: args, cacheTimeout: 1)
        XCTAssertEqual(result["CurrentLEDState"], "On")
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, "POST")
        XCTAssertEqual(client.requests[0].url.absoluteString, "http://192.168.1.101:1400/Service/Control")
        XCTAssertEqual(client.requests[0].body, Data(dummyValidAction.utf8))
        XCTAssertEqual(client.requests[0].timeout, SoCoConfig.requestTimeout)

        // Same action and arguments should come from the cache.
        let cached = try service.sendCommand("SetAVTransportURI", arguments: args)
        XCTAssertEqual(cached["Unicode"], "μИⅠℂ☺ΔЄ💋")
        XCTAssertEqual(client.requests.count, 1)

        // Different parameters must not collide in the cache.
        client.enqueue(text: dummyValidResponse)
        _ = try service.sendCommand("SetAVTransportURI", arguments: [("InstanceID", "1")])
        XCTAssertEqual(client.requests.count, 2)
    }

    func testExplicitCacheCanOverrideServiceCache() throws {
        let client = MockHTTPClient()
        client.enqueue(text: dummyValidResponse)
        let (_, service, _) = try makeService(client: client)
        service.cache = NullCache()
        let explicit = TimedCache(defaultTimeout: 1)

        _ = try service.sendCommand("GetLEDState", cache: explicit, cacheTimeout: 1)
        _ = try service.sendCommand("GetLEDState", cache: explicit)
        XCTAssertEqual(client.requests.count, 1)
    }

    func testDispatcherEquivalentComposesSCPDArguments() throws {
        let client = MockHTTPClient()
        client.enqueue(text: scpd)
        client.enqueue(text: dummyValidResponse)
        let (_, service, _) = try makeService(client: client)

        let testAction = service.action(named: "Test")
        let result = try testAction(["Argument1": 1], nil)
        XCTAssertEqual(result["CurrentLEDState"], "On")
        XCTAssertEqual(client.requests.count, 2)
        let body = String(data: try XCTUnwrap(client.requests[1].body), encoding: .utf8)
        XCTAssertTrue(try XCTUnwrap(body).contains("<Argument1>1</Argument1><Argument2>2</Argument2>"))
    }

    func testHandleUPnPError() throws {
        let (_, service, _) = try makeService()
        XCTAssertThrowsError(try service.handleUPnPError(dummyError)) { error in
            guard case SoCoError.upnp(let code, let description, let xml) = error else {
                return XCTFail("Expected UPnP error, got \(error)")
            }
            XCTAssertEqual(code, "607")
            XCTAssertEqual(description, "Signature Failure")
            XCTAssertTrue(xml.contains("Oops μИⅠℂ☺ΔЄ💋"))
        }
    }

    func testHandleUPnPErrorWithoutCodeIsUnknown() throws {
        let (_, service, _) = try makeService()
        for response in [dummyErrorNoCode, ""] {
            XCTAssertThrowsError(try service.handleUPnPError(response)) { error in
                guard case SoCoError.unknown = error else {
                    return XCTFail("Expected unknown SoCo error, got \(error)")
                }
            }
        }
    }

    func testHTTPStatusHandling() throws {
        let client = MockHTTPClient()
        let (_, service, _) = try makeService(client: client)

        client.enqueue(statusCode: 405, text: "")
        XCTAssertThrowsError(try service.sendCommand("Nope")) { error in
            guard case SoCoError.unsupported = error else { return XCTFail("Expected unsupported") }
        }

        client.enqueue(statusCode: 500, text: dummyError)
        XCTAssertThrowsError(try service.sendCommand("Bad")) { error in
            guard case SoCoError.upnp(let code, _, _) = error else { return XCTFail("Expected UPnP") }
            XCTAssertEqual(code, "607")
        }

        client.enqueue(statusCode: 503, text: "offline")
        XCTAssertThrowsError(try service.sendCommand("Bad")) { error in
            guard case SoCoError.http(let status, let body) = error else { return XCTFail("Expected HTTP") }
            XCTAssertEqual(status, 503)
            XCTAssertEqual(body, "offline")
        }
    }
}
