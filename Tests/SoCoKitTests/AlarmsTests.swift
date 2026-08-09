import Foundation
import Testing
@testable import SoCoKit

private func alarmListSOAP(version: String, room: String) -> String {
    let list = "<Alarms><Alarm ID=\"14\" StartTime=\"07:00:00\" Duration=\"02:00:00\" Recurrence=\"DAILY\" Enabled=\"1\" RoomUUID=\"\(room)\" ProgramURI=\"x-rincon-buzzer:0\" ProgramMetaData=\"\" PlayMode=\"SHUFFLE_NOREPEAT\" Volume=\"25\" IncludeLinkedZones=\"0\"/></Alarms>"
    return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:ListAlarmsResponse xmlns:u=\"urn:schemas-upnp-org:service:AlarmClock:1\"><CurrentAlarmListVersion>\(version)</CurrentAlarmListVersion><CurrentAlarmList>\(xmlEscape(list))</CurrentAlarmList></u:ListAlarmsResponse></s:Body></s:Envelope>"
}

private func zgsSOAP(_ zones: [(uid: String, name: String, ip: String)]) -> String {
    let members = zones.map { zone in
        "<ZoneGroupMember UUID=\"\(zone.uid)\" ZoneName=\"\(zone.name)\" Location=\"http://\(zone.ip):1400/xml/device_description.xml\" Invisible=\"0\" BootSeq=\"1\"/>"
    }.joined()
    let coordinator = zones.first?.uid ?? "RINCON_none"
    let payload = "<ZoneGroups><ZoneGroup Coordinator=\"\(coordinator)\" ID=\"\(coordinator):1\">\(members)</ZoneGroup></ZoneGroups>"
    return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:GetZoneGroupStateResponse xmlns:u=\"urn:schemas-upnp-org:service:ZoneGroupTopology:1\"><ZoneGroupState>\(xmlEscape(payload))</ZoneGroupState></u:GetZoneGroupStateResponse></s:Body></s:Envelope>"
}

@Suite(.serialized) struct AlarmsTests {
    init() { Alarms.shared.reset() }

    @Test func recurrenceValidationMatchesPython() {
        for value in ["DAILY", "WEEKDAYS", "WEEKENDS", "ONCE", "ON_1", "ON_123412"] {
            #expect(isValidRecurrence(value))
        }
        for value in ["on_1", "ON_123456789", "ON_", " ON_1"] {
            #expect(!isValidRecurrence(value))
        }
    }

    @Test func loadsExistingZoneAlarm() throws {
        Alarms.shared.reset()
        let http = MockHTTPClient()
        http.enqueue(text: alarmListSOAP(version: "RINCON_test:14", room: "RINCON_test"))
        http.enqueue(text: zgsSOAP([("RINCON_test", "Kitchen", "10.0.0.51")]))
        let source = try SoCo("10.0.0.50", httpClient: http)
        try Alarms.shared.update(zone: source)
        #expect(Alarms.shared.count == 1)
        #expect(Alarms.shared.skipped.isEmpty)
        let alarm = try #require(Alarms.shared["14"])
        #expect(try alarm.zone?.uid() == "RINCON_test")
        let expectedStartTime = try AlarmTime(hour: 7, minute: 0)
        let expectedDuration = try AlarmTime(hour: 2, minute: 0)
        #expect(alarm.startTime == expectedStartTime)
        #expect(alarm.duration == expectedDuration)
        #expect(alarm.recurrence == "DAILY")
        #expect(alarm.enabled)
        #expect(alarm.programURI == nil)
        #expect(alarm.playMode == "SHUFFLE_NOREPEAT")
        #expect(alarm.volume == 25)
        #expect(!alarm.includeLinkedZones)
        #expect(alarm.roomUUID == "RINCON_test")
    }

    @Test func missingZoneMovesFromSkippedWhenRegistered() throws {
        Alarms.shared.reset()
        let http = MockHTTPClient()
        http.enqueue(text: alarmListSOAP(version: "RINCON_test:14", room: "RINCON_missing"))
        http.enqueue(text: zgsSOAP([("RINCON_test", "Kitchen", "10.0.0.52")]))
        let source = try SoCo("10.0.0.53", httpClient: http)
        try Alarms.shared.update(zone: source)
        let skipped = try #require(Alarms.shared.skipped["14"])
        #expect(skipped.zone == nil)

        let missing = try SoCo("10.0.0.54", httpClient: http)
        missing._uid = "RINCON_missing"
        try Alarms.shared.updateSkipped(zone: missing)
        #expect(Alarms.shared.skipped.isEmpty)
        #expect(Alarms.shared["14"] === skipped)
        #expect(Alarms.shared["14"]?.zone === missing)
    }

    @Test func skippedAlarmObjectIsReusedOnLaterRefresh() throws {
        Alarms.shared.reset()
        let http = MockHTTPClient()
        http.enqueue(text: alarmListSOAP(version: "RINCON_test:14", room: "RINCON_missing"))
        http.enqueue(text: zgsSOAP([("RINCON_test", "Kitchen", "10.0.0.55")]))
        let source = try SoCo("10.0.0.56", httpClient: http)
        try Alarms.shared.update(zone: source)
        let original = try #require(Alarms.shared.skipped["14"])

        source.zoneGroupState.clearCache()
        http.enqueue(text: alarmListSOAP(version: "RINCON_test:15", room: "RINCON_missing"))
        http.enqueue(text: zgsSOAP([
            ("RINCON_test", "Kitchen", "10.0.0.55"),
            ("RINCON_missing", "Bedroom", "10.0.0.57")
        ]))
        try Alarms.shared.update(zone: source)
        #expect(Alarms.shared.skipped.isEmpty)
        let resolved = try #require(Alarms.shared["14"])
        #expect(resolved === original)
        #expect(try resolved.zone?.uid() == "RINCON_missing")
    }

    @Test func saveWithoutZoneRaises() throws {
        let alarm = try Alarm(zone: nil, roomUUID: "RINCON_missing")
        do {
            _ = try alarm.save()
            Issue.record("Expected a missing-zone error")
        } catch let SoCoError.invalidArgument(message) {
            #expect(message.contains("zone is not set"))
        }
    }

    @Test func nextAlarmDateUsesSonosSundayZeroAndOnceAsNextPossibleDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 8, minute: 0))! // Saturday
        let sunday = try Alarm(zone: nil, startTime: AlarmTime(hour: 7, minute: 0), recurrence: "ON_0")
        let next = try #require(sunday.nextAlarmDate(from: from, calendar: calendar))
        #expect(calendar.component(.weekday, from: next) == 1)
        #expect(calendar.component(.day, from: next) == 9)

        let once = try Alarm(zone: nil, startTime: AlarmTime(hour: 9, minute: 0), recurrence: "ONCE")
        #expect(calendar.component(.day, from: try #require(once.nextAlarmDate(from: from, calendar: calendar))) == 8)
    }
}
