import AppKit
import SwiftUI
import os

/// Right-hand preview panel with live-rendered canvas.
public struct RenderPreviewView: View {
    private let viewModel: ProjectViewModel
    @ObservedObject private var previewState: PreviewState
    @State private var pinchBaseZoom: Double?
    private let zoomLogger = Logger(subsystem: "Cake", category: "Zoom")

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
        self._previewState = ObservedObject(wrappedValue: viewModel.previewState)
    }

    public var body: some View {
        let scene = previewState.scene
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    previewCanvas(scene: scene)
                    .frame(
                        width: scene.canvasSize.width,
                        height: scene.canvasSize.height
                    )
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
                .onAppear {
                    let usable = usableViewport(from: proxy.size)
                    guard usable.width > 0, usable.height > 120 else {
                        #if DEBUG
                        zoomLogger.debug(
                            "RenderPreview onAppear skipped (unstable layout) proxy=(\(proxy.size.width, format: .fixed(precision: 2)), \(proxy.size.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                        )
                        #endif
                        return
                    }
                    #if DEBUG
                    zoomLogger.debug(
                        "RenderPreview onAppear proxy=(\(proxy.size.width, format: .fixed(precision: 2)), \(proxy.size.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                    )
                    #endif
                    viewModel.updateViewportSize(usable)
                }
                .onChange(of: proxy.size) { _, newSize in
                    let usable = usableViewport(from: newSize)
                    guard usable.width > 0, usable.height > 120 else {
                        #if DEBUG
                        zoomLogger.debug(
                            "RenderPreview onChange skipped (unstable layout) proxy=(\(newSize.width, format: .fixed(precision: 2)), \(newSize.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                        )
                        #endif
                        return
                    }
                    #if DEBUG
                    zoomLogger.debug(
                        "RenderPreview onChange proxy=(\(newSize.width, format: .fixed(precision: 2)), \(newSize.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                    )
                    #endif
                    viewModel.updateViewportSize(usable)
                }
            }
            .accessibilityLabel("Log preview canvas")

            if !previewState.validationIssues.isEmpty {
                ProPanelSection("Validation Warnings", subtitle: "Review before export") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(previewState.validationIssues) { issue in
                            Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .accessibilityLabel("Validation warnings")
            }
        }
    }

    private func usableViewport(from size: CGSize) -> CGSize {
        let contentPadding: CGFloat = 14
        let horizontalInsets = contentPadding * 2
        let verticalInsets = contentPadding * 2
        return CGSize(
            width: max(0, size.width - horizontalInsets),
            height: max(0, size.height - verticalInsets)
        )
    }

    @ViewBuilder
    private func previewCanvas(scene: RenderScene) -> some View {
        let rasterScale = previewState.previewRasterScale
        if let staticRaster = previewState.previewStaticRaster,
           let overlayRaster = previewState.previewOverlayRaster {
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
                    SceneCGRenderer.draw(scene: scene, in: cgContext)
                }
            }
        }
    }

}
