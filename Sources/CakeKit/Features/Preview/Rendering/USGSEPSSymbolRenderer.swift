import AppKit
import Foundation

/// Draws USGS EPS-derived symbols by tiling/cropping cached PDF pages.
public enum USGSEPSSymbolRenderer {
    private static let resolver = USGSSymbolAssetResolver.shared
    nonisolated(unsafe) private static var croppedImageCache: [String: CGImage] = [:]
    nonisolated(unsafe) private static var rasterPageCache: [String: CGImage] = [:]
    nonisolated(unsafe) private static var pdfDocumentCache: [String: CGPDFDocument] = [:]
    nonisolated(unsafe) private static var pdfPageCache: [String: CGPDFPage] = [:]
    nonisolated(unsafe) private static var missingLoggedCodes = Set<Int>()
    private static let lock = NSLock()
    private static let swatchBorderInsetPoints: CGFloat = 1.2

    @discardableResult
    public static func drawSymbol(code: Int, in rect: CGRect, context: CGContext, symbolScale: Double = 1.0) -> Bool {
        guard let asset = resolver.asset(for: code) else {
            return false
        }
        return draw(asset: asset, in: rect, context: context, symbolScale: symbolScale)
    }

    /// Warm symbol tiles asynchronously so live preview can use cached raster tiles.
    public static func prewarm(codes: [Int]) {
        let unique = Array(Set(codes)).sorted()
        guard !unique.isEmpty else { return }
        Task.detached(priority: .utility) {
            for code in unique {
                warmSymbol(code: code)
            }
        }
    }

    private static func draw(asset: USGSSymbolAsset, in rect: CGRect, context: CGContext, symbolScale: Double) -> Bool {
        let tiledRect = insetSymbolRect(asset.symbolRect, pageSizePoints: asset.pageSizePoints)
        guard let tileImage = cachedTileImage(asset: asset, tiledRect: tiledRect) else {
            if let code = asset.code {
                prewarm(codes: [code])
            }
            return false
        }

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
                context.draw(tileImage, in: drawRect)
                x += tileW
            }
            y += tileH
        }

        context.restoreGState()
        return true
    }

    public static func pngTileData(for code: Int, maxDimension: Int = 1024) -> (data: Data, width: Int, height: Int)? {
        guard let asset = resolver.asset(for: code) else {
            return nil
        }
        return pngTileData(asset: asset, maxDimension: maxDimension)
    }

    private static func pngTileData(asset: USGSSymbolAsset, maxDimension: Int) -> (data: Data, width: Int, height: Int)? {
        guard let tileImage = tileImage(asset: asset) else {
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

    private static func warmSymbol(code: Int) {
        guard let asset = resolver.asset(for: code) else { return }
        _ = tileImage(asset: asset)
    }

    private static func cachedTileImage(asset: USGSSymbolAsset, tiledRect: USGSSymbolRect) -> CGImage? {
        let cacheKey = tileCacheKey(asset: asset, tiledRect: tiledRect)
        lock.lock()
        let cached = croppedImageCache[cacheKey]
        lock.unlock()
        return cached
    }

    private static func tileImage(asset: USGSSymbolAsset) -> CGImage? {
        let tiledRect = insetSymbolRect(asset.symbolRect, pageSizePoints: asset.pageSizePoints)

        if let page = pdfPage(for: asset) {
            return rasterizedPDFTile(
                code: asset.code ?? -1,
                asset: asset,
                page: page,
                tiledRect: tiledRect
            )
        }
        logMissingAssetOnce(code: asset.code ?? -1, reason: "Cannot open PDF \(asset.pdfRelativePath)")
        return nil
    }

    private static func rasterizedPDFTile(
        code: Int,
        asset: USGSSymbolAsset,
        page: CGPDFPage,
        tiledRect: USGSSymbolRect
    ) -> CGImage? {
        let cacheKey = tileCacheKey(asset: asset, tiledRect: tiledRect)
        lock.lock()
        if let cached = croppedImageCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let rasterScale: CGFloat = 6.0
        guard let pageRaster = rasterizedPageImage(asset: asset, page: page, rasterScale: rasterScale) else {
            logMissingAssetOnce(code: code, reason: "Cannot rasterize page for \(asset.pdfRelativePath)")
            return nil
        }

        let pageHeight = CGFloat(pageRaster.height)
        let cropRect = CGRect(
            x: CGFloat(tiledRect.x) * rasterScale,
            y: pageHeight - CGFloat(tiledRect.y + tiledRect.height) * rasterScale,
            width: CGFloat(tiledRect.width) * rasterScale,
            height: CGFloat(tiledRect.height) * rasterScale
        ).integral
        let pageBounds = CGRect(x: 0, y: 0, width: pageRaster.width, height: pageRaster.height)
        let clippedRect = cropRect.intersection(pageBounds)
        guard clippedRect.width > 1, clippedRect.height > 1,
              let cropped = pageRaster.cropping(to: clippedRect)
        else {
            logMissingAssetOnce(code: code, reason: "Cannot crop raster page tile for \(asset.pdfRelativePath)")
            return nil
        }

        lock.lock()
        croppedImageCache[cacheKey] = cropped
        lock.unlock()
        return cropped
    }

    private static func rasterizedPageImage(
        asset: USGSSymbolAsset,
        page: CGPDFPage,
        rasterScale: CGFloat
    ) -> CGImage? {
        let cacheKey = "\(asset.pdfURL.path)#\(rasterScale)"
        lock.lock()
        if let cached = rasterPageCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let pageW = CGFloat(max(asset.pageSizePoints.width, 1))
        let pageH = CGFloat(max(asset.pageSizePoints.height, 1))
        let width = max(Int(pageW * rasterScale), 16)
        let height = max(Int(pageH * rasterScale), 16)
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
            return nil
        }

        bitmap.setFillColor(NSColor.clear.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        bitmap.saveGState()
        bitmap.scaleBy(x: rasterScale, y: rasterScale)
        let media = page.getBoxRect(.mediaBox)
        if media.width > 0, media.height > 0 {
            bitmap.scaleBy(x: pageW / media.width, y: pageH / media.height)
        }
        bitmap.drawPDFPage(page)
        bitmap.restoreGState()

        guard let rasterPage = bitmap.makeImage() else { return nil }
        lock.lock()
        rasterPageCache[cacheKey] = rasterPage
        lock.unlock()
        return rasterPage
    }

    private static func tileCacheKey(asset: USGSSymbolAsset, tiledRect: USGSSymbolRect) -> String {
        "\(asset.symbolId)#\(asset.pdfURL.path)#\(asset.pageSizePoints.width)x\(asset.pageSizePoints.height)#\(tiledRect.x)-\(tiledRect.y)-\(tiledRect.width)-\(tiledRect.height)"
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

    private static func logMissingAssetOnce(code: Int, reason: String) {
        lock.lock()
        defer { lock.unlock() }
        guard missingLoggedCodes.insert(code).inserted else { return }
        fputs("[USGSEPSSymbolRenderer] fallback for code \(code): \(reason)\n", stderr)
    }
}
