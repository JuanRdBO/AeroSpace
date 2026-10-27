@testable import AppBundle
import Combine
import Common
import XCTest

@MainActor
final class TrayMenuModelTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private var publishes = (trayText: 0, workspaces: 0, trayItems: 0)
    private var subscriptions: Set<AnyCancellable> = []

    override func tearDown() async throws { subscriptions = [] }

    /// Counts every `@Published` emission (they fire on each assignment, equal or not)
    private func observe() {
        let model = TrayMenuModel.shared
        publishes = (0, 0, 0)
        model.$trayText.dropFirst().sink { [unowned self] _ in publishes.trayText += 1 }.store(in: &subscriptions)
        model.$workspaces.dropFirst().sink { [unowned self] _ in publishes.workspaces += 1 }.store(in: &subscriptions)
        model.$trayItems.dropFirst().sink { [unowned self] _ in publishes.trayItems += 1 }.store(in: &subscriptions)
    }

    func testUnchangedStateDoesNotPublish() {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        updateTrayText()
        observe()

        for _ in 1 ... 100 { updateTrayText() }

        assertEquals("\(publishes)", "\((trayText: 0, workspaces: 0, trayItems: 0))")
    }

    func testFocusedWorkspaceChangePublishesNewState() {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        updateTrayText()
        observe()

        assertTrue(Workspace.get(byName: "b").focusWorkspace())
        updateTrayText()

        assertEquals("\(publishes)", "\((trayText: 1, workspaces: 1, trayItems: 1))")
        assertEquals(TrayMenuModel.shared.trayText, "b")
        assertEquals(TrayMenuModel.shared.trayItems.map(\.name), ["b"])
        assertEquals(TrayMenuModel.shared.workspaces.singleOrNil(where: \.isFocused)?.name, "b")
    }

    func testWindowInInvisibleWorkspacePublishesOnlyWorkspaces() {
        assertTrue(Workspace.get(byName: "a").focusWorkspace())
        let b = Workspace.get(byName: "b")
        updateTrayText()
        observe()

        TestWindow.new(id: 1, parent: b.rootTilingContainer)
        updateTrayText()

        assertEquals("\(publishes)", "\((trayText: 0, workspaces: 1, trayItems: 0))")
        let bViewModel = TrayMenuModel.shared.workspaces.singleOrNil(where: { $0.name == "b" })
        assertEquals(bViewModel?.isEffectivelyEmpty, false)
        assertEquals(bViewModel?.suffix, " - \(TestApp.shared.name.orDie())")
    }
}
