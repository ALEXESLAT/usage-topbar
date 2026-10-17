import Foundation

// This helper is embedded only in isolated fixtures, never the production app.
@main struct PreferencesProbe {
    static func main() {
        let args = CommandLine.arguments
        guard args.count == 4, args[1].hasPrefix("local.alex.usage-topbar.fixture."),
              let defaults = UserDefaults(suiteName: args[1]) else { exit(2) }
        let settings = OverlayPreferences(defaults: defaults)
        let gradients = ProgressGradientPreferences(defaults: defaults)
        let palette = ProgressGradientSettings(stops: [
            ProgressGradientStop(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, location: 0, red: 0.2, green: 0.8, blue: 0.4, alpha: 0.7),
            ProgressGradientStop(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, location: 1, red: 0.9, green: 0.1, blue: 0.6)
        ])
        let expected = args[3] == "hidden"
        if args[2] == "seed" {
            guard defaults.object(forKey: OverlayPreferences.hiddenKey) == nil,
                  !settings.userHidden else { exit(3) }
            settings.userHidden = expected
            guard gradients.save(palette) else { exit(6) }
            defaults.set("fixture-only", forKey: "future-setting-sentinel")
            guard defaults.synchronize() else { exit(4) }
        } else if args[2] != "verify" { exit(2) }
        guard settings.userHidden == expected, gradients.load() == palette,
              defaults.string(forKey: "future-setting-sentinel") == "fixture-only" else { exit(5) }
        print("preferences-verified")
    }
}
