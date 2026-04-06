import SwiftUI

/// Side-by-side logs aligned on a shared altitude axis.
public struct SyntheticComparisonPopoverView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var pinchBaseZoom: Double?

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if !viewModel.canOpenSyntheticView {
                ProEmptyState(
                    title: "Synthetic comparison is unavailable",
                    message: "Create at least two logs and set a zero-level altitude for each log.",
                    systemImage: "rectangle.split.2x1"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(20)
                .accessibilityLabel("Synthetic comparison unavailable")
            } else {
                let scene = viewModel.makeSyntheticComparisonScene()
                VStack(spacing: 0) {
                    ScrollView([.horizontal, .vertical]) {
                        Canvas { context, _ in
                            context.withCGContext { cgContext in
                                SyntheticSceneCGRenderer.draw(scene: scene, in: cgContext)
                            }
                        }
                        .frame(width: scene.canvasSize.width, height: scene.canvasSize.height)
                        .scaleEffect(viewModel.zoom, anchor: .topLeading)
                        .frame(
                            width: scene.canvasSize.width * viewModel.zoom,
                            height: scene.canvasSize.height * viewModel.zoom,
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
                }
                .accessibilityLabel("Synthetic comparison canvas")
            }
        }
    }
}
