import Foundation
let folder=URL(fileURLWithPath:CommandLine.arguments[1])
let file=folder.appendingPathComponent("prefs.plist")
let store=try FilePreferenceStore(file:file)
let overlay=OverlayPreferences(defaults:store)
let gradients=ProgressGradientPreferences(defaults:store)
precondition(!overlay.userHidden)
overlay.userHidden=true
var palette=ProgressGradientSettings.standard
palette.stops[0].red=0.83
precondition(gradients.save(palette))
let reopened=try FilePreferenceStore(file:file)
precondition(OverlayPreferences(defaults:reopened).userHidden)
precondition(ProgressGradientPreferences(defaults:reopened).load()==palette)
let untouched=folder.appendingPathComponent("other.plist")
let other=try FilePreferenceStore(file:untouched)
precondition(!other.bool(forKey:OverlayPreferences.hiddenKey))
precondition(!FileManager.default.fileExists(atPath:untouched.path))
let broken=try FilePreferenceStore(file:folder.appendingPathComponent("absent/prefs.plist"))
precondition(!ProgressGradientPreferences(defaults:broken).save(palette))
let link=folder.appendingPathComponent("link.plist")
try FileManager.default.createSymbolicLink(at:link,withDestinationURL:file)
do { _=try FilePreferenceStore(file:link); preconditionFailure("symlink allowed") } catch {}
print("PASS isolated file preferences: save, reopen, separate roots, write failure, symlink rejection; no standard domain")
