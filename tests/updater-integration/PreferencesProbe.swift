import Foundation

// This helper is embedded only in isolated fixtures, never the production app.
@main struct PreferencesProbe {
    static func main() {
        let args = CommandLine.arguments
        guard args.count == 4, args[1].hasPrefix("local.alex.usage-topbar.fixture.preferences-"),
              let defaults = UserDefaults(suiteName: args[1]) else { exit(2) }
        let settings = OverlayPreferences(defaults: defaults)
        let expected = args[3] == "hidden"
        if args[2] == "seed" {
            guard defaults.object(forKey: OverlayPreferences.hiddenKey) == nil,
                  !settings.userHidden else { exit(3) }
            settings.userHidden = expected
            defaults.set("fixture-only", forKey: "future-setting-sentinel")
            guard defaults.synchronize() else { exit(4) }
        } else if args[2] != "verify" { exit(2) }
        guard settings.userHidden == expected,
              defaults.string(forKey: "future-setting-sentinel") == "fixture-only" else { exit(5) }
        print("preferences-verified")
    }
}
