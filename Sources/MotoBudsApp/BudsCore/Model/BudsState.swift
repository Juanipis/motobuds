import Foundation

/// Modos ANC del Moto Buds (XT2443-1, "guitar"). Mapeo de byte por
/// `Commands.setANC` — confirmado del decompile pero el orden exacto
/// del firmware se valida al primer toggle.
public enum ANCMode: String, CaseIterable, Sendable, Identifiable {
    case off
    case transparency
    case anc
    case adaptive
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: return "Apagado"
        case .transparency: return "Transparencia"
        case .anc: return "Cancelación"
        case .adaptive: return "Adaptativo"
        }
    }
    public var symbol: String {
        switch self {
        case .off: return "speaker.slash"
        case .transparency: return "ear"
        case .anc: return "waveform.path.ecg"
        case .adaptive: return "wand.and.stars"
        }
    }
}

public enum BudSide: String, Sendable {
    case left, right
    public var displayName: String { self == .left ? "Izquierdo" : "Derecho" }
}

public struct FirmwareInfo: Sendable, Equatable {
    public var leftBud: String?
    public var rightBud: String?
    public var caseFW: String?
}

/// Toggles soportados por el modelo `guitar` (Moto Buds XT2443-1).
public struct AudioToggles: Sendable, Equatable {
    public var bassEnhancement: Bool = false
    public var volumeBoost: Bool = false
    public var hiRes: Bool = false
    public var gameMode: Bool = false
    public var inEarDetection: Bool = true
    public var adaptiveHearing: Bool = false
}

/// Find-buds active state. The buds emit a loud sound while finding.
public enum FindBudsState: Sendable, Equatable {
    case idle
    case findingLeft
    case findingRight
    case findingBoth
}

/// Live status reported by the buds (notifications, not toggles we set).
public struct LiveStatus: Sendable, Equatable {
    public var leftInEar: Bool = false
    public var rightInEar: Bool = false
    public var leftInCase: Bool = false
    public var rightInCase: Bool = false
    public var leftFit: Int? = nil      // 0..3, higher = better fit
    public var rightFit: Int? = nil
}

public struct BudsState: Sendable, Equatable {
    public enum Connection: Sendable, Equatable { case disconnected, connecting, connected }

    public var connection: Connection = .disconnected
    public var deviceName: String = "Moto Buds"
    public var deviceMAC: String = ""

    public var batteryLeft: Int?
    public var batteryRight: Int?
    public var batteryCase: Int?

    public var ancMode: ANCMode = .off
    public var toggles: AudioToggles = AudioToggles()
    public var dualConnect: Bool = false
    public var firmware: FirmwareInfo = FirmwareInfo()
    public var live: LiveStatus = LiveStatus()
    public var findBuds: FindBudsState = .idle
}
