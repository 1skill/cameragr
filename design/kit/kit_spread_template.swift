import AppKit
// Maintenance spread: the whole inner screen (1536x1024 canvas, screen x 40..1496 = 1456x1024 bag px,
// corners r84, spine at bag x 704..752). Same bag shell as the films spread.
let W = 1536.0, H = 1024.0, X0 = 40.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)
func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: X0 + x, y: y, width: w, height: h) }
func fill(_ r: CGRect, _ c: NSColor, _ rad: Double = 0) { cg.setFillColor(c.cgColor); cg.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); cg.fillPath() }
fill(CGRect(x: 0, y: 0, width: W, height: H), NSColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1))
fill(R(0, 0, 1456, 1024), NSColor(red: 0.45, green: 0.3, blue: 0.18, alpha: 1), 84)        // leather shell
fill(R(26, 26, 678, 972), NSColor(white: 0.3, alpha: 1), 60)                                 // left page: canvas
fill(R(752, 26, 678, 972), NSColor(white: 0.3, alpha: 1), 60)                                // right page: canvas
fill(R(704, 0, 48, 1024), NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1))              // spine
var rects: [String: [Double]] = [:]
// LEFT: switch plate (3 rows) and the certificate
fill(R(60, 64, 610, 470), NSColor(white: 0.12, alpha: 1), 16); rects["plate"] = [60, 64, 610, 470]
for (i, y) in [100.0, 248, 396].enumerated() {
    let label = R(96, y, 380, 96); fill(label, NSColor(white: 0.2, alpha: 1), 6)               // engraved label recess
    let slot = R(500, y + 20, 130, 58); fill(slot, NSColor(white: 0.02, alpha: 1), 29)         // switch channel
    let lamp = R(470, y + 38, 20, 20); fill(lamp, NSColor(red: 0.6, green: 0.15, blue: 0.1, alpha: 1), 10)
    rects["label\(i)"] = [96, y, 380, 96]; rects["switch\(i)"] = [500, y + 20, 130, 58]; rects["lamp\(i)"] = [470, y + 38, 20, 20]
}
fill(R(60, 580, 610, 380), NSColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1), 4); rects["certificate"] = [60, 580, 610, 380]
fill(R(110, 860, 240, 60), NSColor(white: 0.7, alpha: 1), 6); fill(R(390, 860, 240, 60), NSColor(white: 0.7, alpha: 1), 6)
rects["restore"] = [110, 860, 240, 60]; rects["redeem"] = [390, 860, 240, 60]
// RIGHT: handbook (open, one big page area) with 4 small bookmarks at its bottom, nameplate below
fill(R(790, 60, 520, 640), NSColor(red: 0.95, green: 0.92, blue: 0.84, alpha: 1), 6); rects["book"] = [790, 60, 520, 640]
for (i, x) in [820.0, 940, 1060, 1180].enumerated() {
    fill(R(x, 700, 100, 40), [NSColor.systemRed, .systemYellow, .systemGreen, .systemBlue][i].withAlphaComponent(0.8), 6)
    rects["mark\(i)"] = [x, 700, 100, 40]
}
fill(R(830, 790, 440, 150), NSColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 1), 10); rects["nameplate"] = [830, 790, 440, 150]
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "kit_spread_template.png"))
try! JSONSerialization.data(withJSONObject: rects, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "kit_spread_rects.json"))
print("ok")
