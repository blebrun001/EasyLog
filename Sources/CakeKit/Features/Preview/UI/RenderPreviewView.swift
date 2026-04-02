import SwiftUI

public struct RenderPreviewView: View {
    @ObservedObject private var viewModel: ProjectViewModel

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            toolbar
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

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button("New") { viewModel.newProject() }
            Button("Open") { viewModel.openProjectViaPanel() }
            Button("Save") { viewModel.saveProjectViaPanelIfNeeded() }
            Divider().frame(height: 18)
            Button("Export SVG") { viewModel.exportViaPanel(format: .svg) }
            Button("Export JPG") { viewModel.exportViaPanel(format: .jpg) }
            Spacer()
            Text("Zoom")
            Slider(value: $viewModel.zoom, in: 0.5...2.5, step: 0.05)
                .frame(width: 140)
            Text("\(Int(viewModel.zoom * 100))%")
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal)
    }
}
