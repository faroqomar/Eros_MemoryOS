import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: root.appendingPathComponent("screenshots/record-regular.png"))
let bitmap = NSBitmapImageRep(data: data)!
let tree = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("regular-text-tree.json"))) as! [String: Any]
let nodes = (tree["data"] as! [String: Any])["nodes"] as! [[String: Any]]
func luminance(_ rgb: [Int]) -> Double {
  let values = rgb.map { Double($0) / 255 }.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
  return zip(values, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
}
var samples: [[String: Any]] = []
for label in ["Correct text", "Move to Trash"] {
  let node = nodes.first { ($0["label"] as? String) == label }!
  let rect = node["rect"] as! [String: Double]
  var counts: [[Int]: Int] = [:]
  for y in Int(rect["y"]!)..<Int(rect["y"]! + rect["height"]!) {
    for x in Int(rect["x"]!)..<Int(rect["x"]! + rect["width"]!) {
      if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
        let rgb = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
        counts[rgb, default: 0] += 1
      }
    }
  }
  let background = counts.keys.filter { $0.max()! < 90 }.max { counts[$0]! < counts[$1]! }!
  let foreground = counts.keys.filter { $0.min()! > 180 && $0.max()! - $0.min()! < 6 && counts[$0]! >= 10 }.max { luminance($0) < luminance($1) }!
  samples.append(["label": label, "background_rgb": background, "foreground_rgb": foreground, "ratio": (luminance(foreground) + 0.05) / (luminance(background) + 0.05), "foreground_pixels": counts[foreground]!])
}
let result: [String: Any] = ["method": "Native AppKit PNG analysis: dominant dark background and brightest repeated neutral foreground tone (at least10 pixels) inside recorded native control rectangles. Ignores antialias edges; sampled controls only, not a full contrast/VoiceOver certification.", "samples": samples]
let output = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try output.write(to: root.appendingPathComponent("rendered-contrast-samples.json"))
print(String(data: output, encoding: .utf8)!)
