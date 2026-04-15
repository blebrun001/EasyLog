import Testing
import Foundation
@testable import EasyLogKit

@MainActor
@Test
func viewModelUsesInjectedRenderTuningForZoomClamp() {
    let vm = ProjectViewModel(
        project: Project.sample,
        store: JSONProjectStore(),
        exporter: CompositeExporter(),
        defaults: UserDefaults(suiteName: "easylog-vm-tuning-\(UUID().uuidString)")!,
        tuning: RenderTuning(minZoom: 0.8, maxZoom: 1.2, defaultZoom: 0.9)
    )

    vm.setManualZoom(10)
    #expect(abs(vm.zoom - 1.2) < 0.0001)

    vm.setManualZoom(0.1)
    #expect(abs(vm.zoom - 0.8) < 0.0001)
}
