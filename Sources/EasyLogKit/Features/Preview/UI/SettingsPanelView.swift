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
                    .help("Adjust vertical scale in pixels per meter")

                LabeledContent("Symbol scale") {
                    Text("\(settings.symbolScale, specifier: "%.2f")x")
                        .foregroundStyle(.secondary)
                }
                Slider(value: symbolScaleBinding, in: 0.35...3.0)
                    .accessibilityLabel("Symbol scale")
                    .help("Adjust symbol size scale")

                LabeledContent("Point icon size") {
                    Text("\(settings.pointFeatureIconSize, specifier: "%.1f") px")
                        .foregroundStyle(.secondary)
                }
                Slider(value: pointFeatureIconSizeBinding, in: ProjectSettings.pointFeatureIconSizeRange)
                    .accessibilityLabel("Point feature icon size")
                    .help("Adjust point feature icon size")

                Picker("Scale unit", selection: $settings.depthScaleUnit) {
                    ForEach(DepthScaleUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .help("Choose depth scale units")
            }

            Section("Visibility") {
                Toggle("Use absolute altitude", isOn: useAbsoluteAltitudeBinding)
                    .accessibilityLabel("Use absolute altitude")
                    .help("Anchor depth values to absolute altitude")
                Toggle("Show legend", isOn: $settings.showLegend)
                    .help("Show or hide the legend")
                Toggle("Show depth scale", isOn: $settings.showScale)
                    .help("Show or hide the depth scale")
                Toggle("Show grain size scale", isOn: $settings.showGrainSizeScale)
                    .help("Show or hide the grain size scale")
                Toggle("Show USGS codes in labels", isOn: $settings.showUSGSCodesInLithologyLabels)
                    .help("Show or hide USGS lithology codes in labels")
                Toggle("Show log title", isOn: $settings.showLogTitle)
                    .help("Show or hide the log title")
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

    private var pointFeatureIconSizeBinding: Binding<Double> {
        Binding(
            get: { settings.pointFeatureIconSize },
            set: { settings.pointFeatureIconSize = snapped($0, step: 0.5, range: ProjectSettings.pointFeatureIconSizeRange) }
        )
    }

    private func snapped(_ value: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
}
