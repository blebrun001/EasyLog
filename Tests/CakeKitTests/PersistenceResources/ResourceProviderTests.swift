import Foundation
import Testing
@testable import CakeKit

@Test
func directoryResourceProviderResolvesURLAndData() throws {
    let root = try makeTempDirectory(prefix: "resource-provider")
    let fileURL = root.appending(path: "nested/file.txt")
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("hello".utf8).write(to: fileURL)

    let provider = DirectoryResourceProvider(rootURL: root)
    let url = try provider.url(for: "nested/file.txt")
    let data = try provider.data(for: "nested/file.txt")

    #expect(url.path == fileURL.path)
    #expect(String(decoding: data, as: UTF8.self) == "hello")
}

@Test
func directoryResourceProviderRejectsTraversalAndMissingFiles() {
    let provider = DirectoryResourceProvider(rootURL: URL(fileURLWithPath: NSTemporaryDirectory()))

    #expect(throws: ResourceProviderError.self) {
        _ = try provider.url(for: "../escape.txt")
    }
    #expect(throws: ResourceProviderError.self) {
        _ = try provider.url(for: "not-found/file.txt")
    }
}

@Test
func bundleResourceProviderResolvesBundledRuntimeCatalog() throws {
    let provider = try BundleResourceProvider(bundle: CakeKitBundle.resources)
    let url = try provider.url(for: "USGSRuntime/ResourceCatalog.release.json")
    let data = try provider.data(for: "USGSRuntime/ResourceCatalog.release.json")

    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(!data.isEmpty)
}
