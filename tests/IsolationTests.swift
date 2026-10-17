import Foundation
let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath:CommandLine.arguments[1])), format:nil) as! [String:Any]
#if USAGE_TOPBAR_TESTING
precondition(AppVariant.isTesting)
precondition(AppVariant.bundleID == "local.alex.usage-topbar.testing")
precondition(QuotaHistoryStore.defaultURL.path.contains("/UsageTopbar Testing/"))
precondition(UpdatePolicy.configurationProblem(info) != nil, "even a production configuration must not enable testing updates")
#else
precondition(!AppVariant.isTesting)
precondition(QuotaHistoryStore.defaultURL.path.contains("/UsageTopbar/"))
precondition(AppVariant.bundleID == "local.alex.usage-topbar")
#endif
print("PASS build identity/history path/updater gate: \(AppVariant.bundleID)")

#if USAGE_TOPBAR_TESTING
precondition(HistorySourcePolicy.usesSimulation(preference:nil))
precondition(HistorySourcePolicy.usesSimulation(preference:true))
precondition(!HistorySourcePolicy.usesSimulation(preference:false))
let clock = Date(timeIntervalSince1970:1800000000)
let mock = SimulatedHistorySource(now:clock)
let key = mock.series()[0]
let points = mock.visiblePoints(series:key)
precondition(points == SimulatedHistorySource(now:clock).visiblePoints(series:key))
precondition(points.last!.reading.time - points.first!.reading.time == 14*86400)
let recent = points.filter { $0.reading.time >= points.last!.reading.time - 4*86400 }
precondition(Set(recent.compactMap { $0.event?.kind }) == Set([.card,.special]))
precondition(Set(points.compactMap { $0.event?.kind }) == Set([.cycle,.card,.special]))
let gaps = zip(points,points.dropFirst()).map { $1.reading.time-$0.reading.time }
precondition(gaps.contains(3600) && gaps.contains(5*3600) && gaps.contains(3*3600))
precondition(points.allSatisfy { $0.reading.account == "simulation-only" && (0...100).contains($0.reading.remaining) })
precondition(mock.visiblePoints(series:"missing").isEmpty)
#else
for preference: Bool? in [nil,true,false] {
    precondition(!HistorySourcePolicy.usesSimulation(preference:preference), "release must force real history")
}
#endif
print("PASS source switch, release exclusion, deterministic fixture coverage")
