import SwiftUI

/// Controls for renderer scaling, depth unit and visibility options.
public struct SettingsPanelView: View {
    @Binding private var settings: ProjectSettings

    public init(settings: Binding<ProjectSettings>) {
        self._settings = settings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Rendering Settings")

            HStack {
                Text("Vertical Scale")
                Slider(value: verticalScaleBinding, in: 8...120)
                    .accessibilityLabel("Vertical Scale")
                Text("\(settings.verticalScale, specifier: "%.0f") px/m")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Symbol Scale")
                Slider(value: symbolScaleBinding, in: 0.35...3.0)
                    .accessibilityLabel("Symbol Scale")
                Text("\(settings.symbolScale, specifier: "%.2f")x")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Scale Unit")
                Picker("Scale Unit", selection: $settings.depthScaleUnit) {
                    ForEach(DepthScaleUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }

            Toggle("Show Legend", isOn: $settings.showLegend)
                .accessibilityLabel("Show Legend")
            Toggle("Show Depth Scale", isOn: $settings.showScale)
                .accessibilityLabel("Show Depth Scale")
            Toggle("Show Grain Size Scale", isOn: $settings.showGrainSizeScale)
                .accessibilityLabel("Show Grain Size Scale")
            Toggle("Show USGS Codes In Lithology Labels", isOn: $settings.showUSGSCodesInLithologyLabels)
                .accessibilityLabel("Show USGS Codes In Lithology Labels")
            Toggle("Show Log Title", isOn: $settings.showLogTitle)
                .accessibilityLabel("Show Log Title")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private var verticalScaleBinding: Binding<Double> {
        Binding(
            get: { settings.verticalScale },
            set: { settings.verticalScale = snapped($0, step: 1, range: 8...120) }
        )
    }

    private var symbolScaleBinding: Binding<Double> {
        Binding(
            get: { settings.symbolScale },
            set: { settings.symbolScale = snapped($0, step: 0.05, range: 0.35...3.0) }
        )
    }

    private func snapped(_ value: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
}
