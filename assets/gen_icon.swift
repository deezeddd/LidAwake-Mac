import AppKit

let canvas: CGFloat = 1024
let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

// macOS Big Sur style: rounded rect inset ~10% on each side
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 22
shadow.set()
NSColor(calibratedRed: 0.32, green: 0.20, blue: 0.11, alpha: 1).setFill()
path.fill()
NSGraphicsContext.current?.restoreGraphicsState()

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.30, green: 0.18, blue: 0.10, alpha: 1),
    ending: NSColor(calibratedRed: 0.65, green: 0.45, blue: 0.28, alpha: 1)
)!
gradient.draw(in: path, angle: 90)

let config = NSImage.SymbolConfiguration(pointSize: 480, weight: .medium)
if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let symSize = symbol.size
    let target: CGFloat = 520
    let scale = min(target / symSize.width, target / symSize.height)
    let w = symSize.width * scale
    let h = symSize.height * scale

    let white = NSImage(size: symSize)
    white.lockFocus()
    symbol.draw(in: NSRect(origin: .zero, size: symSize))
    NSColor.white.set()
    NSRect(origin: .zero, size: symSize).fill(using: .sourceIn)
    white.unlockFocus()

    white.draw(in: NSRect(x: (canvas - w) / 2, y: (canvas - h) / 2 - 6, width: w, height: h))
}

image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_raw.png"
try! png.write(to: URL(fileURLWithPath: out))
print("written \(out) at \(rep.pixelsWide)x\(rep.pixelsHigh)")
