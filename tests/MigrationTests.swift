import Foundation
let dir=URL(fileURLWithPath:CommandLine.arguments[1])
let source=dir.appendingPathComponent("source.json"), dest=dir.appendingPathComponent("destination.json")
let now=Date(timeIntervalSince1970:1800000000)
let a=String(repeating:"a",count:64), b=String(repeating:"b",count:64)
func point(_ time:Double,_ value:Double=50,account:String?=nil,series:String="codex/secondary/10080.0") -> HistoryPoint {
 HistoryPoint(reading:HistoryReading(account:account ?? a,series:series,time:now.timeIntervalSince1970+time,remaining:value,resetsAt:nil,duration:series.contains("primary") ? 18000:604800,cards:nil,availableCards:nil),gapBefore:false,event:nil)
}
func write(_ rows:[HistoryPoint],_ url:URL,version:Int=1) throws { try JSONEncoder().encode(HistoryMigration.Archive(version:version,points:rows)).write(to:url,options:.atomic) }
func rows(_ url:URL) throws -> [HistoryPoint] { try JSONDecoder().decode(HistoryMigration.Archive.self,from:Data(contentsOf:url)).points }
func check(_ condition:Bool,_ message:String) { precondition(condition,message) }
let formal=point(-3600,60), conflict=point(-3600,20)
try write([formal],dest)
try write([conflict,point(-1800),point(-1800),point(-1800,account:b),point(-1800,series:"codex/primary/300.0"),point(-120*86400),point(3600)],source)
let sourceBefore=try Data(contentsOf:source), destBefore=try Data(contentsOf:dest)
let first=try HistoryMigration.merge(source:source,destination:dest,now:now)
let merged=try rows(dest)
check(first.added==3 && first.conflicts==1 && merged.count==4,"dedup, distinct accounts/periods, conflicts, retention/future")
check(merged.contains(formal) && !merged.contains(conflict),"formal wins conflict")
check(try Data(contentsOf:source)==sourceBefore,"source unchanged")
check(try Data(contentsOf:first.backup!.appendingPathComponent("production-before-v1.json"))==destBefore,"exact backup")
let after=try Data(contentsOf:dest)
let again=try HistoryMigration.merge(source:source,destination:dest,now:now)
let repeatedData=try Data(contentsOf:dest)
check(again.added==0 && again.backup==nil && repeatedData==after,"repeat no write/backup")
let loaded=QuotaHistoryStore(file:dest,now:now)
check(loaded.points.count==4,"merged v1 readable by normal store")
for badVersion in [2] {
 try write([point(-10)],source,version:badVersion)
 do { try HistoryMigration.merge(source:source,destination:dest,now:now);fatalError("unsupported version accepted") } catch {}
 check(try Data(contentsOf:dest)==after,"invalid source leaves formal untouched")
}
try write([point(-1,account:"simulation-only")],source)
do { try HistoryMigration.merge(source:source,destination:dest,now:now);fatalError("simulation accepted") } catch {}
let simulatedEvent=HistoryReset(kind:.card,lowerBound:now.timeIntervalSince1970-30,upperBound:now.timeIntervalSince1970,exactTime:nil,inferred:false,source:"simulation")
try write([HistoryPoint(reading:point(0).reading,gapBefore:false,event:simulatedEvent)],source)
do { try HistoryMigration.merge(source:source,destination:dest,now:now);fatalError("simulation provenance accepted") } catch {}
try write([point(-30)],source)
enum Injected:Error { case failure }
do { try HistoryMigration.merge(source:source,destination:dest,now:now,afterWrite:{throw Injected.failure});fatalError("fault not injected") } catch {}
check(try Data(contentsOf:dest)==after,"post-write failure rolls back existing destination")
let absent=dir.appendingPathComponent("new/destination.json")
do { try HistoryMigration.merge(source:source,destination:absent,now:now,afterWrite:{throw Injected.failure});fatalError("fault not injected") } catch {}
check(!FileManager.default.fileExists(atPath:absent.path),"rollback originally absent destination")
let created=try HistoryMigration.merge(source:source,destination:absent,now:now)
check(created.added==1,"first upgrade to empty production history")
try Data("broken".utf8).write(to:dest)
do { try HistoryMigration.merge(source:source,destination:dest,now:now);fatalError("corrupt destination overwritten") } catch {}
check(try Data(contentsOf:dest)==Data("broken".utf8),"corrupt destination preserved")
let permissions=try FileManager.default.attributesOfItem(atPath:absent.path)[.posixPermissions] as! NSNumber
check(permissions.intValue==0o600,"private output permissions")
let upgradeFile=dir.appendingPathComponent("upgrade/history-v1.json")
let upgraded=QuotaHistoryStore(file:upgradeFile,now:now,migrationSource:source)
check(upgraded.points.count==1 && upgraded.error==nil,"normal store startup imports injected source")
let upgradedAgain=QuotaHistoryStore(file:upgradeFile,now:now,migrationSource:source)
check(upgradedAgain.points==upgraded.points,"repeated startup preserves samples")
try write([point(-2,account:"simulation-only")],source)
let failedUpgrade=QuotaHistoryStore(file:upgradeFile,now:now,migrationSource:source)
check(failedUpgrade.error != nil && failedUpgrade.points==upgraded.points,"failed import visible, existing history usable")
print("PASS migration: stable-key dedup, production conflict priority, separate accounts/periods, retention, v1 compatibility, exact backups, idempotence, invalid versions/simulation rejection, corrupt destination preservation, atomic rollback and private permissions")
if CommandLine.arguments.count>2 {
 let snapshot=URL(fileURLWithPath:CommandLine.arguments[2])
 let isolated=dir.appendingPathComponent("real-snapshot-rehearsal/history-v1.json")
 let original=try Data(contentsOf:snapshot)
 let input=try rows(snapshot)
 let result=try HistoryMigration.merge(source:snapshot,destination:isolated,now:Date())
 let output=try rows(isolated)
 check(input==output,"real snapshot full count/order/values retained")
 check(try Data(contentsOf:snapshot)==original,"real snapshot unchanged")
 let repeated=try HistoryMigration.merge(source:snapshot,destination:isolated,now:Date())
 check(repeated.added==0,"real snapshot repeat idempotent")
 let report:[String:Any] = ["count":output.count,"added":result.added,"earliest":output.first!.reading.time,"latest":output.last!.reading.time,"exactRowsPreserved":true,"simulationAccepted":false]
 print(String(data:try JSONSerialization.data(withJSONObject:report,options:.sortedKeys),encoding:.utf8)!)
}
