import SwiftUI

/// Side-by-side logs aligned on a shared altitude axis.
public struct SyntheticComparisonPopoverView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var pinchBaseZoom: Double?
    @State private var zoom: Double = 1.0

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let scene = viewModel.makeSyntheticComparisonScene()
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    zoom = max(0.5, zoom - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")

                Slider(value: $zoom, in: 0.5...2.5)
                    .frame(width: 180)

                Button {
                    zoom = min(2.5, zoom + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in")

                Button("100%") {
                    zoom = 1.0
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            ScrollView([.horizontal, .vertical]) {
                Canvas { context, _ in
                    context.withCGContext { cgContext in
                        SyntheticSceneCGRenderer.draw(scene: scene, in: cgContext)
                    }
                }
                .frame(width: scene.canvasSize.width, height: scene.canvasSize.height)
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(
                    width: scene.canvasSize.width * zoom,
                    height: scene.canvasSize.height * zoom,
                    alignment: .topLeading
                )
                .background(Color.white)
            }
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        if pinchBaseZoom == nil {
                            pinchBaseZoom = zoom
                        }
                        let base = pinchBaseZoom ?? zoom
                        zoom = min(max(base * value, 0.5), 2.5)
                    }
                    .onEnded { _ in
                        pinchBaseZoom = nil
                    }
            )
        }
        .padding(14)
        .frame(minWidth: 900, minHeight: 580)
    }
}
