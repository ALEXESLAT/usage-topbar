import Foundation
func check(_ value:Bool,_ message:String) { if !value { fatalError(message) } }
var s=ProgressGradientSettings.standard
let a=s.stops[0].id
s.move(a,to:1.5);check(s.stops[0].location==1,"drag clamps")
s.move(a,to:.nan);check(s.isValid,"nonfinite move ignored")
s.color(a,red:0.2,green:0.4,blue:0.8,alpha:0.25);check(s.stops[0].alpha==0.25,"alpha editable")
let id=s.add()!;check(s.stops.count==3,"adds stop");s.remove(id);check(s.stops.count==2,"deletes stop");s.remove(a);check(s.stops.count==2,"retains two stops")
for _ in 0..<10 { s.add() };check(s.stops.count==8,"bounded stop count")
check(s.orderedStops.map(\.location)==s.orderedStops.map(\.location).sorted(),"crossed stops sort for rendering")
let suite="UsageTopbarGradientTests."+UUID().uuidString,defaults=UserDefaults(suiteName:suite)!
defer { defaults.removePersistentDomain(forName:suite) }
let prefs=ProgressGradientPreferences(defaults:defaults)
check(prefs.load() == .standard,"default")
check(prefs.save(s) && prefs.load()==s,"save and reload")
var invalid=s;invalid.version=2;check(!prefs.save(invalid) && prefs.load()==s,"future format cannot overwrite")
defaults.set(Data("broken".utf8),forKey:ProgressGradientPreferences.key);check(prefs.load() == .standard,"corrupt config falls back")
var displayed=ProgressGradientSettings.standard,writes=0
let session=ProgressGradientSession(original:.standard,preview:{ displayed=$0 },persist:{ _ in writes+=1;return true })
session.edit { $0.color(a,red:0.1,green:0.2,blue:0.3,alpha:0.4) };check(writes==0 && displayed == .standard,"draft has no side effects")
session.setPreview(true);check(displayed==session.draft && writes==0,"preview does not persist")
session.edit { $0.move(a,to:0.3) };check(displayed==session.draft,"preview follows draft")
session.cancel();check(displayed == .standard && writes==0,"cancel restores original")
check(prefs.save(s),"seed saved settings")
let saveSession=ProgressGradientSession(original:s,preview:{ displayed=$0 },persist:{ prefs.save($0) })
saveSession.reset();check(prefs.load()==s,"reset remains draft")
check(saveSession.save() && prefs.load() == .standard,"save default persists")
saveSession.cancel();check(displayed == .standard,"close after save cannot revert")
let failing=ProgressGradientSession(original:s,preview:{ displayed=$0 },persist:{ _ in false })
failing.reset();check(!failing.save() && failing.error != nil,"failed save stays open")
failing.cancel();check(displayed==s,"cancel after failure restores")
print("PASS gradient: bounded stops, ordering, alpha, invalid input, persistence isolation, draft/preview/save/cancel/reset and failure")
