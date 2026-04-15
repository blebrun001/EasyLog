import AppKit
import Foundation

/// Small lock-based cache used by sync renderers to avoid global mutable static vars.
final class TextWidthCache: @unchecked Sendable {
    private var storage: [String: Double] = [:]
    private let lock = NSLock()

    func value(for key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func insert(_ value: Double, for key: String) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }
}

final class SymbolRenderCache: @unchecked Sendable {
    private let lock = NSLock()
    private var croppedImageCache: [String: CGImage] = [:]
    private var rasterPageCache: [String: CGImage] = [:]
    private var pdfDocumentCache: [String: CGPDFDocument] = [:]
    private var pdfPageCache: [String: CGPDFPage] = [:]
    private var missingLoggedCodes = Set<Int>()

    func cachedCroppedImage(for key: String) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return croppedImageCache[key]
    }

    func storeCroppedImage(_ image: CGImage, for key: String) {
        lock.lock()
        croppedImageCache[key] = image
        lock.unlock()
    }

    func cachedRasterPage(for key: String) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return rasterPageCache[key]
    }

    func storeRasterPage(_ image: CGImage, for key: String) {
        lock.lock()
        rasterPageCache[key] = image
        lock.unlock()
    }

    func cachedPDFPage(for key: String) -> CGPDFPage? {
        lock.lock()
        defer { lock.unlock() }
        return pdfPageCache[key]
    }

    func storePDFDocument(_ doc: CGPDFDocument, page: CGPDFPage, for key: String) {
        lock.lock()
        pdfDocumentCache[key] = doc
        pdfPageCache[key] = page
        lock.unlock()
    }

    func logMissingCodeOnce(_ code: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return missingLoggedCodes.insert(code).inserted
    }
}
