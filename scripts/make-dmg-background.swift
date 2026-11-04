// Renders the DMG window background: a soft backdrop with an arrow from the
// app icon slot to the Applications slot. Writes 1x + 2x PNGs and a combined
// HiDPI TIFF that Finder picks the right resolution from.
//
// Usage: swift scripts/make-dmg-background.swift Resources/DMG
// Layout constants must match Support/dmg-settings.py.
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/DMG")
let size = CGSize(width: 640, height: 400)
let appCenter = CGPoint(x: 170, y: 215)   // top-left origin, same as Finder
let appsCenter = CGPoint(x: 470, y: 215)

let teal = NSColor(srgbRed: 0.04, green: 0.29, blue: 0.33, alpha: 1)

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    // Flip to top-left origin so coordinates match Finder icon positions.
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)

    // Backdrop: warm off-white with a faint teal glow.
    let bg = NSGradient(colors: [NSColor(srgbRed: 0.98, green: 0.97, blue: 0.96, alpha: 1),
                                 NSColor(srgbRed: 0.92, green: 0.95, blue: 0.95, alpha: 1)])!
    bg.draw(in: CGRect(origin: .zero, size: size), angle: 90)

    // Soft wells behind the two icon slots.
    for center in [appCenter, appsCenter] {
        let well = NSBezierPath(roundedRect: CGRect(x: center.x - 84, y: center.y - 80, width: 168, height: 190), xRadius: 34, yRadius: 34)
        teal.withAlphaComponent(0.05).setFill()
        well.fill()
    }

    // Curved arrow between the slots.
    let start = CGPoint(x: appCenter.x + 96, y: appCenter.y + 4)
    let end = CGPoint(x: appsCenter.x - 100, y: appsCenter.y + 4)
    let control = CGPoint(x: (start.x + end.x) / 2, y: appCenter.y - 40)
    let shaft = NSBezierPath()
    shaft.move(to: start)
    shaft.curve(to: end, controlPoint1: control, controlPoint2: control)
    shaft.lineWidth = 4
    shaft.lineCapStyle = .round
    shaft.setLineDash([0.5, 10], count: 2, phase: 0)
    teal.withAlphaComponent(0.8).setStroke()
    shaft.stroke()

    // Filled arrowhead along the curve's end tangent, tip just past the shaft.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let tip = CGPoint(x: end.x + 8 * cos(angle), y: end.y + 8 * sin(angle))
    let length: CGFloat = 18, spread: CGFloat = .pi / 6
    let head = NSBezierPath()
    head.move(to: tip)
    head.line(to: CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread)))
    head.line(to: CGPoint(x: tip.x - length * 0.7 * cos(angle), y: tip.y - length * 0.7 * sin(angle)))
    head.line(to: CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread)))
    head.close()
    teal.withAlphaComponent(0.8).setFill()
    head.fill()

    // Caption.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    func draw(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
        // Text drawing expects an unflipped context; flip locally around the line.
        cg.saveGState()
        cg.translateBy(x: 0, y: y)
        cg.scaleBy(x: 1, y: -1)
        (text as NSString).draw(in: CGRect(x: 0, y: -font.pointSize * 1.3, width: size.width, height: font.pointSize * 1.6),
                                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        cg.restoreGState()
    }
    draw("Drag Possum into Applications", y: 62, font: .systemFont(ofSize: 17, weight: .semibold), color: teal)
    draw("Then open it from the menu bar", y: 86, font: .systemFont(ofSize: 12.5, weight: .regular), color: teal.withAlphaComponent(0.6))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let png1 = outDir.appendingPathComponent("background.png")
let png2 = outDir.appendingPathComponent("background@2x.png")
try render(scale: 1).write(to: png1)
try render(scale: 2).write(to: png2)

let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = ["-cathidpicheck", png1.path, png2.path, "-out", outDir.appendingPathComponent("background.tiff").path]
try tiffutil.run()
tiffutil.waitUntilExit()
exit(tiffutil.terminationStatus)
