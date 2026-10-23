// Draws the 1024×1024 app icon. Run through scripts/make_icon.sh, which turns it into AppIcon.icns.
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Rounded-square background in the macOS icon grid (824pt body inside 1024pt canvas).
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let background = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGradient(
    starting: NSColor(calibratedRed: 0.27, green: 0.35, blue: 0.95, alpha: 1),
    ending: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.45, alpha: 1)
)!.draw(in: background, angle: -90)

// A screen with a pause sign: the TV picture is held.
let screen = NSRect(x: 230, y: 360, width: 564, height: 360)
NSColor.white.setFill()
NSBezierPath(roundedRect: screen, xRadius: 36, yRadius: 36).fill()
NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.55, alpha: 1).setFill()
NSBezierPath(roundedRect: screen.insetBy(dx: 26, dy: 26), xRadius: 18, yRadius: 18).fill()

NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 445, y: 450, width: 48, height: 180), xRadius: 12, yRadius: 12).fill()
NSBezierPath(roundedRect: NSRect(x: 531, y: 450, width: 48, height: 180), xRadius: 12, yRadius: 12).fill()

// Stand.
NSBezierPath(roundedRect: NSRect(x: 482, y: 280, width: 60, height: 80), xRadius: 8, yRadius: 8).fill()
NSBezierPath(roundedRect: NSRect(x: 382, y: 250, width: 260, height: 40), xRadius: 20, yRadius: 20).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
