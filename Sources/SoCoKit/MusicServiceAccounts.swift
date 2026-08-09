import Foundation

/// An account for a third-party music service.
///
/// Each service may have more than one account. Newer Sonos firmware exposes less
/// account information over UPnP than older releases did, so this class retains the
/// `/status/accounts` compatibility path used by upstream SoCo.
public final class MusicServiceAccount: CustomStringConvertible {
    public var serviceType = ""
    public var serialNumber = ""
    public var nickname = ""
    public var deleted = false
    public var username = ""
    public var metadata = ""
    public var oaDeviceID = ""
    public var key = ""

    public var description: String { "<MusicServiceAccount '\(serialNumber):\(serviceType):\(nickname)'>" }

    public typealias AccountXMLLoader = (_ device: SoCo?) throws -> String
    public static var xmlLoader: AccountXMLLoader = { device in
        guard let player = try device ?? Discovery.anySoCo() else { throw SoCoError.noDeviceFound }
        let url = URL(string: "http://\(player.ipAddress):1400/status/accounts")!
        let response = try player.httpClient.request(method: "GET", url: url, headers: [:], body: nil, timeout: SoCoConfig.requestTimeout)
        guard (200..<300).contains(response.statusCode) else { throw SoCoError.http(status: response.statusCode, body: response.text) }
        return response.text
    }

    private final class WeakBox { weak var value: MusicServiceAccount?; init(_ value: MusicServiceAccount) { self.value = value } }
    private static let lock = NSLock()
    private static var allAccounts: [String: WeakBox] = [:]

    public static func resetCache() {
        lock.lock(); allAccounts.removeAll(); lock.unlock()
    }

    /// Get all accounts known to the Sonos system. Existing account objects are reused
    /// and updated when possible, matching Python SoCo's weak-value account database.
    public static func accounts(device: SoCo? = nil) throws -> [String: MusicServiceAccount] {
        let tree = try XMLTree(try xmlLoader(device))
        var result: [String: MusicServiceAccount] = [:]

        for xmlAccount in tree.root?.descendants(named: "Account") ?? [] {
            guard let serial = xmlAccount.attribute("SerialNum") else { continue }
            let isDeleted = xmlAccount.attribute("Deleted") == "1"

            lock.lock()
            let existing = allAccounts[serial]?.value
            if isDeleted {
                allAccounts.removeValue(forKey: serial)
                lock.unlock()
                continue
            }
            let account: MusicServiceAccount
            if let existing { account = existing }
            else {
                account = MusicServiceAccount()
                account.serialNumber = serial
                allAccounts[serial] = WeakBox(account)
            }
            lock.unlock()

            account.serviceType = xmlAccount.attribute("Type") ?? ""
            account.deleted = false
            account.username = xmlAccount.firstChild(named: "UN")?.text ?? ""
            // Upstream notes that `MD` is not fully understood (possibly metadata).
            account.metadata = xmlAccount.firstChild(named: "MD")?.text ?? ""
            account.nickname = xmlAccount.firstChild(named: "NN")?.text ?? ""
            account.oaDeviceID = xmlAccount.firstChild(named: "OADevID")?.text ?? ""
            account.key = xmlAccount.firstChild(named: "Key")?.text ?? ""
            result[serial] = account
        }

        // There is always a TuneIn account, but Sonos handles it separately and it does
        // not appear in `/status/accounts`. Upstream SoCo adds this synthetic account.
        let tuneIn = MusicServiceAccount()
        tuneIn.serviceType = "65031"
        tuneIn.serialNumber = "0"
        result["0"] = tuneIn
        return result
    }

    public static func accounts(forServiceType serviceType: String, device: SoCo? = nil) throws -> [MusicServiceAccount] {
        try accounts(device: device).values.filter { $0.serviceType == serviceType }
    }
}

/// Compatibility spelling corresponding to `soco.music_services.accounts.Account`.
public typealias Account = MusicServiceAccount
