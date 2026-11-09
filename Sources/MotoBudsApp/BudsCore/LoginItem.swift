import Foundation
import ServiceManagement

/// Wrapper around `SMAppService.mainApp` so the rest of the app can
/// observe / toggle "Open at Login" without dragging ServiceManagement
/// imports everywhere.
///
/// Implementation note: macOS 13+ replaced the old SMLoginItemSetEnabled
/// (which required a separate helper bundle and a Team ID on the parent
/// app) with `SMAppService.mainApp` — the system enables the app itself
/// as a login item by reading its bundle identifier. No helper, no signing
/// requirement beyond the app's own ad-hoc signature.
@MainActor
public enum LoginItem {

    public enum State: Equatable {
        case enabled
        case disabled
        case requiresApproval   // user opted in but System Settings hasn't approved yet
        case unsupported        // pre-macOS 13 or app not bundled
    }

    public static var current: State {
        guard #available(macOS 13.0, *) else { return .unsupported }
        switch SMAppService.mainApp.status {
        case .enabled:           return .enabled
        case .notFound:          return .disabled
        case .notRegistered:     return .disabled
        case .requiresApproval:  return .requiresApproval
        @unknown default:        return .disabled
        }
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Result<State, Error> {
        guard #available(macOS 13.0, *) else { return .success(.unsupported) }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return .success(current)
        } catch {
            return .failure(error)
        }
    }
}
