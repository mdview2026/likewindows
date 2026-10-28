#!/usr/bin/env swift
//
// 生成 App 图标：Resources/AppIcon.icns
//   swift scripts/make-icon.swift
//
// 设计：蓝色渐变圆角方块（macOS squircle）+ 白色「分屏窗口」图形，
// 表达「把窗口左右贴边 / 像 Windows 一样管理窗口」。
// 纯矢量绘制，各尺寸单独渲染，保证 16px 下依然清晰。
//
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetDir = root.appendingPathComponent("build/AppIcon.iconset")
let icnsPath = root.appendingPathComponent("Resources/AppIcon.icns")
let previewPath = root.appendingPathComponent("build/icon-1024.png")

func draw(size S: CGFloat) {
    let inset = S * 0.098          // 与 macOS 图标留白一致
    let radius = S * 0.2237        // squircle 圆角
    let body = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)

    // 背景：Windows 蓝渐变
    let squircle = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = S * 0.022
    shadow.shadowOffset = NSSize(width: 0, height: -S * 0.012)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSGradient(colors: [
        NSColor(srgbRed: 0.31, green: 0.60, blue: 1.00, alpha: 1),   // 顶部亮蓝
        NSColor(srgbRed: 0.04, green: 0.33, blue: 0.83, alpha: 1),   // 底部深蓝
    ])?.draw(in: squircle, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 顶部内高光
    NSGraphicsContext.saveGraphicsState()
    squircle.setClip()
    NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.28),
        NSColor.white.withAlphaComponent(0.0),
    ])?.draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 窗口图形：两块面板 + 中间分隔线
    let winW = S * 0.50
    let winH = S * 0.38
    let winX = (S - winW) / 2
    let winY = (S - winH) / 2
    let winRect = NSRect(x: winX, y: winY, width: winW, height: winH)
    let winRadius = S * 0.055
    let lineW = max(S * 0.026, 1.5)

    let gap = S * 0.022
    let paneW = (winW - gap) / 2

    // 左面板：实心白（被「贴」在左边）
    let left = NSRect(x: winRect.minX, y: winRect.minY, width: paneW, height: winH)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: left, xRadius: winRadius, yRadius: winRadius).fill()

    // 右面板：半透明白，暗示「另一半空间」
    NSColor.white.withAlphaComponent(0.42).setFill()
    let right = NSRect(x: winRect.maxX - paneW, y: winRect.minY, width: paneW, height: winH)
    NSBezierPath(roundedRect: right, xRadius: winRadius, yRadius: winRadius).fill()

    // 右面板描边，小尺寸下也能看出是「两块」
    if S >= 32 {
        NSColor.white.withAlphaComponent(0.85).setStroke()
        let outline = NSBezierPath(roundedRect: right.insetBy(dx: lineW / 2, dy: lineW / 2),
                                   xRadius: winRadius, yRadius: winRadius)
        outline.lineWidth = lineW
        outline.stroke()
    }

    // 左面板里的「标题栏」一条，弱化纯色块的呆板感
    if S >= 64 {
        NSColor(srgbRed: 0.04, green: 0.33, blue: 0.83, alpha: 0.55).setFill()
        let bar = NSRect(x: left.minX + paneW * 0.16, y: left.maxY - winH * 0.26,
                         width: paneW * 0.42, height: winH * 0.085)
        NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()
    }
}

func render(size S: CGFloat) -> Data {
    let px = Int(S)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: px, pixelsHigh: px,
                                    bitsPerSample: 8, samplesPerPixel: 4,
                                    hasAlpha: true, isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep)
    else { fatalError("无法创建 \(px)px 位图") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true
    context.imageInterpolation = .high
    draw(size: S)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("无法编码 \(px)px PNG")
    }
    return data
}

// ---------- 生成 iconset ----------
try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let variants: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let data = render(size: variant.size)
    try data.write(to: iconsetDir.appendingPathComponent("\(variant.name).png"))
}

// 1024 预览图（用于目视检查）
try render(size: 1024).write(to: previewPath)
try FileManager.default.createDirectory(at: icnsPath.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)

// ---------- 打包成 icns ----------
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    print("iconutil 失败")
    exit(1)
}

let size = (try? FileManager.default.attributesOfItem(atPath: icnsPath.path)[.size] as? Int) ?? 0
print("✅ \(icnsPath.path)（\(size ?? 0) 字节，\(variants.count) 个尺寸）")
print("   预览：\(previewPath.path)")
