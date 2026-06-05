#!/usr/bin/env swift
//
// Procedural macOS app icon for GramartEnglish.
//
// Draws a 1024×1024 squircle with a teal→mint vertical gradient, an open
// book glyph, and three sound-wave arcs over the right page — read + listen,
// the two skills the MVP trains. Saved as PNG; the outer build script
// downsamples to all required sizes via `sips`.
//
// Run:  swift scripts/make-icon.swift /path/to/out.png

import Foundation
import AppKit
import CoreGraphics

let outPath: String = CommandLine.arguments.dropFirst().first ?? {
    fputs("usage: make-icon.swift <out.png>\n", stderr); exit(2)
}()

let size: CGFloat = 1024
let scale: CGFloat = 1
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

guard let ctx = CGContext(
    data: nil,
    width: Int(size * scale),
    height: Int(size * scale),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext init failed") }

ctx.scaleBy(x: scale, y: scale)

// Background: rounded "squircle" using the Big Sur-style corner ratio 0.225×.
let cornerRadius: CGFloat = size * 0.225
let backgroundRect = CGRect(x: 0, y: 0, width: size, height: size)
let backgroundPath = CGPath(roundedRect: backgroundRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(backgroundPath); ctx.clip()

// Vertical gradient: deep teal at top → mint at bottom. Two-stop.
let topColor = CGColor(srgbRed: 0.04, green: 0.36, blue: 0.42, alpha: 1.0)
let bottomColor = CGColor(srgbRed: 0.32, green: 0.78, blue: 0.62, alpha: 1.0)
let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

// Inner light glow for depth — radial soft white near top.
let glowColors = [
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18),
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
]
let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: size * 0.5, y: size * 0.78), startRadius: 0,
    endCenter: CGPoint(x: size * 0.5, y: size * 0.78), endRadius: size * 0.55,
    options: []
)

// ----- Open book -----
//
// Two pages meeting at the centerline, slight downward tilt outward to suggest depth.
// Drawn in soft cream so it pops against the teal background.

let bookCx = size * 0.5
let bookCy = size * 0.5
let bookHalfWidth = size * 0.30
let bookHalfHeight = size * 0.21
let pageColor = CGColor(srgbRed: 0.985, green: 0.967, blue: 0.92, alpha: 1.0)
let shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35)

// Drop shadow under the book.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: shadowColor)
ctx.setFillColor(pageColor)

// Left page: subtle curve.
let leftPage = CGMutablePath()
leftPage.move(to: CGPoint(x: bookCx, y: bookCy - bookHalfHeight + 8))
leftPage.addCurve(
    to: CGPoint(x: bookCx - bookHalfWidth, y: bookCy - bookHalfHeight + 26),
    control1: CGPoint(x: bookCx - bookHalfWidth * 0.5, y: bookCy - bookHalfHeight - 4),
    control2: CGPoint(x: bookCx - bookHalfWidth * 0.9, y: bookCy - bookHalfHeight + 12)
)
leftPage.addLine(to: CGPoint(x: bookCx - bookHalfWidth, y: bookCy + bookHalfHeight - 6))
leftPage.addCurve(
    to: CGPoint(x: bookCx, y: bookCy + bookHalfHeight),
    control1: CGPoint(x: bookCx - bookHalfWidth * 0.7, y: bookCy + bookHalfHeight + 8),
    control2: CGPoint(x: bookCx - bookHalfWidth * 0.25, y: bookCy + bookHalfHeight + 8)
)
leftPage.closeSubpath()
ctx.addPath(leftPage); ctx.fillPath()

// Right page (mirror).
let rightPage = CGMutablePath()
rightPage.move(to: CGPoint(x: bookCx, y: bookCy - bookHalfHeight + 8))
rightPage.addCurve(
    to: CGPoint(x: bookCx + bookHalfWidth, y: bookCy - bookHalfHeight + 26),
    control1: CGPoint(x: bookCx + bookHalfWidth * 0.5, y: bookCy - bookHalfHeight - 4),
    control2: CGPoint(x: bookCx + bookHalfWidth * 0.9, y: bookCy - bookHalfHeight + 12)
)
rightPage.addLine(to: CGPoint(x: bookCx + bookHalfWidth, y: bookCy + bookHalfHeight - 6))
rightPage.addCurve(
    to: CGPoint(x: bookCx, y: bookCy + bookHalfHeight),
    control1: CGPoint(x: bookCx + bookHalfWidth * 0.7, y: bookCy + bookHalfHeight + 8),
    control2: CGPoint(x: bookCx + bookHalfWidth * 0.25, y: bookCy + bookHalfHeight + 8)
)
rightPage.closeSubpath()
ctx.addPath(rightPage); ctx.fillPath()
ctx.restoreGState()

// Center spine line (subtle gray).
ctx.setStrokeColor(CGColor(srgbRed: 0.55, green: 0.43, blue: 0.30, alpha: 0.4))
ctx.setLineWidth(3)
ctx.move(to: CGPoint(x: bookCx, y: bookCy - bookHalfHeight + 8))
ctx.addLine(to: CGPoint(x: bookCx, y: bookCy + bookHalfHeight))
ctx.strokePath()

// Text lines on the left page — three short, decorative.
ctx.setFillColor(CGColor(srgbRed: 0.40, green: 0.35, blue: 0.28, alpha: 0.65))
for i in 0..<3 {
    let y = bookCy - 60 + CGFloat(i) * 36
    let lineWidth = bookHalfWidth * 0.70 - CGFloat(i) * 24
    let rect = CGRect(x: bookCx - bookHalfWidth * 0.85, y: y, width: lineWidth, height: 14)
    let path = CGPath(roundedRect: rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
    ctx.addPath(path); ctx.fillPath()
}

// ----- Sound waves over right page -----
// Three concentric arcs in white-ish, increasing radius, decreasing alpha
// — represents "listen". Centered slightly inside the right page edge.
let waveOrigin = CGPoint(x: bookCx + bookHalfWidth * 0.40, y: bookCy + 6)
ctx.setLineCap(.round)
for i in 0..<3 {
    let radius = 50.0 + CGFloat(i) * 48
    let alpha = 0.95 - CGFloat(i) * 0.28
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
    ctx.setLineWidth(16 - CGFloat(i) * 3)
    let arc = CGMutablePath()
    arc.addArc(
        center: waveOrigin,
        radius: radius,
        startAngle: -CGFloat.pi / 4,
        endAngle: CGFloat.pi / 4,
        clockwise: false
    )
    ctx.addPath(arc); ctx.strokePath()
}

// Speaker bullet at the wave origin.
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
let bulletRect = CGRect(x: waveOrigin.x - 22, y: waveOrigin.y - 22, width: 44, height: 44)
ctx.fillEllipse(in: bulletRect)

// ----- Write to PNG -----
guard let cgImage = ctx.makeImage() else { fatalError("makeImage failed") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("CGImageDestinationCreateWithURL failed for \(outPath)")
}
CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("PNG write failed") }
print("wrote \(outPath) (\(Int(size))×\(Int(size)))")
