import AppKit
// App Store screenshot: a GPT scene with a flat green screen (design/appstore/shots/desk_*.png),
// the real app screenshot dropped into the green, and a headline on the empty side.
//   swiftc -O tools/appstore_compose.swift -o build-sim/compose
//   build-sim/compose <scene.png> <landscape screenshot 2868x1320> <out.png> "<title, \\n for a break>" "<subtitle>"
// compose <scene.png> <screenshot.png> <out.png> <title> <subtitle>
let a = CommandLine.arguments
func fail(_ why: String) -> Never { FileHandle.standardError.write(Data((why + "\n").utf8)); exit(1) }
guard a.count == 6 else { fail("usage: compose <scene.png> <screenshot.png> <out.png> <title> <subtitle>") }
guard let sceneData = try? Data(contentsOf: URL(fileURLWithPath: a[1])), let scene = NSBitmapImageRep(data: sceneData)
else { fail("can't read the scene \(a[1])") }
guard let shot = NSImage(contentsOfFile: a[2]) else { fail("can't read the screenshot \(a[2])") }
let OW = 2868, OH = 1320
let bandY = 158.0, bandH = 707.0, k = Double(OW) / 1536.0
// Green area of the scene, in scene pixels (top-left origin).
var minX = 9999, minY = 9999, maxX = 0, maxY = 0
func isGreen(_ c: NSColor) -> Bool { c.greenComponent > 0.75 && c.redComponent < 0.45 && c.blueComponent < 0.45 }
for y in stride(from: 0, to: scene.pixelsHigh, by: 1) { for x in stride(from: 0, to: scene.pixelsWide, by: 2) {
    if let c = scene.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), isGreen(c) {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } } }
guard maxX > minX, maxY > minY else { fail("no green screen found in \(a[1])") }
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: OW, pixelsHigh: OH, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
NSGraphicsContext.current!.imageInterpolation = .high
let sceneImg = NSImage(size: NSSize(width: scene.pixelsWide, height: scene.pixelsHigh)); sceneImg.addRepresentation(scene)
// Scene band, scaled up (AppKit: bottom-left origin).
sceneImg.draw(in: NSRect(x: 0, y: 0, width: OW, height: OH),
              from: NSRect(x: 0, y: Double(scene.pixelsHigh) - bandY - bandH, width: 1536, height: bandH), operation: .copy, fraction: 1)
// Screen rect in output pixels.
let sx = Double(minX) * k, sw = Double(maxX - minX + 1) * k
let sy = (Double(minY) - bandY) * k, sh = Double(maxY - minY + 1) * k
let screenRect = NSRect(x: sx, y: Double(OH) - sy - sh, width: sw, height: sh)
let path = NSBezierPath(roundedRect: screenRect.insetBy(dx: -7, dy: -7), xRadius: sh * 0.08, yRadius: sh * 0.08)
NSGraphicsContext.saveGraphicsState(); path.addClip()
NSColor.black.setFill(); screenRect.insetBy(dx: -7, dy: -7).fill()
shot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
// Headline on the empty desk.
let left = 120.0, top = 300.0, width = sx - left - 90
let title = NSMutableParagraphStyle(); title.lineSpacing = 6
let tAttrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "PingFang SC Semibold", size: 112) ?? NSFont.boldSystemFont(ofSize: 112),
    .foregroundColor: NSColor(red: 0.97, green: 0.93, blue: 0.85, alpha: 1), .paragraphStyle: title,
    .shadow: { let s = NSShadow(); s.shadowBlurRadius = 18; s.shadowColor = NSColor.black.withAlphaComponent(0.55); return s }()]
let sAttrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "PingFang SC", size: 52) ?? NSFont.systemFont(ofSize: 52),
    .foregroundColor: NSColor(red: 0.95, green: 0.78, blue: 0.52, alpha: 1)]
let t = NSAttributedString(string: a[4].replacingOccurrences(of: "\\n", with: "\n"), attributes: tAttrs)
let tSize = t.boundingRect(with: NSSize(width: width, height: 2000), options: [.usesLineFragmentOrigin])
t.draw(with: NSRect(x: left, y: Double(OH) - top - tSize.height, width: width, height: tSize.height), options: [.usesLineFragmentOrigin])
let st = NSAttributedString(string: a[5], attributes: sAttrs)
st.draw(with: NSRect(x: left, y: Double(OH) - top - tSize.height - 110, width: width, height: 90), options: [.usesLineFragmentOrigin])
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
print("screen", minX, minY, maxX, maxY)
