// Writes the InfoMétrie app icon as an Icon Composer document (AppIcon.icon): the wordmark's pictogram, an "i"
// on a speech bubble whose bottom-left corner is sharp, in white Liquid Glass on a cobalt-to-lilac field,
// the colors of interventions and citations. iOS renders the glass and the light, dark, tinted and clear
// appearances from these layers; only the light and dark colors are set here.
// Run: swift scripts/make_app_icon.swift
// Preview: Icon Composer's ictool, e.g. `ictool Infometrie/Resources/AppIcon.icon --export-image --output-file icon.png
//   --platform iOS --rendition Dark --width 1024 --height 1024 --scale 1`.
import Foundation

let side: CGFloat = 1024
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let document = root.appendingPathComponent("Infometrie/Resources/AppIcon.icon")
let assets = document.appendingPathComponent("Assets")

// Proportions shared with `BrandTile` in Design.swift, scaled to the bubble's side.
let bubbleSide: CGFloat = 600
let roundRadius = bubbleSide * 0.3
let sharpRadius = bubbleSide * 0.04
let dotDiameter = bubbleSide * 0.157
let dotGap = bubbleSide * 0.064
let stemWidth = bubbleSide * 0.128
let stemHeight = bubbleSide * 0.36

/// A number short enough for the SVG source.
func n(_ value: CGFloat) -> String { String(format: "%g", Double(value)) }

/// An Icon Composer sRGB color from a 0xRRGGBB value.
func color(_ hex: UInt32) -> String {
    let parts = [16, 8, 0].map { String(format: "%.5f", Double((hex >> UInt32($0)) & 0xFF) / 255) }
    return "srgb:" + parts.joined(separator: ",") + ",1.00000"
}

/// A 1024-point canvas holding one black shape; the document gives each layer its color.
func svg(_ body: String) -> String {
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(n(side))\" height=\"\(n(side))\" viewBox=\"0 0 \(n(side)) \(n(side))\">\(body)</svg>\n"
}

/// The bubble: rounded corners except the bottom-left one, which points like a speech bubble.
func bubble() -> String {
    let (x, y) = ((side - bubbleSide) / 2, (side - bubbleSide) / 2)
    let (right, bottom, r, k) = (x + bubbleSide, y + bubbleSide, roundRadius, sharpRadius)
    let path = "M\(n(x + r)),\(n(y)) L\(n(right - r)),\(n(y)) A\(n(r)),\(n(r)) 0 0 1 \(n(right)),\(n(y + r)) "
        + "L\(n(right)),\(n(bottom - r)) A\(n(r)),\(n(r)) 0 0 1 \(n(right - r)),\(n(bottom)) "
        + "L\(n(x + k)),\(n(bottom)) A\(n(k)),\(n(k)) 0 0 1 \(n(x)),\(n(bottom - k)) "
        + "L\(n(x)),\(n(y + r)) A\(n(r)),\(n(r)) 0 0 1 \(n(x + r)),\(n(y)) Z"
    return svg("<path d=\"\(path)\" fill=\"#000\"/>")
}

/// The "i": a dot over a rounded stem, centred in the bubble.
func letter() -> String {
    let center = side / 2
    let top = center - (dotDiameter + dotGap + stemHeight) / 2
    return svg("<circle cx=\"\(n(center))\" cy=\"\(n(top + dotDiameter / 2))\" r=\"\(n(dotDiameter / 2))\" fill=\"#000\"/>"
        + "<rect x=\"\(n(center - stemWidth / 2))\" y=\"\(n(top + dotDiameter + dotGap))\" width=\"\(n(stemWidth))\" "
        + "height=\"\(n(stemHeight))\" rx=\"\(n(stemWidth / 2))\" fill=\"#000\"/>")
}

/// A layer filled with one color per appearance.
func layer(_ name: String, light: UInt32, dark: UInt32, glass: Bool) -> [String: Any] {
    ["image-name": "\(name).svg", "name": name, "glass": glass,
     "fill-specializations": [["value": ["solid": color(light)]],
                              ["appearance": "dark", "value": ["solid": color(dark)]]]]
}

/// A decimal written as is: a Double would print 0.15 as 0.14999999999999999.
func d(_ value: String) -> Decimal { Decimal(string: value)! }

/// The field runs diagonally from cobalt to lilac, deeper in dark appearance.
func field(_ start: UInt32, _ stop: UInt32) -> [String: Any] {
    ["linear-gradient": [color(start), color(stop)],
     "orientation": ["start": ["x": d("0.15"), "y": 0], "stop": ["x": d("0.85"), "y": 1]]]
}

let icon: [String: Any] = [
    "fill-specializations": [["value": field(0x3A63D8, 0x7A55C8)],
                             ["appearance": "dark", "value": field(0x14204A, 0x2A1D4E)]],
    // The first layer sits on top: a plain letter over the glass bubble.
    "groups": [[
        "layers": [layer("letter", light: 0x4A5BD0, dark: 0xC9D6FF, glass: false),
                   layer("bubble", light: 0xFFFFFF, dark: 0x2E2A52, glass: true)],
        "lighting": "individual",
        "shadow": ["kind": "layer-color", "opacity": d("0.5")],
        "specular": true,
        "translucency": ["enabled": true, "value": d("0.4")],
    ]],
    "supported-platforms": ["squares": "shared"],
]

try? FileManager.default.removeItem(at: document)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try bubble().write(to: assets.appendingPathComponent("bubble.svg"), atomically: true, encoding: .utf8)
try letter().write(to: assets.appendingPathComponent("letter.svg"), atomically: true, encoding: .utf8)
var json = try JSONSerialization.data(withJSONObject: icon, options: [.prettyPrinted, .sortedKeys])
json.append(0x0A)
try json.write(to: document.appendingPathComponent("icon.json"))
print("App icon written: \(document.path)")
