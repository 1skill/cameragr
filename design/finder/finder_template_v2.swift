import AppKit
// Half-fold lower half (waist-level reflex finder), 1536x1024 canvas; the half (669x475 pt) is x 47..1489
// (1442x1024, 2.155 px/pt). Hinge along the TOP edge; the two BOTTOM corners rounded 55 pt = 118 px.
let W = 1536.0, H = 1024.0, X0 = 47.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)
func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: X0 + x, y: y, width: w, height: h) }
func fill(_ p: CGPath, _ c: NSColor) { cg.setFillColor(c.cgColor); cg.addPath(p); cg.fillPath() }
func rr(_ r: CGRect, _ rad: Double) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }
fill(CGPath(rect: CGRect(x: 0, y: 0, width: W, height: H), transform: nil), NSColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1))
// the half: square top (hinge), rounded bottom corners
let half = NSBezierPath(); let r = 118.0, x0 = X0, x1 = X0 + 1442
half.move(to: NSPoint(x: x0, y: 0)); half.line(to: NSPoint(x: x1, y: 0)); half.line(to: NSPoint(x: x1, y: H - r))
half.appendArc(withCenter: NSPoint(x: x1 - r, y: H - r), radius: r, startAngle: 0, endAngle: 90)
half.line(to: NSPoint(x: x0 + r, y: H)); half.appendArc(withCenter: NSPoint(x: x0 + r, y: H - r), radius: r, startAngle: 90, endAngle: 180)
half.close(); fill(half.cgPath, NSColor(white: 0.2, alpha: 1))
fill(CGPath(rect: R(0, 0, 1442, 40), transform: nil), NSColor(white: 0.32, alpha: 1))      // hinge edge
let window = R(43, 150, 1125, 750); fill(rr(window, 14), .black)
let vial = R(1205, 790, 180, 70); fill(rr(vial, 35), NSColor(red: 0.6, green: 0.8, blue: 0.4, alpha: 1))
let slot = R(1215, 170, 170, 170); fill(rr(slot, 28), NSColor(white: 0.08, alpha: 1))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "finder_template_v2.png"))
func a(_ r: CGRect) -> [Double] { [r.minX - X0, r.minY, r.width, r.height] }
let rects: [String: Any] = ["window": a(window), "vial": a(vial), "buttonWell": a(slot), "half": [47, 0, 1442, 1024], "cornerRadius": 118, "pxPerPt": 2.155]
try! JSONSerialization.data(withJSONObject: rects, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "finder_rects_v2.json"))
print("ok")
