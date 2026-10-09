import Foundation
// Public test data only. No credentials, filesystem writes or external requests.
while let line = readLine() {
    guard let data = line.data(using: .utf8),
          let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = request["id"] else { continue }
    let result: [String: Any]
    switch request["method"] as? String {
    case "initialize": result = [:]
    case "account/rateLimits/read":
        result = ["rateLimits": ["primary": ["usedPercent": 40, "windowDurationMins": 300, "resetsAt": 2000000000]]]
    default: continue
    }
    if let output = try? JSONSerialization.data(withJSONObject: ["id": id, "result": result]) {
        FileHandle.standardOutput.write(output + Data([10]))
    }
}
