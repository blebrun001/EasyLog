import SwiftUI

/// Controls for renderer scaling, depth unit and visibility options.
public struct SettingsPanelView: View {
    @Binding private var settings: ProjectSettings

    public init(settings: Binding<ProjectSettings>) {
        self._settings = settings
    }

    public var body: some View {
        Form {
            Section("Scale") {
                LabeledContent("Vertical scale") {
                    Text("\(settings.verticalScale, specifier: "%.0f") px/m")
                        .foregroundStyle(.secondary)
                }
                Slider(value: verticalScaleBinding, in: 8...120)
                    .accessibilityLabel("Vertical scale")

                LabeledContent("Symbol scale") {
                    Text("\(settings.symbolScale, specifier: "%.2f")x")
                        .foregroundStyle(.secondary)
                }
                Slider(value: symbolScaleBinding, in: 0.35...3.0)
                    .accessibilityLabel("Symbol scale")

                Picker("Scale unit", selection: $settings.depthScaleUnit) {
                    ForEach(DepthScaleUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            }

            Section("Visibility") {
                Toggle("Use absolute altitude", isOn: useAbsoluteAltitudeBinding)
                    .accessibilityLabel("Use absolute altitude")
                Toggle("Show legend", isOn: $settings.showLegend)
                Toggle("Show depth scale", isOn: $settings.showScale)
                Toggle("Show grain size scale", isOn: $settings.showGrainSizeScale)
                Toggle("Show USGS codes in labels", isOn: $settings.showUSGSCodesInLithologyLabels)
                Toggle("Show log title", isOn: $settings.showLogTitle)
            }
        }
        .formStyle(.grouped)
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

    private var useAbsoluteAltitudeBinding: Binding<Bool> {
        Binding(
            get: { settings.useAbsoluteAltitude },
            set: { isEnabled in
                settings.useAbsoluteAltitude = isEnabled
                if isEnabled {
                    settings.zeroLevelAltitudeMeters = settings.zeroLevelAltitudeMeters ?? 0
                }
            }
        )
    }

    private func snapped(_ value: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
}
