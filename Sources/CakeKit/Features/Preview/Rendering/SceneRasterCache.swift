import CoreGraphics
import Foundation

public struct SceneRasterKey: Hashable, Sendable {
    public enum Layer: String, Sendable {
        case `static`
        case overlay
    }

    public enum Mode: String, Sendable {
        case preview
        case synthetic
    }

    public let sceneHash: Int
    public let renderScaleHundredths: Int
    public let layer: Layer
    public let mode: Mode

    public init(sceneHash: Int, renderScaleHundredths: Int, layer: Layer, mode: Mode) {
        self.sceneHash = sceneHash
        self.renderScaleHundredths = renderScaleHundredths
        self.layer = layer
        self.mode = mode
    }
}

/// Memory-bounded LRU cache for preview raster layers.
public actor SceneRasterCache {
    private struct Entry {
        let key: SceneRasterKey
        let image: CGImage
        let cost: Int
    }

    private let maxBytes: Int
    private var totalBytes = 0
    private var entries: [SceneRasterKey: Entry] = [:]
    private var lru: [SceneRasterKey] = []

    public init(maxBytes: Int = 160 * 1024 * 1024) {
        self.maxBytes = max(maxBytes, 4 * 1024 * 1024)
    }

    public func image(for key: SceneRasterKey) -> CGImage? {
        guard let entry = entries[key] else { return nil }
        touch(key)
        return entry.image
    }

    public func insert(_ image: CGImage, for key: SceneRasterKey) {
        let cost = max(image.bytesPerRow * image.height, 1)

        if let previous = entries[key] {
            totalBytes -= previous.cost
            removeFromLRU(key)
        }

        entries[key] = Entry(key: key, image: image, cost: cost)
        totalBytes += cost
        lru.append(key)

        evictIfNeeded()
    }

    public func removeAll() {
        entries.removeAll(keepingCapacity: false)
        lru.removeAll(keepingCapacity: false)
        totalBytes = 0
    }

    private func touch(_ key: SceneRasterKey) {
        removeFromLRU(key)
        lru.append(key)
    }

    private func removeFromLRU(_ key: SceneRasterKey) {
        if let idx = lru.firstIndex(of: key) {
            lru.remove(at: idx)
        }
    }

    private func evictIfNeeded() {
        while totalBytes > maxBytes, let victim = lru.first {
            lru.removeFirst()
            guard let entry = entries.removeValue(forKey: victim) else { continue }
            totalBytes -= entry.cost
        }
    }
}
