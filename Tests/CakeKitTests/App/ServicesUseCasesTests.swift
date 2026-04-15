import Foundation
import Testing
@testable import CakeKit

private final class MockProjectPersisting: ProjectPersisting {
    var loadedDocument: ProjectDocument = ProjectDocument(logs: [Project.sample])
    var loadError: Error?
    var saveError: Error?

    private(set) var savedDocument: ProjectDocument?
    private(set) var savedURL: URL?

    func load(url _: URL) throws -> ProjectDocument {
        if let loadError {
            throw loadError
        }
        return loadedDocument
    }

    func save(_ document: ProjectDocument, to url: URL) throws {
        if let saveError {
            throw saveError
        }
        savedDocument = document
        savedURL = url
    }
}

private final class MockExportingService: Exporting {
    var error: Error?
    private(set) var lastURL: URL?
    private(set) var lastOptions: ExportOptions?

    func export(scene _: RenderScene, to url: URL, options: ExportOptions) throws {
        if let error {
            throw error
        }
        lastURL = url
        lastOptions = options
    }
}

private enum TestFailure: Error {
    case boom
}

@Test
func colorProfileServiceUniqueProfileNameNormalizesAndAvoidsCollisions() {
    let service = ColorProfileService()
    let existing = [
        LithologyColorProfile(name: "Default"),
        LithologyColorProfile(name: "Test"),
        LithologyColorProfile(name: "Test 2")
    ]

    let unique = service.uniqueProfileName(base: "  test ", existingProfiles: existing)

    #expect(unique == "test 3")
}

@Test
func colorProfileServiceUniqueNameCanExcludeCurrentProfile() {
    let service = ColorProfileService()
    let kept = LithologyColorProfile(name: "Profile A")
    let other = LithologyColorProfile(name: "Profile A 2")

    let unique = service.uniqueProfileName(base: " Profile A ", existingProfiles: [kept, other], excludingID: kept.id)

    #expect(unique == "Profile A")
}

@Test
func colorProfileServiceNormalizedStoreFallsBackToValidActiveProfile() {
    let service = ColorProfileService()
    let first = LithologyColorProfile(name: "A")
    let second = LithologyColorProfile(name: "B")

    let normalized = service.normalizedStore(profiles: [first, second], activeProfileID: UUID())

    #expect(normalized.profiles.count == 2)
    #expect(normalized.activeProfileID == first.id)
}

@Test
func sceneRefreshServicePrioritizesStructuralAndSliderRules() {
    let service = SceneRefreshService()

    #expect(service.mergedTrigger(current: .slider, incoming: .structural) == .structural)
    #expect(service.mergedTrigger(current: .structural, incoming: .textInput) == .structural)
    #expect(service.mergedTrigger(current: .slider, incoming: .textInput) == .slider)
    #expect(service.mergedTrigger(current: .textInput, incoming: .slider) == .slider)
}

@Test
func sceneRefreshServiceCanOpenSyntheticRequiresAtLeastTwoLogsAndZeroLevels() {
    let service = SceneRefreshService()
    var a = Project.sample
    var b = Project.sample

    a.settings.zeroLevelAltitudeMeters = 100
    b.settings.zeroLevelAltitudeMeters = nil

    #expect(service.canOpenSynthetic(logs: [a]) == false)
    #expect(service.canOpenSynthetic(logs: [a, b]) == false)

    b.settings.zeroLevelAltitudeMeters = 98
    #expect(service.canOpenSynthetic(logs: [a, b]) == true)
}

@Test
func zoomServiceClampsAndComputesFitScales() {
    let service = ZoomService()
    let tuning = RenderTuning(minZoom: 0.5, maxZoom: 2.0, defaultZoom: 1.1, fitWidthVisualBoost: 1.2, maxRenderScale: 4)

    #expect(service.clampedZoom(0.1, tuning: tuning) == 0.5)
    #expect(service.clampedZoom(3.0, tuning: tuning) == 2.0)
    #expect(service.clampedAutoFitZoom(0.3, tuning: tuning) == 0.5)
    #expect(service.fitScaleForWidth(viewportWidth: 300, canvasWidth: 0, applyingVisualBoost: true, tuning: tuning) == 1.1)
    #expect(service.fitScaleForWidth(viewportWidth: 240, canvasWidth: 200, applyingVisualBoost: true, tuning: tuning) == 1.44)
    #expect(service.fitScaleForHeight(viewportHeight: 100, canvasHeight: 0, tuning: tuning) == 1.1)
    #expect(service.fitScaleForHeight(viewportHeight: 100, canvasHeight: 200, tuning: tuning) == 0.5)
    #expect(service.resolvedRenderScale(backingScale: 3, zoom: 2, tuning: tuning) == 4)
}

@Test
func projectDocumentServiceNewDocumentHasSingleLog() {
    let service = ProjectDocumentService(persister: JSONProjectStore())
    let document = service.newDocument()

    #expect(document.logs.count == 1)
}

@Test
func projectDocumentServiceOpenAndSaveUsePersisterAndNowClock() throws {
    let persister = MockProjectPersisting()
    let loaded = ProjectDocument(logs: [Project(units: [StratigraphicUnit(name: "A", thickness: 1, usgsLithologyCode: 607)])])
    persister.loadedDocument = loaded

    let fixedNow = Date(timeIntervalSince1970: 1_700_100_000)
    let service = ProjectDocumentService(persister: persister, now: { fixedNow })

    let opened = try service.open(url: URL(fileURLWithPath: "/tmp/open.json"))
    #expect(opened == loaded)

    let input = ProjectDocument(logs: [Project.sample, Project.sample])
    let saved = try service.save(input, to: URL(fileURLWithPath: "/tmp/save.json"))
    #expect(saved.logs.allSatisfy { $0.metadata.updatedAt == fixedNow })
}

@Test
func projectDocumentServicePropagatesLoadAndSaveErrors() {
    let failing = MockProjectPersisting()
    failing.loadError = TestFailure.boom
    let serviceLoad = ProjectDocumentService(persister: failing)

    #expect(throws: (any Error).self) {
        _ = try serviceLoad.open(url: URL(fileURLWithPath: "/tmp/boom.json"))
    }
}

@Test
func exportServiceDelegatesFormatAndDPIAndPropagatesError() {
    let exporter = MockExportingService()
    let service = ExportService(exporter: exporter)
    let scene = makeSimpleScene()
    let out = makeTempFileURL(prefix: "export-service", ext: "svg")

    #expect(throws: Never.self) {
        try service.export(scene: scene, to: out, format: .svg, dpi: 144)
    }

    exporter.error = TestFailure.boom
    let failingService = ExportService(exporter: exporter)
    #expect(throws: (any Error).self) {
        try failingService.export(scene: scene, to: out, format: .jpg, dpi: 300)
    }
}

@Test
func addDeleteAndMoveUseCasesBehaveSafelyAtEdges() {
    var project = Project(units: [
        StratigraphicUnit(name: "A", thickness: 1, usgsLithologyCode: 607),
        StratigraphicUnit(name: "B", thickness: 1, usgsLithologyCode: 627),
        StratigraphicUnit(name: "C", thickness: 1, usgsLithologyCode: 609)
    ])

    let add = AddUnitUseCase()
    let addedID = add.execute(project: &project)
    #expect(project.units.count == 4)
    #expect(project.units.last?.id == addedID)

    let move = MoveSelectedUnitUseCase()
    let firstID = project.units[0].id
    move.execute(project: &project, selectedUnitID: firstID, direction: .up)
    #expect(project.units[0].id == firstID)

    move.execute(project: &project, selectedUnitID: firstID, direction: .down)
    #expect(project.units[1].id == firstID)

    let delete = DeleteSelectedUnitUseCase()
    let selection = delete.execute(project: &project, selectedUnitID: firstID)
    #expect(project.units.count == 3)
    #expect(selection != nil)

    var single = Project(units: [StratigraphicUnit(name: "Only", thickness: 1, usgsLithologyCode: 607)])
    let removedSelection = delete.execute(project: &single, selectedUnitID: single.units[0].id)
    #expect(single.units.isEmpty)
    #expect(removedSelection == nil)
}

private final class RecordingExporter: Exporter {
    var called = false
    var options: ExportOptions?

    func export(scene _: RenderScene, to _: URL, options: ExportOptions) throws {
        called = true
        self.options = options
    }
}

@Test
func openSaveAndExportUseCasesCoverHappyPaths() throws {
    let store = JSONProjectStore()
    let file = makeTempFileURL(prefix: "usecase", ext: "json")
    let source = ProjectDocument(logs: [Project.sample])
    try store.save(source, to: file)

    let opened = try OpenProjectUseCase(store: store).execute(url: file)
    #expect(opened.logs.count == 1)

    let fixedNow = Date(timeIntervalSince1970: 1_700_000_111)
    let saved = try SaveProjectUseCase(store: store, now: { fixedNow }).execute(document: opened, url: file)
    #expect(saved.logs.allSatisfy { $0.metadata.updatedAt == fixedNow })

    let recordingExporter = RecordingExporter()
    let exportUseCase = ExportProjectUseCase(exporter: recordingExporter)
    try exportUseCase.execute(scene: makeSimpleScene(), url: makeTempFileURL(prefix: "usecase-export", ext: "svg"), format: .svg, dpi: 200)
    #expect(recordingExporter.called)
    #expect(recordingExporter.options?.format == .svg)
    #expect(recordingExporter.options?.dpi == 200)
}
