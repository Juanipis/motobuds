import SwiftUI
import AppKit

@main
struct MotoBudsApp: App {
    @State private var manager: BudsManager
    @StateObject private var updater = Updater()

    init() {
        let env = ProcessInfo.processInfo.environment
        let m: BudsManager
        if env["MOTOBUDS_REAL"] == nil {
            m = BudsManager.mock()
        } else {
            // SPP transport is the path that actually works on macOS — RFCOMM
            // ch 16 with `fc9d9fe0` UUID. Verified with the SPP probe.
            let cfg = SPPTransport.Config(mac: "a4-05-6e-d9-c9-14", channel: 16)
            m = BudsManager(transport: SPPTransport(config: cfg), usingMock: false)
        }
        _manager = State(wrappedValue: m)
        // Kick connect immediately — `.onAppear` doesn't fire reliably with
        // LSUIElement + MenuBarExtra apps (no Dock, window may stay hidden).
        m.connect()
    }

    var body: some Scene {
        WindowGroup("MotoBuds") {
            ContentView(manager: manager)
                .environmentObject(updater)
                .background(MotoColor.bgDeep)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Buscar actualizaciones…") { updater.checkNow() }
                    .disabled(!updater.canCheck)
            }
        }

        MenuBarExtra {
            MenuBarView(manager: manager) {
                NSApp.activate(ignoringOtherApps: true)
                for w in NSApp.windows where w.canBecomeMain {
                    w.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let connected = manager.state.connection == .connected
        Image(systemName: connected ? "earbuds" : "earbuds.slash")
    }
}
