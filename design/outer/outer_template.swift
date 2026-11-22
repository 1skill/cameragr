import AppKit
// Outer screen as the body plate maps it: 1536x1024, top corners r134, bottom r18, front-camera island top-left.
let W = 1536.0, H = 1024.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
// AppKit y-up: top corners at high y
let p = NSBezierPath(); let rt = 134.0, rb = 18.0
p.move(to: NSPoint(x: rb, y: 0)); p.line(to: NSPoint(x: W - rb, y: 0))
p.appendArc(withCenter: NSPoint(x: W - rb, y: rb), radius: rb, startAngle: 270, endAngle: 360)
p.line(to: NSPoint(x: W, y: H - rt)); p.appendArc(withCenter: NSPoint(x: W - rt, y: H - rt), radius: rt, startAngle: 0, endAngle: 90)
p.line(to: NSPoint(x: rt, y: H)); p.appendArc(withCenter: NSPoint(x: rt, y: H - rt), radius: rt, startAngle: 90, endAngle: 180)
p.line(to: NSPoint(x: 0, y: rb)); p.appendArc(withCenter: NSPoint(x: rb, y: rb), radius: rb, startAngle: 180, endAngle: 270)
p.close(); NSColor(white: 0.35, alpha: 1).setFill(); p.fill()
NSColor.black.setFill(); NSBezierPath(roundedRect: NSRect(x: 35, y: H - 260, width: 165, height: 225), xRadius: 40, yRadius: 40).fill()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "outer_template.png"))
print("ok")
