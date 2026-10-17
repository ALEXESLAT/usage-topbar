import Foundation

/// Only explicit user choices persist; geometry-driven hiding remains transient.
/// Keep this key and the application Bundle ID stable across updates.
final class OverlayPreferences {
    static let hiddenKey = "overlay.userHidden"
    private let defaults: any PreferenceStore
    init(defaults: any PreferenceStore = UserDefaults.standard) { self.defaults = defaults }
    var userHidden: Bool {
        get { defaults.bool(forKey: Self.hiddenKey) }
        set { defaults.set(newValue, forKey: Self.hiddenKey) }
    }
}
