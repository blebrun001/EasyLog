import SwiftUI

public struct SettingsPanelView: View {
    @Binding private var settings: ProjectSettings

    public init(settings: Binding<ProjectSettings>) {
        self._settings = settings
    }

    public var body: some View {
        GroupBox("Rendering Settings") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Vertical Scale")
                    Slider(value: $settings.verticalScale, in: 8...120)
                        .onChange(of: settings.verticalScale) { value in
                            settings.verticalScale = value.rounded()
                        }
                    Text("\(settings.verticalScale, specifier: "%.0f") px/m")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Symbol Scale")
                    Slider(value: $settings.symbolScale, in: 0.35...3.0)
                        .onChange(of: settings.symbolScale) { value in
                            settings.symbolScale = (value * 20).rounded() / 20
                        }
                    Text("\(settings.symbolScale, specifier: "%.2f")x")
                        .foregroundStyle(.secondary)
                }

                Picker("Page Size", selection: $settings.pageSize) {
                    ForEach(PageSizePreset.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
