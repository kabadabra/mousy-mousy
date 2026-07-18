// Renders the app icon: 🐭 centered on a soft cheese-gradient squircle,
// 1024x1024 PNG. Run via scripts/make-icon.sh (which builds the .icns).
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Apple icon-grid content box: ~100 px inset, ~185 px corner radius at 1024.
let box = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: box, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.82, alpha: 1),
    NSColor(calibratedRed: 0.97, green: 0.84, blue: 0.52, alpha: 1),
])!.draw(in: squircle, angle: -90)

let emoji = "🐭" as NSString
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 540)]
let glyph = emoji.size(withAttributes: attrs)
emoji.draw(at: NSPoint(x: (size - glyph.width) / 2, y: (size - glyph.height) / 2 - 10),
           withAttributes: attrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to render icon bitmap")
}
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
