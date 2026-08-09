import XCTest
@testable import SoCoKit

final class CacheTests: XCTestCase {
    override func tearDown() {
        SoCoConfig.cacheEnabled = true
        super.tearDown()
    }

    func testFactoryHonorsGlobalCacheSetting() {
        SoCoConfig.cacheEnabled = true
        XCTAssertTrue(Cache.make() is TimedCache)
        SoCoConfig.cacheEnabled = false
        XCTAssertTrue(Cache.make() is NullCache)
    }

    func testPutGetDeleteAndClear() {
        let cache = TimedCache(defaultTimeout: 10)
        cache.put("item", keyParts: ["some", "args"], timeout: 10)
        XCTAssertEqual(cache.get(keyParts: ["some", "args"]) as? String, "item")
        XCTAssertNil(cache.get(keyParts: ["some", "otherargs"]))

        cache.delete(keyParts: ["some", "args"])
        XCTAssertNil(cache.get(keyParts: ["some", "args"]))

        cache.put("item", keyParts: ["some", "args"], timeout: 10)
        cache.clear()
        XCTAssertNil(cache.get(keyParts: ["some", "args"]))
    }

    func testExpiration() {
        let cache = TimedCache()
        cache.put("item", keyParts: ["short"], timeout: 0.03)
        XCTAssertEqual(cache.get(keyParts: ["short"]) as? String, "item")
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertNil(cache.get(keyParts: ["short"]))
    }

    func testDisabledCache() {
        let cache = TimedCache(defaultTimeout: 10)
        cache.enabled = false
        cache.put("item", keyParts: ["args"], timeout: 10)
        XCTAssertNil(cache.get(keyParts: ["args"]))
    }

    func testUnicodeKey() {
        let cache = TimedCache(defaultTimeout: 10)
        let unicode = "μИⅠℂ☺ΔЄ💋"
        cache.put("result", keyParts: ["SetAVTransportURI", unicode], timeout: 10)
        XCTAssertEqual(cache.get(keyParts: ["SetAVTransportURI", unicode]) as? String, "result")
    }
}
