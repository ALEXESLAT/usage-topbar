import Foundation

/// Only explicit user choices persist; geometry-driven hiding remains transient.
/// Keep this key and the application Bundle ID stable across updates.
final class OverlayPreferences {
    static let hiddenKey = "overlay.userHidden"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var userHidden: Bool {
        get { defaults.bool(forKey: Self.hiddenKey) }
        set { defaults.set(newValue, forKey: Self.hiddenKey) }
    }
}
