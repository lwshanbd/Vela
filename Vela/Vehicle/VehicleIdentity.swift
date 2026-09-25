import CryptoKit
import Foundation
import TeslaBLE

/// A vehicle Vela has been paired with. Only the VIN is persisted here; the
/// P-256 private key lives in the Keychain via `KeychainTeslaKeyStore`.
struct VehicleIdentity: Equatable, Sendable {
    let vin: String

    /// Model name decoded from the VIN. Tesla VINs carry the model line in
    /// the fourth character (5YJ3…, 7SAY…, 5YJS…, 5YJX…, 7G2C…).
    var modelName: String {
        let chars = Array(vin)
        guard chars.count == 17 else { return "Tesla" }
        switch chars[3] {
        case "3": return "Model 3"
        case "Y": return "Model Y"
        case "S": return "Model S"
        case "X": return "Model X"
        case "C": return "Cybertruck"
        default: return "Tesla"
        }
    }

    /// The BLE local name the vehicle advertises: "S" + hex of the first
    /// eight bytes of SHA-1(VIN) + "C". Matches `VehicleLocalName` in Tesla's
    /// vehicle-command (pkg/connector/ble) and TeslaBLE's scanner filter.
    var bleLocalName: String {
        Self.bleLocalName(for: vin)
    }

    static func bleLocalName(for vin: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(vin.utf8))
        return "S" + digest.prefix(8).map { String(format: "%02x", $0) }.joined() + "C"
    }

    /// VINs are 17 characters from A–Z and 0–9, never I, O or Q.
    static func normalize(_ raw: String) -> String? {
        let vin = raw.uppercased().filter { !$0.isWhitespace }
        guard vin.count == 17,
              vin.allSatisfy({ ($0.isASCII && ($0.isLetter || $0.isNumber)) && !"IOQ".contains($0) })
        else { return nil }
        return vin
    }
}

/// Persists which vehicle is paired and owns its Keychain key.
struct VehicleIdentityStore: Sendable {
    static let keychainService = "com.beadinventory.vela.tesla-key"
    private static let vinKey = "vela.pairedVIN"

    let keyStore = KeychainTeslaKeyStore(service: keychainService)

    var paired: VehicleIdentity? {
        UserDefaults.standard.string(forKey: Self.vinKey).map(VehicleIdentity.init(vin:))
    }

    func markPaired(_ identity: VehicleIdentity) {
        UserDefaults.standard.set(identity.vin, forKey: Self.vinKey)
    }

    /// Returns the Keychain key for `vin`, creating and storing one only when
    /// none exists. Re-pairing reuses the same identity.
    func loadOrCreateKey(for vin: String) throws -> P256.KeyAgreement.PrivateKey {
        if let existing = try keyStore.loadPrivateKey(forVIN: vin) {
            return existing
        }
        let key = KeyPairFactory.generateKeyPair()
        try keyStore.savePrivateKey(key, forVIN: vin)
        return key
    }

    func forget(_ identity: VehicleIdentity) throws {
        try keyStore.deletePrivateKey(forVIN: identity.vin)
        UserDefaults.standard.removeObject(forKey: Self.vinKey)
    }
}
