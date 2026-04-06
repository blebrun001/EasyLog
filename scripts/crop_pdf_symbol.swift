import CoreGraphics
import Foundation

struct Arguments {
    let inputPDF: URL
    let outputPDF: URL
    let rect: CGRect
    let sourcePageSize: CGSize
}

private func usageAndExit() -> Never {
    fputs("usage: crop_pdf_symbol <input.pdf> <output.pdf> <x> <y> <w> <h> <pageW> <pageH>\n", stderr)
    exit(2)
}

private func parseArgs() -> Arguments {
    let args = CommandLine.arguments
    guard args.count == 9 else { usageAndExit() }

    guard let x = Double(args[3]),
          let y = Double(args[4]),
          let w = Double(args[5]),
          let h = Double(args[6]),
          let pageW = Double(args[7]),
          let pageH = Double(args[8]) else {
        usageAndExit()
    }

    return Arguments(
        inputPDF: URL(fileURLWithPath: args[1]),
        outputPDF: URL(fileURLWithPath: args[2]),
        rect: CGRect(x: x, y: y, width: w, height: h),
        sourcePageSize: CGSize(width: pageW, height: pageH)
    )
}

private func cropPDF(_ args: Arguments) throws {
    guard let doc = CGPDFDocument(args.inputPDF as CFURL),
          let page = doc.page(at: 1) else {
        throw NSError(domain: "CropPDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open source PDF"])
    }

    let tileRect = args.rect
    guard tileRect.width > 0, tileRect.height > 0 else {
        throw NSError(domain: "CropPDF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid crop rect"])
    }

    let fm = FileManager.default
    try fm.createDirectory(at: args.outputPDF.deletingLastPathComponent(), withIntermediateDirectories: true)

    var mediaBox = CGRect(x: 0, y: 0, width: tileRect.width, height: tileRect.height)
    guard let ctx = CGContext(args.outputPDF as CFURL, mediaBox: &mediaBox, nil) else {
        throw NSError(domain: "CropPDF", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create destination PDF"])
    }

    ctx.beginPDFPage(nil)
    ctx.saveGState()

    let sourceW = max(args.sourcePageSize.width, 1)
    let sourceH = max(args.sourcePageSize.height, 1)
    let sx = mediaBox.width / tileRect.width
    let sy = mediaBox.height / tileRect.height

    // Normalize source page size first.
    let pageMedia = page.getBoxRect(.mediaBox)
    if pageMedia.width > 0, pageMedia.height > 0 {
        ctx.scaleBy(x: sourceW / pageMedia.width, y: sourceH / pageMedia.height)
    }

    // Shift so desired symbol rect maps to output origin, then scale to fill.
    ctx.translateBy(x: -tileRect.minX, y: -tileRect.minY)
    ctx.scaleBy(x: sx, y: sy)
    ctx.drawPDFPage(page)

    ctx.restoreGState()
    ctx.endPDFPage()
    ctx.closePDF()
}

do {
    let parsed = parseArgs()
    try cropPDF(parsed)
} catch {
    fputs("crop_pdf_symbol failed: \(error)\n", stderr)
    exit(1)
}
