import Testing
@testable import CakeKit

/// Validates geometry, legend composition and point-symbol density behavior.
@Test
func rendererProducesStackedUnitsWithoutOverlap() {
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 2, lithology: "Massive sand or sandstone"),
            StratigraphicUnit(name: "B", thickness: 3, lithology: "Sandy or silty shale"),
            StratigraphicUnit(name: "C", thickness: 1.5, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)

    #expect(scene.units.count == 3)
    let first = scene.units[0].rect
    let second = scene.units[1].rect
    let third = scene.units[2].rect
    #expect(first.y + first.height == second.y)
    #expect(second.y + second.height == third.y)
}

@Test
func legendContainsEveryUsedUSGSSymbolCode() {
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 2, lithology: "Massive sand or sandstone"),
            StratigraphicUnit(name: "B", thickness: 2, lithology: "Crossbedded sand or sandstone (1st option)"),
            StratigraphicUnit(name: "C", thickness: 2, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)

    #expect(scene.legend.count == 3)
    #expect(scene.legend[0].symbol == .sandstone)
    #expect(scene.legend[0].usgsSymbolCode == 607)
    #expect(scene.legend[1].symbol == .sandstone)
    #expect(scene.legend[1].usgsSymbolCode == 609)
    #expect(scene.legend[2].symbol == .limestone)
    #expect(scene.legend[2].usgsSymbolCode == 627)
}

@Test
func sceneCarriesConfiguredSymbolScale() {
    let project = Project(
        settings: ProjectSettings(symbolScale: 1.8),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)
    #expect(scene.symbolScale == 1.8)
}

@Test
func pointFeaturesAppearInLegendOnlyWhenUsed() {
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "A",
                thickness: 2,
                lithology: "Massive sand or sandstone",
                pointFeatures: [
                    UnitPointFeature(type: .archaeologicalBoneFragments, concentration: .low)
                ]
            ),
            StratigraphicUnit(
                name: "B",
                thickness: 2,
                lithology: "Limestone",
                pointFeatures: [
                    UnitPointFeature(type: .hydroDissolutionTraces, concentration: .high)
                ]
            )
        ]
    )

    let scene = CakeRenderer().makeScene(project: project)
    let pointLegendItems = scene.legend.filter { $0.pointIconToken != nil || $0.pointSymbol != nil }

    #expect(pointLegendItems.count == 2)
    #expect(pointLegendItems.contains(where: { $0.label.contains("Bone Fragments") }))
    #expect(pointLegendItems.contains(where: { $0.label.contains("Dissolution Traces") }))
    #expect(pointLegendItems.allSatisfy { $0.pointIconToken != nil })
}

@Test
func samePointFeatureAcrossUnitsAppearsOnceInLegend() {
    let sharedType: PointFeatureType = .paleoMicrofossils
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "A",
                thickness: 2,
                lithology: "Massive sand or sandstone",
                pointFeatures: [UnitPointFeature(type: sharedType, density: 0.2)]
            ),
            StratigraphicUnit(
                name: "B",
                thickness: 2,
                lithology: "Limestone",
                pointFeatures: [UnitPointFeature(type: sharedType, density: 0.8)]
            )
        ]
    )

    let scene = CakeRenderer().makeScene(project: project)
    let matches = scene.legend.filter { $0.label.contains(sharedType.label) }
    #expect(matches.count == 1)
}

@Test
func highConcentrationProducesMorePointSymbolsAndStaysInsideUnit() {
    let unit = StratigraphicUnit(
        name: "A",
        thickness: 4,
        lithology: "Massive sand or sandstone",
        pointFeatures: [
            UnitPointFeature(type: .archaeologicalBoneFragments, concentration: .low),
            UnitPointFeature(type: .archaeologicalArtifacts, concentration: .high)
        ]
    )
    let scene = CakeRenderer().makeScene(project: Project(units: [unit]))
    let renderedUnit = scene.units[0]
    let rect = renderedUnit.rect

    let lowCount = renderedUnit.pointFeatures.filter { $0.type == .archaeologicalBoneFragments }.count
    let highCount = renderedUnit.pointFeatures.filter { $0.type == .archaeologicalArtifacts }.count
    #expect(highCount > lowCount)
    #expect(lowCount > 0)

    for point in renderedUnit.pointFeatures {
        #expect(point.centerX >= rect.x)
        #expect(point.centerX <= rect.x + rect.width)
        #expect(point.centerY >= rect.y)
        #expect(point.centerY <= rect.y + rect.height)
    }
}

@Test
func higherDensityProducesMorePointSymbols() {
    let unit = StratigraphicUnit(
        name: "A",
        thickness: 4,
        lithology: "Massive sand or sandstone",
        pointFeatures: [
            UnitPointFeature(type: .archaeologicalBoneFragments, density: 0.2),
            UnitPointFeature(type: .archaeologicalArtifacts, density: 0.9)
        ]
    )

    let scene = CakeRenderer().makeScene(project: Project(units: [unit]))
    let renderedUnit = scene.units[0]
    let lowDensityCount = renderedUnit.pointFeatures.filter { $0.type == .archaeologicalBoneFragments }.count
    let highDensityCount = renderedUnit.pointFeatures.filter { $0.type == .archaeologicalArtifacts }.count
    #expect(highDensityCount > lowDensityCount)
}

@Test
func pointFeatureIconSizeIsPropagatedToSceneAndRenderedPoints() {
    let project = Project(
        settings: ProjectSettings(pointFeatureIconSize: 11.5),
        units: [
            StratigraphicUnit(
                name: "A",
                thickness: 2,
                lithology: "Massive sand or sandstone",
                pointFeatures: [UnitPointFeature(type: .paleoRoots, density: 0.4)]
            )
        ]
    )
    let scene = CakeRenderer().makeScene(project: project)
    #expect(scene.pointFeatureIconSize == 11.5)
    #expect(scene.units.first?.pointFeatures.allSatisfy { abs($0.size - 11.5) < 0.001 } == true)
}

@Test
func sceneCarriesConfiguredDepthScaleUnit() {
    let project = Project(
        settings: ProjectSettings(depthScaleUnit: .centimeter),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")
        ]
    )
    let scene = CakeRenderer().makeScene(project: project)
    #expect(scene.depthScaleUnit == .centimeter)
}

@Test
func scaleLabelPlacementKeepsRightEdgeAtConstantDistanceFromAxis() {
    let axisX = 80.0
    let widths = [8.0, 24.0, 56.0]
    for width in widths {
        let x = SceneLayout.scaleLabelX(axisX: axisX, labelWidth: width)
        #expect(abs((x + width) - (axisX - SceneLayout.scaleLabelAxisPadding)) < 0.000_001)
    }
}

@Test
func depthTitleMovesLeftWhenScaleLabelsGetWider() {
    let axisX = 80.0
    let titleFontSize = 11.0
    let narrow = SceneLayout.depthLabelCenterX(axisX: axisX, maxScaleLabelWidth: 12, titleFontSize: titleFontSize)
    let wide = SceneLayout.depthLabelCenterX(axisX: axisX, maxScaleLabelWidth: 64, titleFontSize: titleFontSize)

    #expect(wide < narrow)

    let titleHalfThickness = max(titleFontSize * 0.5, SceneLayout.depthLabelMinimumHalfThickness)
    let wideTitleRightEdge = wide + titleHalfThickness
    let wideLabelsLeftEdge = SceneLayout.scaleLabelX(axisX: axisX, labelWidth: 64)
    #expect(wideTitleRightEdge <= wideLabelsLeftEdge - SceneLayout.scaleLabelTitleGap + 0.000_001)
}

@Test
func sceneCarriesConfiguredZeroLevelAltitude() {
    let project = Project(
        settings: ProjectSettings(useAbsoluteAltitude: true, zeroLevelAltitudeMeters: 123),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")
        ]
    )
    let scene = CakeRenderer().makeScene(project: project)
    #expect(scene.useAbsoluteAltitude == true)
    #expect(scene.zeroLevelAltitudeMeters == 123)
}

@Test
func sceneCarriesConfiguredGridVisibility() {
    let project = Project(
        settings: ProjectSettings(showGrid: true),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")
        ]
    )
    let scene = CakeRenderer().makeScene(project: project)
    #expect(scene.showsGrid == true)
}

@Test
func sceneCarriesRenderingVisibilityFlags() {
    let project = Project(
        settings: ProjectSettings(showLegend: false, showScale: false, showLogTitle: false),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")
        ]
    )
    let scene = CakeRenderer().makeScene(project: project)
    #expect(scene.showsLegend == false)
    #expect(scene.showsScale == false)
    #expect(scene.showsLogTitle == false)
}

@Test
func rendererUsesNaturalCanvasSizeWithoutPresetMinimums() {
    let projectLetter = Project(
        settings: ProjectSettings(verticalScale: 25, pageSize: .letterPortrait),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Massive sand or sandstone")
        ]
    )
    let projectA4 = Project(
        settings: ProjectSettings(verticalScale: 25, pageSize: .a4Portrait),
        units: projectLetter.units
    )
    let renderer = CakeRenderer()
    let sceneLetter = renderer.makeScene(project: projectLetter)
    let sceneA4 = renderer.makeScene(project: projectA4)

    // Expected natural dimensions from renderer margins and content.
    #expect(sceneLetter.canvasSize.height == 184)
    #expect(sceneA4.canvasSize.height == 184)
    #expect(sceneLetter.canvasSize.width == sceneA4.canvasSize.width)
    #expect(sceneLetter.canvasSize.width >= 460)
}

@Test
func rendererExpandsCanvasWidthForLongLegendLabels() {
    let baseUnit = StratigraphicUnit(name: "A", thickness: 1, lithology: "Massive sand or sandstone")
    let shortestType = PointFeatureType.allCases.min {
        ("\($0.categoryLabel): \($0.label)").count < ("\($1.categoryLabel): \($1.label)").count
    } ?? .paleoRoots
    let longestType = PointFeatureType.allCases.max {
        ("\($0.categoryLabel): \($0.label)").count < ("\($1.categoryLabel): \($1.label)").count
    } ?? .hydroLocalizedMineralPrecipitation
    let shortLegendUnit = StratigraphicUnit(
        name: "A",
        thickness: 1,
        lithology: "Massive sand or sandstone",
        pointFeatures: [UnitPointFeature(type: shortestType, concentration: .low)]
    )
    let longLegendUnit = StratigraphicUnit(
        name: "A",
        thickness: 1,
        lithology: "Massive sand or sandstone",
        pointFeatures: [UnitPointFeature(type: longestType, concentration: .low)]
    )

    let renderer = CakeRenderer()
    let baseScene = renderer.makeScene(project: Project(units: [baseUnit]))
    let shortLegendScene = renderer.makeScene(project: Project(units: [shortLegendUnit]))
    let longLegendScene = renderer.makeScene(project: Project(units: [longLegendUnit]))

    #expect(shortLegendScene.canvasSize.width >= baseScene.canvasSize.width)
    #expect(longLegendScene.canvasSize.width >= shortLegendScene.canvasSize.width)
}

@Test
func rendererUsesCustomLithologyColorWhenProvided() {
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "A",
                thickness: 1,
                lithology: "Limestone",
                lithologyColorHex: "#abc123"
            )
        ]
    )

    let scene = CakeRenderer().makeScene(project: project)
    #expect(scene.units[0].fillHex == "#ABC123")
    #expect(scene.legend[0].fillHex == "#ABC123")
}

@Test
func rendererFallsBackToUSGSColorWhenNoCustomColor() {
    let lithology = "Limestone"
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: lithology)
        ]
    )

    let scene = CakeRenderer().makeScene(project: project)
    let expected = SymbologyLibrary.style(forLithology: lithology).fillHex
    #expect(scene.units[0].fillHex == expected)
    #expect(scene.legend[0].fillHex == expected)
}

@Test
func legendKeepsSeparateLithologyRowsWhenSameLithologyUsesDifferentColors() {
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone", lithologyColorHex: "#FF0000"),
            StratigraphicUnit(name: "B", thickness: 1, lithology: "Limestone", lithologyColorHex: "#00FF00")
        ]
    )

    let scene = CakeRenderer().makeScene(project: project)
    let limestoneRows = scene.legend.filter { $0.label.contains("Limestone") }
    #expect(limestoneRows.count == 2)
    #expect(Set(limestoneRows.compactMap(\.fillHex)).count == 2)
}

@Test
func syntheticComparisonAlignsUnitsInSharedAltitudeReference() {
    let logA = Project(
        settings: ProjectSettings(
            verticalScale: 20,
            depthScaleUnit: .meter,
            useAbsoluteAltitude: true,
            zeroLevelAltitudeMeters: 100
        ),
        units: [
            StratigraphicUnit(name: "A1", thickness: 2, lithology: "Limestone")
        ]
    )
    let logB = Project(
        settings: ProjectSettings(
            verticalScale: 35,
            depthScaleUnit: .millimeter,
            useAbsoluteAltitude: true,
            zeroLevelAltitudeMeters: 101
        ),
        units: [
            StratigraphicUnit(name: "B1", thickness: 1, lithology: "Limestone")
        ]
    )

    let scene = SyntheticComparisonSceneBuilder.make(logs: [logA, logB], selectedLogIndex: 0, renderer: CakeRenderer())
    #expect(scene.columns.count == 2)

    let unitA = scene.columns[0].units[0]
    let unitB = scene.columns[1].units[0]
    let yAtAltitude100FromA = unitA.rect.y
    let yAtAltitude100FromB = unitB.rect.y + unitB.rect.height
    #expect(abs(yAtAltitude100FromA - yAtAltitude100FromB) < 0.0001)
}

@Test
func syntheticComparisonMergesLegendAcrossLogs() {
    let logA = Project(
        settings: ProjectSettings(useAbsoluteAltitude: true, zeroLevelAltitudeMeters: 100),
        units: [
            StratigraphicUnit(name: "A1", thickness: 1, lithology: "Limestone")
        ]
    )
    let logB = Project(
        settings: ProjectSettings(useAbsoluteAltitude: true, zeroLevelAltitudeMeters: 99),
        units: [
            StratigraphicUnit(name: "B1", thickness: 1, lithology: "Limestone")
        ]
    )

    let scene = SyntheticComparisonSceneBuilder.make(logs: [logA, logB], selectedLogIndex: 0, renderer: CakeRenderer())
    let limestoneRows = scene.legend.filter { $0.label.contains("Limestone") }
    #expect(limestoneRows.count == 1)
}

@Test
func syntheticComparisonUsesSelectedLogDepthUnit() {
    let first = Project(
        settings: ProjectSettings(depthScaleUnit: .meter, zeroLevelAltitudeMeters: 100),
        units: [StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")]
    )
    let second = Project(
        settings: ProjectSettings(depthScaleUnit: .centimeter, zeroLevelAltitudeMeters: 90),
        units: [StratigraphicUnit(name: "B", thickness: 1, lithology: "Limestone")]
    )

    let scene = SyntheticComparisonSceneBuilder.make(
        logs: [first, second],
        selectedLogIndex: 1,
        renderer: CakeRenderer()
    )
    #expect(scene.depthScaleUnit == .centimeter)
}
