// Draws the InfoMétrie app icon: the wordmark's pictogram, a white "i" on a green speech bubble whose
// bottom-left corner is sharp, centred on a paper background.
// Writes the light, dark and tinted 1024 px variants into the asset catalog.
// Run: swift scripts/make_app_icon.swift
import AppKit

let side = 1024
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let folder = root.appendingPathComponent("Infometrie/Resources/Assets.xcassets/AppIcon.appiconset")

/// One appearance: a vertical background gradient, the bubble and the letter inside it.
struct Variant {
    let file: String
    let top: UInt32
    let bottom: UInt32
    let bubble: UInt32
    let letter: UInt32
}

// Light: green bubble on paper, like the wordmark. Dark: the app's dark green on ink.
// Tinted: grayscale that iOS colours, the letter cut out of a white bubble.
// A full green background with a white bubble was avoided: it reads like a messaging app.
let variants = [
    Variant(file: "AppIcon.png", top: 0xFFFFFF, bottom: 0xEEF0F1, bubble: 0x17753A, letter: 0xFFFFFF),
    Variant(file: "AppIcon-dark.png", top: 0x1D1F22, bottom: 0x08090A, bubble: 0x4ADE80, letter: 0x0B1F12),
    Variant(file: "AppIcon-tinted.png", top: 0x000000, bottom: 0x000000, bubble: 0xFFFFFF, letter: 0x000000),
]

// Proportions shared with `BrandTile` in Design.swift, scaled to the bubble's side.
let bubbleSide: CGFloat = 600
let roundRadius = bubbleSide * 0.3
let sharpRadius = bubbleSide * 0.04
let dotDiameter = bubbleSide * 0.157
let dotGap = bubbleSide * 0.064
let stemWidth = bubbleSide * 0.128
let stemHeight = bubbleSide * 0.36

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(_ variant: Variant) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // Opaque RGB: App Store icons must not carry transparency.
    guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw CocoaError(.fileWriteUnknown)
    }
    // Work in a top-left origin so the geometry reads like the design.
    context.translateBy(x: 0, y: CGFloat(side)); context.scaleBy(x: 1, y: -1)
    let gradient = CGGradient(colorsSpace: space, colors: [color(variant.top), color(variant.bottom)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: side), options: [])

    // The bubble: rounded corners except the bottom-left one, which points like a speech bubble.
    let origin = (CGFloat(side) - bubbleSide) / 2
    let bubble = CGRect(x: origin, y: origin, width: bubbleSide, height: bubbleSide)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: bubble.minX + roundRadius, y: bubble.minY))
    path.addArc(tangent1End: CGPoint(x: bubble.maxX, y: bubble.minY), tangent2End: CGPoint(x: bubble.maxX, y: bubble.maxY), radius: roundRadius)
    path.addArc(tangent1End: CGPoint(x: bubble.maxX, y: bubble.maxY), tangent2End: CGPoint(x: bubble.minX, y: bubble.maxY), radius: roundRadius)
    path.addArc(tangent1End: CGPoint(x: bubble.minX, y: bubble.maxY), tangent2End: CGPoint(x: bubble.minX, y: bubble.minY), radius: sharpRadius)
    path.addArc(tangent1End: CGPoint(x: bubble.minX, y: bubble.minY), tangent2End: CGPoint(x: bubble.maxX, y: bubble.minY), radius: roundRadius)
    path.closeSubpath()
    context.setFillColor(color(variant.bubble))
    context.addPath(path)
    context.fillPath()

    // The "i": a dot over a rounded stem, centred in the bubble.
    let centerX = CGFloat(side) / 2
    let letterTop = CGFloat(side) / 2 - (dotDiameter + dotGap + stemHeight) / 2
    context.setFillColor(color(variant.letter))
    context.fillEllipse(in: CGRect(x: centerX - dotDiameter / 2, y: letterTop, width: dotDiameter, height: dotDiameter))
    let stem = CGRect(x: centerX - stemWidth / 2, y: letterTop + dotDiameter + dotGap, width: stemWidth, height: stemHeight)
    context.addPath(CGPath(roundedRect: stem, cornerWidth: stemWidth / 2, cornerHeight: stemWidth / 2, transform: nil))
    context.fillPath()

    guard let image = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: folder.appendingPathComponent(variant.file))
}

for variant in variants { try render(variant) }
print("App icon written: \(variants.map(\.file).joined(separator: ", "))")
