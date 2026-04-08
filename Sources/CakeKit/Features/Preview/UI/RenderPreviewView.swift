import SwiftUI
import os

/// Right-hand preview panel with live-rendered canvas.
public struct RenderPreviewView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var pinchBaseZoom: Double?
    private let zoomLogger = Logger(subsystem: "Cake", category: "Zoom")

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Canvas { context, _ in
                        context.withCGContext { cgContext in
                            SceneCGRenderer.draw(scene: viewModel.scene, in: cgContext)
                        }
                    }
                    .frame(
                        width: viewModel.scene.canvasSize.width,
                        height: viewModel.scene.canvasSize.height
                    )
                    .scaleEffect(viewModel.zoom, anchor: .topLeading)
                    .frame(
                        width: viewModel.scene.canvasSize.width * viewModel.zoom,
                        height: viewModel.scene.canvasSize.height * viewModel.zoom,
                        alignment: .topLeading
                    )
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(14)
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if pinchBaseZoom == nil {
                                pinchBaseZoom = viewModel.zoom
                            }
                            let base = pinchBaseZoom ?? viewModel.zoom
                            viewModel.setManualZoom(base * value)
                        }
                        .onEnded { _ in
                            pinchBaseZoom = nil
                        }
                )
                .onAppear {
                    let usable = usableViewport(from: proxy.size)
                    guard usable.width > 0, usable.height > 120 else {
                        zoomLogger.info(
                            "RenderPreview onAppear skipped (unstable layout) proxy=(\(proxy.size.width, format: .fixed(precision: 2)), \(proxy.size.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                        )
                        return
                    }
                    zoomLogger.info(
                        "RenderPreview onAppear proxy=(\(proxy.size.width, format: .fixed(precision: 2)), \(proxy.size.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                    )
                    viewModel.updateViewportSize(usable)
                }
                .onChange(of: proxy.size) { _, newSize in
                    let usable = usableViewport(from: newSize)
                    guard usable.width > 0, usable.height > 120 else {
                        zoomLogger.info(
                            "RenderPreview onChange skipped (unstable layout) proxy=(\(newSize.width, format: .fixed(precision: 2)), \(newSize.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                        )
                        return
                    }
                    zoomLogger.info(
                        "RenderPreview onChange proxy=(\(newSize.width, format: .fixed(precision: 2)), \(newSize.height, format: .fixed(precision: 2))) usable=(\(usable.width, format: .fixed(precision: 2)), \(usable.height, format: .fixed(precision: 2)))"
                    )
                    viewModel.updateViewportSize(usable)
                }
            }
            .accessibilityLabel("Log preview canvas")

            if !viewModel.validationIssues.isEmpty {
                ProPanelSection("Validation Warnings", subtitle: "Review before export") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.validationIssues) { issue in
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
        CGSize(width: max(0, size.width), height: max(0, size.height))
    }

}
