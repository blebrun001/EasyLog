import AppKit
import Foundation

public enum USGSEPSSymbolRenderer {
    private static let resolver = USGSSymbolAssetResolver.shared
    nonisolated(unsafe) private static var croppedImageCache: [String: CGImage] = [:]
    nonisolated(unsafe) private static var pdfDocumentCache: [String: CGPDFDocument] = [:]
    nonisolated(unsafe) private static var pdfPageCache: [String: CGPDFPage] = [:]
    nonisolated(unsafe) private static var missingLoggedCodes = Set<Int>()
    private static let lock = NSLock()
    private static let swatchBorderInsetPoints: CGFloat = 1.2

    @discardableResult
    public static func drawSymbol(code: Int, in rect: CGRect, context: CGContext, symbolScale: Double = 1.0) -> Bool {
        guard let asset = resolver.asset(for: code),
              let page = pdfPage(for: asset)
        else {
            return false
        }
        let tiledRect = insetSymbolRect(asset.symbolRect, pageSizePoints: asset.pageSizePoints)

        context.saveGState()
        context.clip(to: rect)
        context.interpolationQuality = .high

        let scale = max(0.05, CGFloat(symbolScale))
        let tileW = CGFloat(tiledRect.width) * scale
        let tileH = CGFloat(tiledRect.height) * scale
        guard tileW > 0, tileH > 0 else {
            context.restoreGState()
            return false
        }

        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let drawRect = CGRect(x: x, y: y, width: tileW, height: tileH)
                drawCroppedPDF(page: page, symbolRect: tiledRect, pageSizePoints: asset.pageSizePoints, in: drawRect, context: context)
                x += tileW
            }
            y += tileH
        }

        context.restoreGState()
        return true
    }

    public static func pngTileData(for code: Int, maxDimension: Int = 1024) -> (data: Data, width: Int, height: Int)? {
        guard let tileImage = tileImage(for: code) else {
            return nil
        }

        let sourceW = max(tileImage.width, 1)
        let sourceH = max(tileImage.height, 1)
        let maxSide = max(sourceW, sourceH)
        let scale = min(1.0, Double(maxDimension) / Double(maxSide))
        let targetW = max(Int(Double(sourceW) * scale), 8)
        let targetH = max(Int(Double(sourceH) * scale), 8)

        guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: targetW,
                pixelsHigh: targetH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [],
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let cgContext = NSGraphicsContext(bitmapImageRep: rep)?.cgContext
        else {
            return nil
        }

        cgContext.setFillColor(NSColor.clear.cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: targetW, height: targetH))
        cgContext.draw(tileImage, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))

        guard let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }

        return (data: data, width: targetW, height: targetH)
    }

    public static func tileSizePoints(for code: Int, symbolScale: Double = 1.0) -> CGSizeDTO? {
        guard let asset = resolver.asset(for: code) else { return nil }
        let tiledRect = insetSymbolRect(asset.symbolRect, pageSizePoints: asset.pageSizePoints)
        let scale = max(0.05, symbolScale)
        return CGSizeDTO(
            width: tiledRect.width * scale,
            height: tiledRect.height * scale
        )
    }

    private static func tileImage(for code: Int) -> CGImage? {
        guard let asset = resolver.asset(for: code) else {
            logMissingAssetOnce(code: code, reason: "No symbol asset entry")
            return nil
        }
        guard let page = pdfPage(for: asset) else {
            logMissingAssetOnce(code: code, reason: "Cannot open PDF \(asset.pdfRelativePath)")
            return nil
        }
        let tiledRect = insetSymbolRect(asset.symbolRect, pageSizePoints: asset.pageSizePoints)

        let cacheKey = "\(asset.pdfURL.path)#\(asset.symbolRect.x)-\(asset.symbolRect.y)-\(asset.symbolRect.width)-\(asset.symbolRect.height)"
        lock.lock()
        if let cached = croppedImageCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let rasterScale: CGFloat = 6.0
        let width = max(Int(CGFloat(tiledRect.width) * rasterScale), 16)
        let height = max(Int(CGFloat(tiledRect.height) * rasterScale), 16)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            logMissingAssetOnce(code: code, reason: "Cannot allocate bitmap for \(asset.pdfRelativePath)")
            return nil
        }

        bitmap.setFillColor(NSColor.clear.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        drawCroppedPDF(
            page: page,
            symbolRect: tiledRect,
            pageSizePoints: asset.pageSizePoints,
            in: CGRect(x: 0, y: 0, width: width, height: height),
            context: bitmap
        )

        guard let cropped = bitmap.makeImage() else {
            logMissingAssetOnce(code: code, reason: "Cannot rasterize PDF tile for \(asset.pdfRelativePath)")
            return nil
        }

        lock.lock()
        croppedImageCache[cacheKey] = cropped
        lock.unlock()
        return cropped
    }

    private static func pdfPage(for asset: USGSSymbolAsset) -> CGPDFPage? {
        let cacheKey = asset.pdfURL.path
        lock.lock()
        if let page = pdfPageCache[cacheKey] {
            lock.unlock()
            return page
        }
        lock.unlock()

        guard let doc = CGPDFDocument(asset.pdfURL as CFURL),
              let page = doc.page(at: 1) else {
            return nil
        }

        lock.lock()
        pdfDocumentCache[cacheKey] = doc
        pdfPageCache[cacheKey] = page
        lock.unlock()
        return page
    }

    private static func drawCroppedPDF(page: CGPDFPage, symbolRect: USGSSymbolRect, pageSizePoints: CGSizeDTO, in drawRect: CGRect, context: CGContext) {
        let pageW = CGFloat(max(pageSizePoints.width, 1))
        let pageH = CGFloat(max(pageSizePoints.height, 1))
        let sx = drawRect.width / CGFloat(max(symbolRect.width, 0.0001))
        let sy = drawRect.height / CGFloat(max(symbolRect.height, 0.0001))

        context.saveGState()
        context.clip(to: drawRect)

        // Draw in a local, y-up coordinate space to match PDF user space.
        context.translateBy(x: 0, y: drawRect.maxY + drawRect.minY)
        context.scaleBy(x: 1, y: -1)

        context.translateBy(
            x: drawRect.minX - CGFloat(symbolRect.x) * sx,
            y: drawRect.minY - CGFloat(symbolRect.y) * sy
        )
        context.scaleBy(x: sx, y: sy)

        // Normalize page into expected point-space (usually 612x792).
        let media = page.getBoxRect(.mediaBox)
        if media.width > 0, media.height > 0 {
            context.scaleBy(x: pageW / media.width, y: pageH / media.height)
        }

        context.drawPDFPage(page)
        context.restoreGState()
    }

    private static func insetSymbolRect(_ rect: USGSSymbolRect, pageSizePoints: CGSizeDTO) -> USGSSymbolRect {
        let maxInsetX = max(CGFloat(rect.width) * 0.2, 0)
        let maxInsetY = max(CGFloat(rect.height) * 0.2, 0)
        let inset = min(swatchBorderInsetPoints, min(maxInsetX, maxInsetY))
        let width = max(CGFloat(rect.width) - inset * 2, 0.1)
        let height = max(CGFloat(rect.height) - inset * 2, 0.1)
        _ = pageSizePoints
        return USGSSymbolRect(
            x: rect.x + Double(inset),
            y: rect.y + Double(inset),
            width: Double(width),
            height: Double(height)
        )
    }

    private static func normalizedCropRect(symbolRect: USGSSymbolRect, pageSizePoints: CGSizeDTO, image: CGImage) -> CGRect {
        let imageW = CGFloat(image.width)
        let imageH = CGFloat(image.height)
        let pageW = CGFloat(max(pageSizePoints.width, 1))
        let pageH = CGFloat(max(pageSizePoints.height, 1))
        let scaleX = imageW / pageW
        let scaleY = imageH / pageH

        let x = CGFloat(symbolRect.x) * scaleX
        let yBottomBased = CGFloat(symbolRect.y) * scaleY
        let width = CGFloat(symbolRect.width) * scaleX
        let height = CGFloat(symbolRect.height) * scaleY

        // EPS geometry in the index is bottom-based, CGImage crop rect is top-based.
        let yTopBased = imageH - yBottomBased - height
        let raw = CGRect(x: x, y: yTopBased, width: width, height: height)
        let bounds = CGRect(x: 0, y: 0, width: imageW, height: imageH)
        return raw.intersection(bounds).integral
    }

    private static func logMissingAssetOnce(code: Int, reason: String) {
        lock.lock()
        defer { lock.unlock() }
        guard missingLoggedCodes.insert(code).inserted else { return }
        fputs("[USGSEPSSymbolRenderer] fallback for code \(code): \(reason)\n", stderr)
    }
}
