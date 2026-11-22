import AppKit
// Maintenance kit: replaces the right page of the bag (752,26,678,972 in bag pixels).
// Canvas 1024x1536 portrait; the page is x 0..1024, y 34..1502 (scale 1024/678 = 1.5103).
let W = 1024.0, H = 1536.0, Y0 = 34.0, k = 1024.0 / 678.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)
func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: x * k, y: Y0 + y * k, width: w * k, height: h * k) }
func fill(_ r: CGRect, _ c: NSColor, _ rad: Double = 0) { cg.setFillColor(c.cgColor); cg.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); cg.fillPath() }
fill(CGRect(x: 0, y: 0, width: W, height: H), NSColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1))
fill(R(0, 0, 678, 972), NSColor(white: 0.3, alpha: 1), 60 * k)                       // dark canvas lid lining
fill(R(24, 64, 290, 400), NSColor(white: 0.12, alpha: 1), 14)                          // switch plate
var rects: [String: [Double]] = [:]
for (i, y) in [110.0, 230, 350].enumerated() {
    let slot = R(44, y, 96, 52); fill(slot, NSColor(white: 0.02, alpha: 1), 26)       // switch slot
    let lamp = R(152, y + 16, 20, 20); fill(lamp, NSColor(red: 0.6, green: 0.15, blue: 0.1, alpha: 1), 10)
    let label = R(184, y + 6, 118, 40); fill(label, NSColor(white: 0.2, alpha: 1), 4)
    rects["switch\(i)"] = [44, y, 96, 52]; rects["lamp\(i)"] = [152, y + 16, 20, 20]; rects["label\(i)"] = [184, y + 6, 118, 40]
}
let book = R(334, 64, 300, 540); fill(book, NSColor(red: 0.95, green: 0.92, blue: 0.84, alpha: 1), 6)   // booklet, open page
rects["bookPage"] = [334, 64, 300, 540]
for (i, y) in [90.0, 200, 310, 420].enumerated() {
    let tab = R(634, y, 30, 96); fill(tab, [NSColor.systemRed, .systemYellow, .systemGreen, .systemBlue][i].withAlphaComponent(0.8), 6)
    rects["tab\(i)"] = [634, y, 30, 96]
}
let cert = R(24, 636, 630, 300); fill(cert, NSColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1), 4)   // certificate, leather corners
rects["certificate"] = [24, 636, 630, 300]
let b1 = R(70, 860, 240, 52), b2 = R(368, 860, 240, 52)
fill(b1, NSColor(white: 0.7, alpha: 1), 6); fill(b2, NSColor(white: 0.7, alpha: 1), 6)
rects["restore"] = [70, 860, 240, 52]; rects["redeem"] = [368, 860, 240, 52]
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "kit_template.png"))
try! JSONSerialization.data(withJSONObject: rects, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "kit_rects.json"))
print("ok")
