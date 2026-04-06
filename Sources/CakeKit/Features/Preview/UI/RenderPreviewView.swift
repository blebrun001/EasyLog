import SwiftUI

/// Right-hand preview panel with live-rendered canvas.
public struct RenderPreviewView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var pinchBaseZoom: Double?

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
                    viewModel.updateViewportSize(usableViewport(from: proxy.size))
                }
                .onChange(of: proxy.size) { _, newSize in
                    viewModel.updateViewportSize(usableViewport(from: newSize))
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
        CGSize(width: max(0, size.width - 32), height: max(0, size.height))
    }

}
