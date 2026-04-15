import AppKit
import SwiftUI

/// Side-by-side logs aligned on a shared altitude axis.
public struct SyntheticComparisonPopoverView: View {
    private let viewModel: ProjectViewModel
    @ObservedObject private var previewState: PreviewState
    @State private var pinchBaseZoom: Double?

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
        self._previewState = ObservedObject(wrappedValue: viewModel.previewState)
    }

    public var body: some View {
        Group {
            if !previewState.isSyntheticAvailable {
                ProEmptyState(
                    title: "Synthetic comparison is unavailable",
                    message: "Create at least two logs and set a zero-level altitude for each log.",
                    systemImage: "rectangle.split.2x1"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(20)
                .accessibilityLabel("Synthetic comparison unavailable")
            } else {
                let scene = previewState.syntheticScene
                VStack(spacing: 0) {
                    ScrollView([.horizontal, .vertical]) {
                        syntheticCanvas(scene: scene)
                        .frame(width: scene.canvasSize.width, height: scene.canvasSize.height)
                        .scaleEffect(previewState.zoom, anchor: .topLeading)
                        .frame(
                            width: scene.canvasSize.width * previewState.zoom,
                            height: scene.canvasSize.height * previewState.zoom,
                            alignment: .topLeading
                        )
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(14)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if pinchBaseZoom == nil {
                                    pinchBaseZoom = previewState.zoom
                                }
                                let base = pinchBaseZoom ?? previewState.zoom
                                viewModel.setManualZoom(base * value, isInteracting: true)
                            }
                            .onEnded { _ in
                                pinchBaseZoom = nil
                                viewModel.finalizeManualZoomInteraction()
                            }
                    )
                }
                .accessibilityLabel("Synthetic comparison canvas")
            }
        }
    }

    @ViewBuilder
    private func syntheticCanvas(scene: SyntheticComparisonScene) -> some View {
        let rasterScale = previewState.syntheticRasterScale
        if let staticRaster = previewState.syntheticStaticRaster,
           let overlayRaster = previewState.syntheticOverlayRaster {
            ZStack(alignment: .topLeading) {
                Image(decorative: staticRaster, scale: rasterScale, orientation: .up)
                    .interpolation(.high)
                    .antialiased(true)
                Image(decorative: overlayRaster, scale: rasterScale, orientation: .up)
                    .interpolation(.high)
                    .antialiased(true)
            }
        } else {
            Canvas { context, _ in
                context.withCGContext { cgContext in
                    SyntheticSceneCGRenderer.draw(scene: scene, in: cgContext)
                }
            }
        }
    }
}
