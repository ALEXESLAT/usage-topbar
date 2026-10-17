import AppKit
import Foundation
struct Archive: Decodable { let version: Int; let points: [HistoryPoint] }
let data = try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
let archive = try JSONDecoder().decode(Archive.self,from:data)
let last=archive.points.last!
let points=archive.points.filter{$0.reading.account==last.reading.account && $0.reading.series==last.reading.series}.sorted{$0.reading.time<$1.reading.time}
let chart=HistoryChartView(frame:CGRect(x:0,y:0,width:766,height:276))
chart.end=Date().timeIntervalSince1970;chart.start=chart.end-7*86400
let runs=HistoryChartGeometry.runs(points)
precondition(runs.flatMap{$0}==Array(points.indices))
for run in runs where run.count>1 {
 let values=run.map{chart.point(points[$0])}
 let path=HistoryChartGeometry.roundedPath(values)
 var moves=0, vertices=Array(repeating:CGPoint.zero,count:3)
 for i in 0..<path.elementCount {
  let element=vertices.withUnsafeMutableBufferPointer{path.element(at:i,associatedPoints:$0.baseAddress!)}
  if element == .moveTo { moves+=1 }
  if element == .curveTo { precondition(vertices.allSatisfy{(20...242).contains($0.y)}) }
 }
 precondition(moves==1)
}
print("PASS real history: \(points.count) observations, \(runs.count) runs, one connected path per nontrivial run; no writes")
