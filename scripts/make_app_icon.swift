// Draws the InfoMétrie app icon: an "i" whose stem rises out of a sound wave, in the Stoic palette.
// Writes the light, dark and tinted 1024 px variants into the asset catalog.
// Run: swift scripts/make_app_icon.swift
import AppKit

let side = 1024
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let folder = root.appendingPathComponent("Infometrie/Resources/Assets.xcassets/AppIcon.appiconset")

/// One appearance: a vertical background gradient and the colour of the mark.
struct Variant {
    let file: String
    let top: UInt32
    let bottom: UInt32
    let mark: UInt32
}

// Light: ink on paper, like the app in light mode. Dark: paper on ink. Tinted: grayscale that iOS colours.
let variants = [
    Variant(file: "AppIcon.png", top: 0xFFFFFF, bottom: 0xE7E8EA, mark: 0x111214),
    Variant(file: "AppIcon-dark.png", top: 0x1D1F22, bottom: 0x08090A, mark: 0xF5F5F4),
    Variant(file: "AppIcon-tinted.png", top: 0x000000, bottom: 0x000000, mark: 0xFFFFFF),
]

// The wave: seven rounded bars; the middle one is the stem of the "i", taller and dotted.
let barWidth: CGFloat = 60
let spacing: CGFloat = 104
let waveCenterY: CGFloat = 575
let heights: [CGFloat] = [170, 330, 460, 560, 460, 330, 170]
// Bars fade toward the edges so the stem reads first.
let opacities: [CGFloat] = [0.42, 0.62, 0.82, 1, 0.82, 0.62, 0.42]
let dotDiameter: CGFloat = 76
let dotGap: CGFloat = 32

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

    let centerX = CGFloat(side) / 2
    for (index, height) in heights.enumerated() {
        let x = centerX + CGFloat(index - heights.count / 2) * spacing - barWidth / 2
        let bar = CGRect(x: x, y: waveCenterY - height / 2, width: barWidth, height: height)
        context.setFillColor(color(variant.mark, alpha: opacities[index]))
        context.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        context.fillPath()
    }
    let stemTop = waveCenterY - heights[heights.count / 2] / 2
    let dot = CGRect(x: centerX - dotDiameter / 2, y: stemTop - dotGap - dotDiameter, width: dotDiameter, height: dotDiameter)
    context.setFillColor(color(variant.mark))
    context.fillEllipse(in: dot)

    guard let image = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: folder.appendingPathComponent(variant.file))
}

for variant in variants { try render(variant) }
print("App icon written: \(variants.map(\.file).joined(separator: ", "))")
