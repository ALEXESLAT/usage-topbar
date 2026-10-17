import Foundation
import Combine

struct ProgressGradientStop: Codable, Equatable, Identifiable {
    var id: UUID
    var location: Double
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    init(id: UUID = UUID(), location: Double, red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.id=id;self.location=location;self.red=red;self.green=green;self.blue=blue;self.alpha=alpha
    }
}

struct ProgressGradientSettings: Codable, Equatable {
    var version = 1
    var stops: [ProgressGradientStop]
    static let standard = ProgressGradientSettings(stops:[
        ProgressGradientStop(id:UUID(uuidString:"00000000-0000-0000-0000-000000000001")!,location:0,red:0.36,green:0.59,blue:0.48),
        ProgressGradientStop(id:UUID(uuidString:"00000000-0000-0000-0000-000000000002")!,location:1,red:0.46,green:0.69,blue:0.61)
    ])
    var orderedStops:[ProgressGradientStop] {
        stops.sorted { $0.location == $1.location ? $0.id.uuidString < $1.id.uuidString : $0.location < $1.location }
    }
    var isValid:Bool {
        version == 1 && (2...8).contains(stops.count) && Set(stops.map(\.id)).count == stops.count &&
        stops.allSatisfy { s in [s.location,s.red,s.green,s.blue,s.alpha].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    }
    mutating func move(_ id:UUID,to location:Double) {
        guard location.isFinite,let i=stops.firstIndex(where: { $0.id==id }) else { return }
        stops[i].location=max(0,min(1,location))
    }
    mutating func color(_ id:UUID,red:Double,green:Double,blue:Double,alpha:Double) {
        let channels=[red,green,blue,alpha]
        guard channels.allSatisfy({ $0.isFinite }),let i=stops.firstIndex(where: { $0.id==id }) else { return }
        stops[i].red=max(0,min(1,red));stops[i].green=max(0,min(1,green));stops[i].blue=max(0,min(1,blue));stops[i].alpha=max(0,min(1,alpha))
    }
    @discardableResult mutating func add() -> UUID? {
        guard stops.count<8 else { return nil }
        let sorted=orderedStops
        let pair=zip(sorted,sorted.dropFirst()).max { ($0.1.location-$0.0.location)<($1.1.location-$1.0.location) }!
        let a=pair.0,b=pair.1
        let stop=ProgressGradientStop(location:(a.location+b.location)/2,red:(a.red+b.red)/2,green:(a.green+b.green)/2,blue:(a.blue+b.blue)/2,alpha:(a.alpha+b.alpha)/2)
        stops.append(stop);return stop.id
    }
    mutating func remove(_ id:UUID) {
        guard stops.count>2,stops.contains(where: { $0.id==id }) else { return }
        stops.removeAll { $0.id==id }
    }
}

final class ProgressGradientPreferences {
    static let key="overlay.progressGradient.v1"
    private let defaults:UserDefaults
    init(defaults:UserDefaults = .standard) { self.defaults=defaults }
    func load() -> ProgressGradientSettings {
        guard let data=defaults.data(forKey:Self.key),let settings=try? JSONDecoder().decode(ProgressGradientSettings.self,from:data),settings.isValid else { return .standard }
        return settings
    }
    func save(_ settings:ProgressGradientSettings) -> Bool {
        guard settings.isValid,let data=try? JSONEncoder().encode(settings) else { return false }
        defaults.set(data,forKey:Self.key);return defaults.data(forKey:Self.key)==data
    }
}

final class ProgressGradientSession:ObservableObject {
    @Published private(set) var draft:ProgressGradientSettings
    @Published private(set) var previewEnabled=false
    @Published private(set) var error:String?
    let original:ProgressGradientSettings
    private let preview:(ProgressGradientSettings)->Void
    private let persist:(ProgressGradientSettings)->Bool
    private var finished=false
    init(original:ProgressGradientSettings,preview:@escaping(ProgressGradientSettings)->Void,persist:@escaping(ProgressGradientSettings)->Bool) {
        self.original=original;draft=original;self.preview=preview;self.persist=persist
    }
    func edit(_ change:(inout ProgressGradientSettings)->Void) {
        guard !finished else { return };var next=draft;change(&next);guard next.isValid else { return }
        draft=next;error=nil;if previewEnabled { preview(draft) }
    }
    func setPreview(_ enabled:Bool) {
        guard !finished else { return };previewEnabled=enabled;preview(enabled ? draft:original)
    }
    func reset() { edit { $0 = .standard } }
    func save() -> Bool {
        guard !finished else { return false }
        guard persist(draft) else { error="保存失败，设置尚未写入。";return false }
        preview(draft);finished=true;return true
    }
    func cancel() { guard !finished else { return };preview(original);finished=true }
}
