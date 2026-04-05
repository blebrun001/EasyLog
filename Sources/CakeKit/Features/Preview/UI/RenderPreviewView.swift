import SwiftUI

/// Right-hand preview panel with toolbar, zoom and live-rendered canvas.
public struct RenderPreviewView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var pinchBaseZoom: Double?

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            displayToolbar
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
                    .background(Color.white)
                }
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
                .onChange(of: proxy.size) { newSize in
                    viewModel.updateViewportSize(usableViewport(from: newSize))
                }
            }
            .padding(.horizontal)

            if !viewModel.validationIssues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.validationIssues) { issue in
                        Text("• \(issue.message)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private var displayToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    viewModel.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")

                Slider(value: zoomBinding, in: 0.5...2.5)
                    .frame(width: 170)
                    .accessibilityLabel("Zoom")

                Button {
                    viewModel.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in")

                Button("100%") {
                    viewModel.resetZoom()
                }
                .buttonStyle(.bordered)
                .help("Reset to native scale")
            }

            Divider()
                .frame(height: 22)

            Picker("Fit Mode", selection: fitModeBinding) {
                ForEach(displayedZoomModes) { mode in
                    Text(modePickerLabel(for: mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .help("Choose the fitting mode")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.horizontal)
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { viewModel.zoom },
            set: { viewModel.setManualZoom($0) }
        )
    }

    private var fitModeBinding: Binding<ProjectViewModel.ZoomMode> {
        Binding(
            get: { viewModel.zoomMode },
            set: { viewModel.setZoomMode($0) }
        )
    }

    private var displayedZoomModes: [ProjectViewModel.ZoomMode] { [.manual, .fitWindow] }

    private func usableViewport(from size: CGSize) -> CGSize {
        CGSize(width: max(0, size.width - 32), height: max(0, size.height))
    }

    private func modePickerLabel(for mode: ProjectViewModel.ZoomMode) -> String {
        switch mode {
        case .manual: "Manual"
        case .fitWindow: "Window"
        case .fitWidth: "Width"
        case .fitHeight: "Height"
        }
    }
}
