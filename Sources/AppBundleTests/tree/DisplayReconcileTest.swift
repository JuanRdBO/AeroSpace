@testable import AppBundle
import Common
import XCTest

/// Offline lid-close geometry from the live 3→2 capture.
/// Rearrange / gcMonitors / setActiveWorkspace never call AX or NSScreen when isUnitTest.
/// Intended repair dest (not in this commit): focused.workspaceMonitor with the new
/// monitors already installed and maps not yet cleared. That uses existing force
/// assignment and monitorApproximation fallbacks. Do not invent a second distance map.
@MainActor
final class DisplayReconcileTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    override func tearDown() async throws {
        installTestMonitors([])
        gcMonitors()
        installTestMonitors(nil)
        resetFrozenFocusForTests()
    }

    func testForcedFallback_3to2_keepsFocusedWorkspaceVisible() {
        seedOpenThreeMonitors(forceAssignNumerics: true)
        assertTrue(Workspace.get(byName: "2").focusWorkspace())
        applyClosedTwoMonitors()
        gcMonitors()

        assertEquals(focus.workspace.name, "2")
        assertEquals(closedRight().activeWorkspace.name, "2")
        assertFalse(Workspace.get(byName: "R").isVisible)
        assertReconcileInvariants()
        gcMonitors()
        assertEquals(closedRight().activeWorkspace.name, "2")
        assertFalse(Workspace.get(byName: "R").isVisible)
        assertReconcileInvariants()
    }

    func testAlreadyVisibleFocus_unforced_staysOnNearestSurvivor() {
        seedOpenThreeMonitors(forceAssignNumerics: false)
        assertTrue(Workspace.get(byName: "2").focusWorkspace())
        applyClosedTwoMonitors()
        gcMonitors()

        assertEquals(focus.workspace.name, "2")
        assertEquals(closedLeft().activeWorkspace.name, "2")
        assertEquals(closedRight().activeWorkspace.name, "R")
        assertReconcileInvariants()
    }

    func testUnforcedCollision_restoresLostLeftFocus() {
        seedOpenThreeMonitors(forceAssignNumerics: false)
        assertTrue(Workspace.get(byName: "1").focusWorkspace())
        applyClosedTwoMonitors()
        gcMonitors()

        assertEquals(focus.workspace.name, "1")
        assertEquals(closedLeft().activeWorkspace.name, "1")
        assertFalse(Workspace.get(byName: "2").isVisible)
        assertEquals(closedRight().activeWorkspace.name, "R")
        assertTrue(Workspace.get(byName: "R").isVisible)
        assertReconcileInvariants()
    }

    func testColdLazyFocusInit_afterClearedMaps() {
        seedOpenThreeMonitors(forceAssignNumerics: true)
        installTestMonitors([])
        gcMonitors()
        resetFrozenFocusForTests()
        assertNil(initializedFrozenFocusWorkspaceName)
        installTestMonitors([closedLeft()])
        let workspace = focus.workspace
        assertNotNil(initializedFrozenFocusWorkspaceName)
        assertTrue(workspace.isVisible)
        assertEquals(closedLeft().activeWorkspace.name, workspace.name)
        assertReconcileInvariants()
    }

    func testActiveWorkspace_sameCountChangedOrigins() {
        config.persistentWorkspaces = ["1", "R"]
        installTestMonitors([closedLeft(), closedRight()])
        gcMonitors()
        check(closedLeft().setActiveWorkspace(Workspace.get(byName: "1")))
        check(closedRight().setActiveWorkspace(Workspace.get(byName: "R")))
        assertTrue(Workspace.get(byName: "1").focusWorkspace())

        let shiftedLeft = testMonitor(
            name: "DELL S2725QC (2)",
            id: 1,
            topLeftX: 10,
            topLeftY: 10,
            width: 1920,
            height: 1080,
            isMain: true,
        )
        let shiftedRight = testMonitor(
            name: "DELL S2725QC (1)",
            id: 2,
            topLeftX: 1930,
            topLeftY: 10,
            width: 1920,
            height: 1080,
            isMain: false,
        )
        installTestMonitors([shiftedLeft, shiftedRight])
        gcMonitors()
        assertEquals(closedLeft().activeWorkspace.name, "1")

        assertEquals(shiftedLeft.activeWorkspace.name, "1")
        assertTrue(Workspace.get(byName: "1").isVisible)
        assertEquals(shiftedRight.activeWorkspace.name, "R")
        assertReconcileInvariants()
    }

    func testEmptyMonitors_skipRepairAndLeaveNoVisibles() {
        seedOpenThreeMonitors(forceAssignNumerics: true)
        assertTrue(Workspace.get(byName: "2").focusWorkspace())
        installTestMonitors([])
        gcMonitors()
        assertEquals(initializedFrozenFocusWorkspaceName, "2")
        assertEquals(focus.workspace.name, "2")
        assertFalse(Workspace.get(byName: "2").isVisible)
        assertEquals(visibleSnapshot().count, 0)
    }
}

private struct TestMonitor: Monitor {
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}

@MainActor
private func installTestMonitors(_ monitors: [Monitor]?) {
    unsafe testMonitors = monitors
}

@MainActor
private func testMonitor(
    name: String,
    id: Int,
    topLeftX: CGFloat,
    topLeftY: CGFloat,
    width: CGFloat,
    height: CGFloat,
    isMain: Bool,
) -> Monitor {
    let rect = Rect(topLeftX: topLeftX, topLeftY: topLeftY, width: width, height: height)
    return TestMonitor(
        monitorAppKitNsScreenScreensId: id,
        name: name,
        rect: rect,
        visibleRect: rect,
        isMain: isMain,
    )
}

@MainActor
private func openLeft() -> Monitor {
    testMonitor(name: "DELL S2725QC (2)", id: 1, topLeftX: -1920, topLeftY: -1080, width: 1920, height: 1080, isMain: false)
}

@MainActor
private func openLaptop() -> Monitor {
    testMonitor(name: "Built-in Retina Display", id: 2, topLeftX: 0, topLeftY: 0, width: 1728, height: 1117, isMain: true)
}

@MainActor
private func openRight() -> Monitor {
    testMonitor(name: "DELL S2725QC (1)", id: 3, topLeftX: 1728, topLeftY: -1080, width: 1920, height: 1080, isMain: false)
}

@MainActor
private func closedLeft() -> Monitor {
    testMonitor(name: "DELL S2725QC (2)", id: 1, topLeftX: 0, topLeftY: 0, width: 1920, height: 1080, isMain: true)
}

@MainActor
private func closedRight() -> Monitor {
    testMonitor(name: "DELL S2725QC (1)", id: 2, topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080, isMain: false)
}

@MainActor
private func seedOpenThreeMonitors(forceAssignNumerics: Bool) {
    config.persistentWorkspaces = ["1", "2", "R"]
    if forceAssignNumerics {
        config.workspaceToMonitorForceAssignment = [
            "1": [.sequenceNumber(1)],
            "2": [.sequenceNumber(2)],
        ]
    }
    installTestMonitors([openLeft(), openLaptop(), openRight()])
    gcMonitors()
    check(openLeft().setActiveWorkspace(Workspace.get(byName: "1")))
    check(openLaptop().setActiveWorkspace(Workspace.get(byName: "2")))
    check(openRight().setActiveWorkspace(Workspace.get(byName: "R")))
}

@MainActor
private func applyClosedTwoMonitors() {
    installTestMonitors([closedLeft(), closedRight()])
}

@MainActor
private func visibleSnapshot() -> [String] {
    Workspace.all
        .filter(\.isVisible)
        .map { "\($0.name)@\($0.workspaceMonitor.rect.topLeftX),\($0.workspaceMonitor.rect.topLeftY)" }
        .sorted()
}

@MainActor
private func assertReconcileInvariants() {
    let visibles = Workspace.all.filter(\.isVisible)
    let origins = visibles.map { "\($0.workspaceMonitor.rect.topLeftX),\($0.workspaceMonitor.rect.topLeftY)" }
    assertEquals(Set(origins).count, origins.count)
    assertEquals(visibles.count, monitors.count)
    for monitor in monitors {
        assertEquals(visibles.filter { $0.workspaceMonitor.rect.topLeftCorner == monitor.rect.topLeftCorner }.count, 1)
    }
}
