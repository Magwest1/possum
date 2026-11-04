// Turns the square source artwork into a macOS-style AppIcon.icns.
//
// The source has an opaque white background outside the rounded tile; this
// flood-fills that background to transparent from the corners, crops to the
// tile, and places it on Apple's 1024 grid (824 pt tile, 100 pt margins).
//
// Usage: swift scripts/make-icon.swift Resources/AppIcon-source.webp Resources/AppIcon.icns
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-icon.swift <source> <output.icns>\n".data(using: .utf8)!)
    exit(2)
}
let sourceURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

guard let source = NSImage(contentsOf: sourceURL),
      let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("cannot read \(sourceURL.path)")
}

let width = cg.width, height = cg.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

// Flood fill near-white background from the four corners.
func isBackground(_ i: Int) -> Bool {
    pixels[i] > 225 && pixels[i + 1] > 225 && pixels[i + 2] > 225 && pixels[i + 3] > 0
}
var stack = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
var visited = [Bool](repeating: false, count: width * height)
while let (x, y) = stack.popLast() {
    guard x >= 0, y >= 0, x < width, y < height else { continue }
    let p = y * width + x
    guard !visited[p] else { continue }
    visited[p] = true
    let i = p * 4
    guard isBackground(i) else { continue }
    pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0; pixels[i + 3] = 0
    stack.append(contentsOf: [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
}

// Soften the one-pixel fringe left next to the cleared area.
var softened = pixels
for y in 1..<(height - 1) {
    for x in 1..<(width - 1) {
        let i = (y * width + x) * 4
        guard pixels[i + 3] == 255 else { continue }
        let neighbours = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        if neighbours.contains(where: { pixels[($0.1 * width + $0.0) * 4 + 3] == 0 }) && isBackground(i) {
            softened[i] /= 2; softened[i + 1] /= 2; softened[i + 2] /= 2; softened[i + 3] /= 2
        }
    }
}
pixels = softened

// Bounding box of remaining content.
var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}

let cleared = ctx.makeImage()!.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = g
    g.imageInterpolation = .high
    let scale = CGFloat(size) / 1024
    let tile = 824 * scale, margin = 100 * scale
    g.cgContext.draw(cleared, in: CGRect(x: margin, y: margin, width: tile, height: tile))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: outputURL.deletingPathExtension().appendingPathExtension("png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
