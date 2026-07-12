#!/usr/bin/env swift

import AppKit
import Foundation

private struct IconVariant {
    let filename: String
    let pixels: Int
}

private let variants: [IconVariant] = [
    .init(filename: "icon_16x16.png", pixels: 16),
    .init(filename: "icon_16x16@2x.png", pixels: 32),
    .init(filename: "icon_32x32.png", pixels: 32),
    .init(filename: "icon_32x32@2x.png", pixels: 64),
    .init(filename: "icon_128x128.png", pixels: 128),
    .init(filename: "icon_128x128@2x.png", pixels: 256),
    .init(filename: "icon_256x256.png", pixels: 256),
    .init(filename: "icon_256x256@2x.png", pixels: 512),
    .init(filename: "icon_512x512.png", pixels: 512),
    .init(filename: "icon_512x512@2x.png", pixels: 1024)
]

private let defaultOutput = "EasySubs/Resources/Assets.xcassets/AppIcon.appiconset"
private let outputPath = CommandLine.arguments.dropFirst().first ?? defaultOutput
private let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.restoreGraphicsState() }

    let context = graphics.cgContext
    let s = CGFloat(size)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // macOS-style rounded tile with breathing room for its shadow.
    let tile = CGRect(x: s * 0.055, y: s * 0.075, width: s * 0.89, height: s * 0.89)
    let tilePath = roundedRect(tile, radius: s * 0.205)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.025), blur: s * 0.055,
                      color: NSColor(calibratedWhite: 0.04, alpha: 0.36).cgColor)
    context.addPath(tilePath)
    context.setFillColor(NSColor(calibratedRed: 0.16, green: 0.12, blue: 0.46, alpha: 1).cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let backgroundColors = [
        NSColor(calibratedRed: 0.13, green: 0.68, blue: 1.00, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.02, green: 0.46, blue: 0.99, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.00, green: 0.31, blue: 0.92, alpha: 1).cgColor
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: backgroundColors, locations: [0, 0.52, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )

    // Soft atmospheric highlights give depth without relying on bitmap effects.
    let glowGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [NSColor.white.withAlphaComponent(0.24).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: s * 0.28, y: s * 0.79), startRadius: 0,
        endCenter: CGPoint(x: s * 0.28, y: s * 0.79), endRadius: s * 0.58,
        options: []
    )

    context.restoreGState()

    // Render the exact SF Symbol used by ContentView's in-app header.
    let captionBlue = NSColor(calibratedRed: 0.02, green: 0.46, blue: 0.99, alpha: 1)
    let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: s * 0.48, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [captionBlue, .white]))
    guard let symbol = NSImage(systemSymbolName: "captions.bubble.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfiguration) else {
        throw CocoaError(.featureUnsupported)
    }

    let available = CGSize(width: s * 0.53, height: s * 0.53)
    let scale = min(available.width / symbol.size.width, available.height / symbol.size.height)
    let symbolSize = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
    let symbolRect = CGRect(
        x: (s - symbolSize.width) / 2,
        y: (s - symbolSize.height) / 2 - s * 0.012,
        width: symbolSize.width,
        height: symbolSize.height
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.014), blur: s * 0.035,
                      color: NSColor(calibratedWhite: 0.03, alpha: 0.24).cgColor)
    symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
    context.restoreGState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
for variant in variants {
    let data = try drawIcon(size: variant.pixels)
    try data.write(to: outputURL.appendingPathComponent(variant.filename), options: .atomic)
    print("Generated \(variant.filename) (\(variant.pixels)×\(variant.pixels))")
}
