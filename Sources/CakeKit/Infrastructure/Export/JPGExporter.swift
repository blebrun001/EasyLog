import AppKit
import Foundation

public struct JPGExporter: Exporter {
    public init() {}

    public func export(scene: RenderScene, to url: URL, options: ExportOptions) throws {
        let scale = max(options.dpi / 72.0, 1.0)
        let width = Int(scene.canvasSize.width * scale)
        let height = Int(scene.canvasSize.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.coderInvalidValue)
        }

        context.scaleBy(x: scale, y: scale)
        SceneCGRenderer.draw(scene: scene, in: context)

        guard let cgImage = context.makeImage() else {
            throw CocoaError(.coderInvalidValue)
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }
}
