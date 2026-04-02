import AppKit
import Foundation

public enum USGSEPSSymbolRenderer {
    private static let resolver = USGSSymbolAssetResolver.shared
    nonisolated(unsafe) private static var croppedImageCache: [String: CGImage] = [:]
    nonisolated(unsafe) private static var missingLoggedCodes = Set<Int>()
    private static let lock = NSLock()

    @discardableResult
    public static func drawSymbol(code: Int, in rect: CGRect, context: CGContext) -> Bool {
        guard let tileImage = tileImage(for: code) else {
            return false
        }

        context.saveGState()
        context.clip(to: rect)
        context.interpolationQuality = .high

        let tileW = CGFloat(tileImage.width)
        let tileH = CGFloat(tileImage.height)
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

    public static func pngTileData(for code: Int, maxDimension: Int = 64) -> (data: Data, width: Int, height: Int)? {
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

    private static func tileImage(for code: Int) -> CGImage? {
        guard let asset = resolver.asset(for: code) else {
            logMissingAssetOnce(code: code, reason: "No symbol asset entry")
            return nil
        }

        let cacheKey = "\(asset.imageURL.path)#\(asset.symbolRect.x)-\(asset.symbolRect.y)-\(asset.symbolRect.width)-\(asset.symbolRect.height)"
        lock.lock()
        if let cached = croppedImageCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let image = NSImage(contentsOf: asset.imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            logMissingAssetOnce(code: code, reason: "Cannot decode rendered symbol image \(asset.pngRelativePath) (from EPS \(asset.epsRelativePath))")
            return nil
        }

        let cropRect = normalizedCropRect(symbolRect: asset.symbolRect, pageSizePoints: asset.pageSizePoints, image: cgImage)
        guard let cropped = cgImage.cropping(to: cropRect) else {
            logMissingAssetOnce(code: code, reason: "Invalid crop rect for \(asset.pngRelativePath)")
            return nil
        }

        lock.lock()
        croppedImageCache[cacheKey] = cropped
        lock.unlock()
        return cropped
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
