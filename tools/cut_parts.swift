// Cuts a GPT parts sheet into separate PNGs: keeps the image's own alpha
// when it has some, else keys out a flat background (sampled from the
// corners) with a soft edge. No pixel of a part is painted; only the
// background goes transparent and each part is cropped to its bounds.
//
//   swift tools/cut_parts.swift <sheet.png> <out-dir> [min-area-px] [tolerance]
//
// Writes part_0.png, part_1.png… in reading order (rows, then left to right)
// and prints each one's bounds.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: cut_parts.swift sheet.png out-dir [min-area] [tolerance]"); exit(1) }
let minArea = args.count > 3 ? Int(args[3]) ?? 4000 : 4000
let tol = args.count > 4 ? Double(args[4]) ?? 18 : 18

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { print("can't read"); exit(1) }
let w = img.width, h = img.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

// Alpha already there?
var transparent = 0
for i in stride(from: 3, to: px.count, by: 4 * 7) where px[i] < 10 { transparent += 1 }
let hasAlpha = transparent > (w * h / 7) / 20
if !hasAlpha {
    // Background colour: median of the four corner patches.
    var rs = [Int](), gs = [Int](), bs = [Int]()
    for (cx, cy) in [(0, 0), (w - 12, 0), (0, h - 12), (w - 12, h - 12)] {
        for y in cy..<cy + 12 { for x in cx..<cx + 12 { let i = (y * w + x) * 4; rs.append(Int(px[i])); gs.append(Int(px[i + 1])); bs.append(Int(px[i + 2])) } }
    }
    let med = { (a: [Int]) in a.sorted()[a.count / 2] }
    let br = Double(med(rs)), bg = Double(med(gs)), bb = Double(med(bs))
    print(String(format: "keying background %.0f %.0f %.0f", br, bg, bb))
    for i in stride(from: 0, to: px.count, by: 4) {
        let d = max(abs(Double(px[i]) - br), abs(Double(px[i + 1]) - bg), abs(Double(px[i + 2]) - bb))
        // Fully background under tol, fully kept over 2×tol, a ramp between.
        let a = min(1, max(0, (d - tol) / tol))
        if a < 1 {
            // Un-mix the background from edge pixels, then premultiply.
            for c in 0..<3 {
                let bgc = [br, bg, bb][c]
                let v = a > 0 ? (Double(px[i + c]) - bgc * (1 - a)) / a : 0
                px[i + c] = UInt8(max(0, min(255, v * a)))
            }
            px[i + 3] = UInt8(a * 255)
        }
    }
} else { print("using the sheet's own alpha") }

// Connected parts (alpha > 40), 4-neighbour flood fill.
var label = [Int32](repeating: -1, count: w * h)
struct Box { var minX: Int, minY: Int, maxX: Int, maxY: Int, n: Int }
var boxes = [Box]()
var stack = [Int]()
for start in 0..<(w * h) where label[start] < 0 && px[start * 4 + 3] > 40 {
    let id = Int32(boxes.count)
    var b = Box(minX: w, minY: h, maxX: 0, maxY: 0, n: 0)
    stack.append(start); label[start] = id
    while let p = stack.popLast() {
        let x = p % w, y = p / w
        b.minX = min(b.minX, x); b.maxX = max(b.maxX, x); b.minY = min(b.minY, y); b.maxY = max(b.maxY, y); b.n += 1
        for q in [x > 0 ? p - 1 : -1, x < w - 1 ? p + 1 : -1, y > 0 ? p - w : -1, y < h - 1 ? p + w : -1]
        where q >= 0 && label[q] < 0 && px[q * 4 + 3] > 40 { label[q] = id; stack.append(q) }
    }
    boxes.append(b)
}
var parts = boxes.enumerated().filter { $0.element.n >= minArea }
// Reading order: rows by centre (a row = overlapping vertical spans), then x.
parts.sort { a, b in
    let ay = (a.element.minY + a.element.maxY) / 2, by = (b.element.minY + b.element.maxY) / 2
    let sameRow = ay >= b.element.minY && ay <= b.element.maxY || by >= a.element.minY && by <= a.element.maxY
    return sameRow ? a.element.minX < b.element.minX : ay < by
}
let out = URL(fileURLWithPath: args[2]); try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (k, (id, b)) in parts.enumerated() {
    let pw = b.maxX - b.minX + 1, ph = b.maxY - b.minY + 1
    var cut = [UInt8](repeating: 0, count: pw * ph * 4)
    for y in 0..<ph { for x in 0..<pw {
        let p = (b.minY + y) * w + b.minX + x
        // Only this part's pixels and their soft fringe (pixels of no part).
        guard label[p] == Int32(id) || label[p] < 0 else { continue }
        for c in 0..<4 { cut[(y * pw + x) * 4 + c] = px[p * 4 + c] }
    } }
    let c2 = CGContext(data: &cut, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: pw * 4, space: space,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let url = out.appendingPathComponent("part_\(k).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, c2.makeImage()!, nil); CGImageDestinationFinalize(dest)
    print("part_\(k).png  x \(b.minX) y \(b.minY)  \(pw)×\(ph)")
}
