import Foundation
import CryptoKit
// Public-key verification only: no Keychain or private key access.
let args = CommandLine.arguments
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(2)
}
guard args.count == 4,
      let key = Data(base64Encoded: try String(contentsOfFile: args[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)),
      let signature = Data(base64Encoded: args[3]) else { fail("Invalid verification arguments") }
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key)
let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
guard publicKey.isValidSignature(signature, for: data) else { fail("Ed25519 verification failed") }
