import AppKit
// Camera bag v3, fitted to the Duo inner screen: 1536x1024 canvas, the screen is x 40..1496
// (1456x1024 = 951x669 pt), its four corners rounded 84 px (55 pt). Hinge at x 768.
let W = 1536.0, H = 1024.0, X0 = 40.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)
func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: X0 + x, y: y, width: w, height: h) }
func fill(_ r: CGRect, _ c: NSColor, radius: Double = 0) {
    cg.setFillColor(c.cgColor); cg.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); cg.fillPath() }
fill(CGRect(x: 0, y: 0, width: W, height: H), NSColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1))   // off screen
fill(R(0, 0, 1456, 1024), NSColor(red: 0.45, green: 0.3, blue: 0.18, alpha: 1), radius: 84)         // leather rim, screen-shaped
fill(R(26, 26, 678, 972), NSColor(white: 0.1, alpha: 1), radius: 60)                                  // left: velvet lining
fill(R(752, 26, 678, 972), NSColor(white: 0.3, alpha: 1), radius: 60)                                 // right: lid inside
fill(R(704, 0, 48, 1024), NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1))                      // spine over the hinge
var cradles: [[Double]] = [], tags: [[Double]] = [], pockets: [[Double]] = []
for col in 0..<2 { for row in 0..<5 {
    let x = 50.0 + Double(col) * 320, y = [72.0, 254, 436, 618, 800][row]
    let c = R(x, y, 234, 122), t = R(x + 248, y + 14, 62, 96)
    fill(c, .black, radius: 30); fill(t, NSColor(red: 0.93, green: 0.88, blue: 0.75, alpha: 1), radius: 6)
    cradles.append([c.minX - X0, c.minY, c.width, c.height]); tags.append([t.minX - X0, t.minY, t.width, t.height])
} }
let hint = R(120, 946, 490, 34); fill(hint, NSColor(white: 0.18, alpha: 1), radius: 8)
let card = R(790, 56, 616, 224); fill(card, NSColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1), radius: 4)
let sleeve = R(784, 300, 628, 636); fill(sleeve, NSColor(white: 0.55, alpha: 1), radius: 10)
for row in 0..<3 { for col in 0..<2 {
    let p = R(798 + Double(col) * 307, 314 + Double(row) * 207, 293, 193); fill(p, .white, radius: 4)
    pockets.append([p.minX - X0, p.minY, p.width, p.height])
} }
let tab = R(1050, 936, 96, 40); fill(tab, NSColor(red: 0.93, green: 0.88, blue: 0.75, alpha: 1), radius: 6)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "bag_fit_template.png"))
func a(_ r: CGRect) -> [Double] { [r.minX - X0, r.minY, r.width, r.height] }
let rects: [String: Any] = ["cradles": cradles, "tags": tags, "pockets": pockets, "card": a(card), "sleeve": a(sleeve),
    "hint": a(hint), "tab": a(tab), "screen": [40, 0, 1456, 1024], "cornerRadius": 84, "hinge": 728,
    "note": "coordinates in screen pixels (x already minus 40)"]
try! JSONSerialization.data(withJSONObject: rects, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "bag_fit_rects.json"))
print("ok")
