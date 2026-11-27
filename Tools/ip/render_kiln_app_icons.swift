#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

/// Sculptural Kiln Ceramic App Icon Renderer for Mie & Mou (`app.chimmo`)
/// Generates opaque 1024x1024 sRGB PNG assets (`AppIcon-Light.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png`)
/// adhering to the unified Mie & Mou Mascot Bible:
/// - Clean character spacing (zero ear/wool tangents)
/// - Mie (left foreground): scalloped cotton-wool body, warm apricot-cream face, drooping ears, 2 symmetrical spiral ram horns, calm dark glazed eyes
/// - Mou (right): matte cocoa/plum ceramic body, 2 smooth upward crescent horns, broad cream snout, calm dark glazed eyes
/// - Pure neutral achromatic grayscale on Tinted mode & matte ceramic lower seal bead (zero glossy plastic highlight)

enum IconAppearance: String, CaseIterable {
    case light = "AppIcon-Light.png"
    case dark = "AppIcon-Dark.png"
    case tinted = "AppIcon-Tinted.png"
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(srgbRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

func renderIcon(appearance: IconAppearance, outputDir: URL) throws {
    let side = 1024
    guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        fatalError("Failed to allocate sRGB CGContext")
    }

    let size = CGFloat(side)
    let center = CGPoint(x: size * 0.5, y: size * 0.5)

    let bgTop: CGColor
    let bgBot: CGColor
    let glowCore: CGColor
    let ringStroke: CGColor
    let dishFill: CGColor
    let sheepWool: CGColor
    let sheepEar: CGColor
    let sheepBodyHi: CGColor
    let sheepFace: CGColor
    let sheepHorn: CGColor
    let sheepCheek: CGColor?
    let cowBody: CGColor
    let cowBodyHi: CGColor
    let cowHorn: CGColor
    let cowNose: CGColor
    let cowNostril: CGColor
    let eyeInk: CGColor
    let contourInk: CGColor
    let beadAccent: CGColor
    let beadInnerRing: CGColor

    switch appearance {
    case .light:
        bgTop = color(251, 246, 236)
        bgBot = color(238, 224, 200)
        glowCore = color(166, 60, 40, 0.16)
        ringStroke = color(166, 60, 40, 0.34)
        dishFill = color(255, 252, 246, 0.48)
        sheepWool = color(255, 253, 247)
        sheepEar = color(231, 221, 208)
        sheepBodyHi = color(255, 255, 255)
        sheepFace = color(243, 230, 212) // Unified warm cream-apricot face
        sheepHorn = color(229, 153, 0)
        sheepCheek = color(232, 122, 130, 0.34)
        cowBody = color(143, 95, 78)
        cowBodyHi = color(166, 114, 96)
        cowHorn = color(255, 228, 158)
        cowNose = color(255, 243, 226)
        cowNostril = color(90, 61, 52, 0.85)
        eyeInk = color(28, 29, 25)
        contourInk = color(35, 27, 21, 0.62)
        beadAccent = color(166, 60, 40)
        beadInnerRing = color(255, 247, 236, 0.42)
    case .dark:
        bgTop = color(18, 25, 52)
        bgBot = color(10, 14, 32)
        glowCore = color(242, 148, 118, 0.22)
        ringStroke = color(126, 203, 197, 0.38)
        dishFill = color(24, 33, 68, 0.48)
        sheepWool = color(237, 228, 213)
        sheepEar = color(216, 204, 184)
        sheepBodyHi = color(249, 244, 235)
        sheepFace = color(217, 200, 180) // Unified warm cream-apricot face (night)
        sheepHorn = color(255, 184, 77)
        sheepCheek = color(232, 122, 130, 0.30)
        cowBody = color(86, 74, 118)
        cowBodyHi = color(110, 96, 148)
        cowHorn = color(255, 210, 117)
        cowNose = color(223, 208, 190)
        cowNostril = color(58, 42, 66, 0.85)
        eyeInk = color(24, 24, 28)
        contourInk = color(216, 223, 244, 0.56)
        beadAccent = color(255, 184, 77)
        beadInnerRing = color(14, 19, 38, 0.42)
    case .tinted:
        // Strictly achromatic neutral grayscale on deep obsidian for clean iOS Home Screen tinting
        bgTop = color(28, 29, 32)
        bgBot = color(10, 11, 13)
        glowCore = color(255, 255, 255, 0.12)
        ringStroke = color(238, 240, 244, 0.42)
        dishFill = color(36, 38, 42, 0.52)
        sheepWool = color(240, 241, 243)
        sheepEar = color(214, 216, 220)
        sheepBodyHi = color(250, 251, 252)
        sheepFace = color(206, 208, 212)
        sheepHorn = color(180, 182, 188)
        sheepCheek = nil
        cowBody = color(132, 134, 140)
        cowBodyHi = color(156, 158, 164)
        cowHorn = color(228, 230, 234)
        cowNose = color(222, 224, 228)
        cowNostril = color(44, 46, 50, 0.88) // Zero chroma in Tinted
        eyeInk = color(18, 20, 22)
        contourInk = color(236, 238, 242, 0.54)
        beadAccent = color(236, 238, 242)
        beadInnerRing = color(32, 34, 38, 0.48)
    }

    // 1. Opaque backdrop
    if let bgGrad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBot] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: size * 0.5, y: size), end: CGPoint(x: size * 0.5, y: 0), options: [])
    }

    // 2. Ambient standing-wave radial bloom & centered matte medallion
    let dishCenter = CGPoint(x: center.x, y: 526)
    if let radial = CGGradient(colorsSpace: cs, colors: [glowCore, color(0, 0, 0, 0)] as CFArray, locations: [0, 1]) {
        ctx.drawRadialGradient(radial, startCenter: dishCenter, startRadius: 0, endCenter: dishCenter, endRadius: 440, options: [.drawsBeforeStartLocation])
    }
    let outerDishR: CGFloat = 418
    ctx.setFillColor(dishFill)
    ctx.fillEllipse(in: CGRect(x: dishCenter.x - outerDishR, y: dishCenter.y - outerDishR, width: outerDishR * 2, height: outerDishR * 2))

    // 3. Concentric embossed kiln grooves (crisp down to 29pt)
    for (idx, r) in [CGFloat(418), CGFloat(366)].enumerated() {
        ctx.saveGState()
        ctx.setStrokeColor(ringStroke)
        ctx.setLineWidth(idx == 0 ? 11.0 : 7.5)
        ctx.strokeEllipse(in: CGRect(x: dishCenter.x - r, y: dishCenter.y - r, width: r * 2, height: r * 2))
        ctx.restoreGState()
    }

    // 4. Sculptural Cocoa Cow (Mou - right-back warm kiln form, tucked behind with >= 30px clearance)
    let cowCenter = CGPoint(x: 682, y: 534)
    let cowW: CGFloat = 256
    let cowH: CGFloat = 244
    ctx.saveGState()

    // Contact shadow under Mou
    ctx.setFillColor(color(10, 12, 22, appearance == .light ? 0.10 : 0.28))
    ctx.fillEllipse(in: CGRect(x: cowCenter.x - 108, y: cowCenter.y - 144, width: 216, height: 34))

    // Smooth curved upward crescent horns behind torso (bows outward then curves softly inward)
    for side in [-1.0, 1.0] {
        let sx = CGFloat(side)
        ctx.saveGState()
        let horn = CGMutablePath()
        horn.move(to: CGPoint(x: cowCenter.x + sx * 42, y: cowCenter.y + 102))
        horn.addCurve(
            to: CGPoint(x: cowCenter.x + sx * 100, y: cowCenter.y + 172),
            control1: CGPoint(x: cowCenter.x + sx * 108, y: cowCenter.y + 106),
            control2: CGPoint(x: cowCenter.x + sx * 132, y: cowCenter.y + 142)
        )
        horn.addCurve(
            to: CGPoint(x: cowCenter.x + sx * 90, y: cowCenter.y + 166),
            control1: CGPoint(x: cowCenter.x + sx * 96, y: cowCenter.y + 176),
            control2: CGPoint(x: cowCenter.x + sx * 92, y: cowCenter.y + 172)
        )
        horn.addQuadCurve(
            to: CGPoint(x: cowCenter.x + sx * 76, y: cowCenter.y + 92),
            control: CGPoint(x: cowCenter.x + sx * 98, y: cowCenter.y + 132)
        )
        horn.closeSubpath()
        ctx.addPath(horn)
        ctx.setFillColor(cowHorn)
        ctx.setStrokeColor(contourInk)
        ctx.setLineWidth(6.0)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }

    // Rounded tucked ears clearing Mie cleanly
    for side in [-1.0, 1.0] {
        let ex = cowCenter.x + CGFloat(side) * 124
        let ey = cowCenter.y + 38
        let earRect = CGRect(x: ex - 32, y: ey - 19, width: 64, height: 38)
        ctx.setFillColor(cowBody)
        ctx.fillEllipse(in: earRect)
        ctx.setStrokeColor(contourInk)
        ctx.setLineWidth(5.5)
        ctx.strokeEllipse(in: earRect)
    }

    // Rounded torso with solid base fill + soft ceramic sheen
    let cowRect = CGRect(x: cowCenter.x - cowW * 0.5, y: cowCenter.y - cowH * 0.5, width: cowW, height: cowH)
    let cowPath = CGPath(roundedRect: cowRect, cornerWidth: 112, cornerHeight: 112, transform: nil)
    ctx.setFillColor(cowBody)
    ctx.addPath(cowPath)
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(cowPath)
    ctx.clip()
    if let cowGrad = CGGradient(colorsSpace: cs, colors: [cowBodyHi, cowBody] as CFArray, locations: [0, 1]) {
        ctx.drawRadialGradient(
            cowGrad,
            startCenter: CGPoint(x: cowCenter.x - 36, y: cowCenter.y + 56),
            startRadius: 0,
            endCenter: cowCenter,
            endRadius: 175,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    ctx.restoreGState()
    ctx.setStrokeColor(contourInk)
    ctx.setLineWidth(6.5)
    ctx.addPath(cowPath)
    ctx.strokePath()

    // Broad cream snout & nostrils
    let snoutRect = CGRect(x: cowCenter.x - 86, y: cowCenter.y - 90, width: 172, height: 90)
    ctx.setFillColor(cowNose)
    ctx.fillEllipse(in: snoutRect)
    ctx.setStrokeColor(contourInk)
    ctx.setLineWidth(5.0)
    ctx.strokeEllipse(in: snoutRect)
    ctx.setFillColor(cowNostril)
    for side in [-1.0, 1.0] {
        let nx = cowCenter.x + CGFloat(side) * 32 - 6.5
        ctx.fillEllipse(in: CGRect(x: nx, y: cowCenter.y - 50, width: 13, height: 10))
    }

    // Calm beaded cow eyes (solid glazed, zero startling white ring)
    for side in [-1.0, 1.0] {
        let ex = cowCenter.x + CGFloat(side) * 48
        let ey = cowCenter.y + 30
        ctx.setFillColor(eyeInk)
        ctx.fillEllipse(in: CGRect(x: ex - 13, y: ey - 13, width: 26, height: 26))
        ctx.setFillColor(color(255, 253, 248, 0.72))
        ctx.fillEllipse(in: CGRect(x: ex - 6.5, y: ey + 3.0, width: 6.5, height: 6.5))
    }
    ctx.restoreGState()

    // 5. Sculptural Porcelain Sheep (Mie - left foreground, unified cream-apricot face, drooping ears, 2 spiral ram horns)
    let sheepCenter = CGPoint(x: 344, y: 520)
    ctx.saveGState()

    // Contact shadow under Mie
    ctx.setFillColor(color(10, 12, 22, appearance == .light ? 0.12 : 0.30))
    ctx.fillEllipse(in: CGRect(x: sheepCenter.x - 110, y: sheepCenter.y - 146, width: 220, height: 34))

    // Drooping soft sheep ears behind cotton wool
    for side in [-1.0, 1.0] {
        let sx = CGFloat(side)
        ctx.saveGState()
        let ex = sheepCenter.x + sx * 130
        let ey = sheepCenter.y - 8
        ctx.translateBy(x: ex, y: ey)
        ctx.rotate(by: -sx * 0.32)
        let earRect = CGRect(x: -32, y: -19, width: 64, height: 38)
        ctx.setFillColor(sheepEar)
        ctx.fillEllipse(in: earRect)
        ctx.setStrokeColor(contourInk)
        ctx.setLineWidth(5.5)
        ctx.strokeEllipse(in: earRect)
        ctx.restoreGState()
    }

    // Scalloped cotton wool puffs (back outline then crisp unified fill)
    for stepFill in [false, true] {
        for i in 0..<8 {
            let a = CGFloat(i) * (CGFloat.pi * 2.0 / 8.0)
            let bx = sheepCenter.x + cos(a) * 94
            let by = sheepCenter.y + sin(a) * 90
            let puffRect = CGRect(x: bx - 50, y: by - 50, width: 100, height: 100)
            if stepFill {
                ctx.setFillColor(sheepWool)
                ctx.fillEllipse(in: puffRect)
            } else {
                ctx.setStrokeColor(contourInk)
                ctx.setLineWidth(12.0)
                ctx.strokeEllipse(in: puffRect)
            }
        }
    }

    // Glazed inner wool sphere gradient
    let woolCircle = CGRect(x: sheepCenter.x - 122, y: sheepCenter.y - 118, width: 244, height: 236)
    let woolPath = CGPath(ellipseIn: woolCircle, transform: nil)
    ctx.setFillColor(sheepWool)
    ctx.addPath(woolPath)
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(woolPath)
    ctx.clip()
    if let sheepGrad = CGGradient(colorsSpace: cs, colors: [sheepBodyHi, sheepWool] as CFArray, locations: [0, 1]) {
        ctx.drawRadialGradient(
            sheepGrad,
            startCenter: CGPoint(x: sheepCenter.x - 32, y: sheepCenter.y + 44),
            startRadius: 0,
            endCenter: sheepCenter,
            endRadius: 162,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    ctx.restoreGState()

    // Warm cream-apricot inner face (matches in-app ChimmoSheepView)
    let faceRect = CGRect(x: sheepCenter.x - 76, y: sheepCenter.y - 68, width: 152, height: 128)
    ctx.setFillColor(sheepFace)
    ctx.fillEllipse(in: faceRect)
    ctx.setStrokeColor(contourInk)
    ctx.setLineWidth(4.5)
    ctx.strokeEllipse(in: faceRect)

    // Two symmetrical spiral ram horns crowning Mie
    for side in [-1.0, 1.0] {
        let sx = CGFloat(side)
        ctx.saveGState()
        let horn = CGMutablePath()
        horn.move(to: CGPoint(x: sheepCenter.x + sx * 34, y: sheepCenter.y + 92))
        horn.addCurve(
            to: CGPoint(x: sheepCenter.x + sx * 112, y: sheepCenter.y + 62),
            control1: CGPoint(x: sheepCenter.x + sx * 76, y: sheepCenter.y + 144),
            control2: CGPoint(x: sheepCenter.x + sx * 130, y: sheepCenter.y + 120)
        )
        horn.addCurve(
            to: CGPoint(x: sheepCenter.x + sx * 72, y: sheepCenter.y + 66),
            control1: CGPoint(x: sheepCenter.x + sx * 102, y: sheepCenter.y + 34),
            control2: CGPoint(x: sheepCenter.x + sx * 74, y: sheepCenter.y + 44)
        )
        ctx.addPath(horn)
        ctx.setStrokeColor(contourInk)
        ctx.setLineWidth(28)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()

        ctx.addPath(horn)
        ctx.setStrokeColor(sheepHorn)
        ctx.setLineWidth(18)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Soft blush cheeks (Light/Dark only)
    if let sheepCheek {
        ctx.setFillColor(sheepCheek)
        for side in [-1.0, 1.0] {
            let cxp = sheepCenter.x + CGFloat(side) * 44
            ctx.fillEllipse(in: CGRect(x: cxp - 12, y: sheepCenter.y - 32, width: 24, height: 18))
        }
    }

    // Calm solid dark glazed eyes (consistent with Mou & in-app Mie; zero outer sclera ring)
    for side in [-1.0, 1.0] {
        let ex = sheepCenter.x + CGFloat(side) * 34
        let ey = sheepCenter.y - 2
        ctx.setFillColor(eyeInk)
        ctx.fillEllipse(in: CGRect(x: ex - 13, y: ey - 13, width: 26, height: 26))
        ctx.setFillColor(color(255, 253, 248, 0.72))
        ctx.fillEllipse(in: CGRect(x: ex - 6.5, y: ey + 3.0, width: 6.5, height: 6.5))
    }
    ctx.restoreGState()

    // 6. Matte kiln resonance seal bead anchoring bottom medallion crest (zero glossy plastic highlight)
    let beadCenter = CGPoint(x: center.x, y: 228)
    let beadR: CGFloat = 32
    ctx.setFillColor(beadAccent)
    ctx.fillEllipse(in: CGRect(x: beadCenter.x - beadR, y: beadCenter.y - beadR, width: beadR * 2, height: beadR * 2))
    ctx.setStrokeColor(contourInk)
    ctx.setLineWidth(4.5)
    ctx.strokeEllipse(in: CGRect(x: beadCenter.x - beadR, y: beadCenter.y - beadR, width: beadR * 2, height: beadR * 2))
    let innerR: CGFloat = 15
    ctx.setStrokeColor(beadInnerRing)
    ctx.setLineWidth(3.5)
    ctx.strokeEllipse(in: CGRect(x: beadCenter.x - innerR, y: beadCenter.y - innerR, width: innerR * 2, height: innerR * 2))

    guard let cgImage = ctx.makeImage() else {
        fatalError("Failed to make CGImage")
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: side, height: side)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    let outURL = outputDir.appendingPathComponent(appearance.rawValue)
    try pngData.write(to: outURL, options: .atomic)
    print("Wrote \(outURL.path) (\(pngData.count) bytes)")
}

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Chimmo/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for app in IconAppearance.allCases {
    try renderIcon(appearance: app, outputDir: outDir)
}
