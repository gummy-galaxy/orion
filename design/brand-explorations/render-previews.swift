import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let rows: [(String, String, String, String, String)] = [
    ("ORION", "Belt / constellation", "orion-belt", "Orbit / network", "orion-orbit"),
    ("STAR CHARTER", "Folded route", "star-charter", "Compass rose", "star-charter-compass"),
    ("ARTEMIS", "Bow / arrow", "artemis", "Moon / arrow", "artemis-arrow"),
]

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: 1
    )
}

func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, color ink: NSColor, bold: Bool = false) {
    let font = bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: ink])
}

for (title, leftLabel, leftName, rightLabel, rightName) in rows {
    let width = 940
    let height = 432
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not make preview bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    color(0xf4f6f5).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    label(title, x: 36, y: 378, size: 28, color: color(0x173038), bold: true)
    label("256 px artwork + 64 px Dock preview", x: 36, y: 352, size: 16, color: color(0x53676d))
    let entries = [(leftLabel, leftName, CGFloat(34)), (rightLabel, rightName, CGFloat(482))]
    for (caption, name, x) in entries {
        color(0xffffff).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 31, width: 425, height: 298), xRadius: 24, yRadius: 24).fill()
        label(caption, x: x + 22, y: 295, size: 20, color: color(0x24373e), bold: true)
        let base = root.appendingPathComponent("previews/\(name)")
        guard let large = NSImage(contentsOf: base.appendingPathComponent("256x256.png")),
              let small = NSImage(contentsOf: base.appendingPathComponent("64x64.png")) else {
            fatalError("Missing preview for \(name)")
        }
        large.draw(in: NSRect(x: x + 25, y: 50, width: 224, height: 224))
        small.draw(in: NSRect(x: x + 289, y: 110, width: 64, height: 64))
        label("64 px", x: x + 295, y: 87, size: 14, color: color(0x6a797e))
    }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let output = root.appendingPathComponent("previews/\(leftName)-comparison.png")
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode preview")
    }
    try png.write(to: output)
    print(output.path)
}
