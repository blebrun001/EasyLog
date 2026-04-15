import Foundation
import Testing
@testable import CakeKit

@Test
func sceneRasterCacheStoresRetrievesAndClearsEntries() async {
    let cache = SceneRasterCache(maxBytes: 8 * 1024 * 1024)
    let key = SceneRasterKey(sceneHash: 1, renderScaleHundredths: 100, layer: .static, mode: .preview)
    let image = makeImage(width: 32, height: 32)

    await cache.insert(image, for: key)
    let loaded = await cache.image(for: key)
    #expect(loaded != nil)

    await cache.removeAll()
    let cleared = await cache.image(for: key)
    #expect(cleared == nil)
}

@Test
func sceneRasterCacheEvictsOldEntriesWhenOverBudget() async {
    let cache = SceneRasterCache(maxBytes: 4 * 1024 * 1024)
    let first = SceneRasterKey(sceneHash: 10, renderScaleHundredths: 100, layer: .static, mode: .preview)
    let second = SceneRasterKey(sceneHash: 11, renderScaleHundredths: 100, layer: .overlay, mode: .preview)

    await cache.insert(makeImage(width: 800, height: 800), for: first)
    await cache.insert(makeImage(width: 800, height: 800), for: second)

    let firstLoaded = await cache.image(for: first)
    let secondLoaded = await cache.image(for: second)

    #expect(firstLoaded == nil)
    #expect(secondLoaded != nil)
}
