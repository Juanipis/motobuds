import Foundation

/// Tipped builders for outgoing commands.  Each function returns a fully-
/// encoded `Packet` ready to write to the GATT command characteristic.
///
/// Mappings come from the decompiled `BudsProxy.q()` / `t()` callers — see
/// `docs/protocol.md`. Anything that requires confirmation against real
/// hardware is marked with `// TBD`.
public enum Commands {

    // MARK: System

    public static func getBattery(seq: UInt16) -> Packet {
        Packet(opcode: Opcode.getBatteryLevel.rawValue, seq: seq)
    }

    public static func getHardwareInfo(seq: UInt16) -> Packet {
        Packet(opcode: Opcode.getHardwareInfo.rawValue, seq: seq)
    }

    public static func getSupportFeatures(seq: UInt16) -> Packet {
        Packet(opcode: Opcode.getSupportFeatures.rawValue, seq: seq)
    }

    // MARK: ANC

    /// Set the actual ANC engine state via opcode `0x201 setANCMode`.
    ///
    /// VERIFIED EMPIRICALLY (this is what the touch button on the bud emits):
    /// payload is **2 bytes** `[category, sub]` where:
    ///   - category 0, sub 0      → off
    ///   - category 1, sub 1/2/3  → ANC strength 1 (light) / 2 (medium) / 3 (high)
    ///   - category 2, sub 0      → transparency
    ///
    /// Earlier attempts with a single-byte payload returned `res=2` (rejected).
    /// `0x102 setToggleConfig` only updates the user preference but does NOT
    /// trigger the audible mode change. `0x201` does.
    public static func setANC(_ mode: ANCMode, seq: UInt16) -> Packet {
        let payload: [UInt8] = {
            switch mode {
            case .off:          return [0x00, 0x00]
            case .transparency: return [0x02, 0x00]
            case .anc:          return [0x01, 0x03]   // high strength (matches touch)
            case .adaptive:     return [0x01, 0x01]   // light strength
            }
        }()
        return Packet(opcode: Opcode.setANCMode.rawValue, seq: seq,
                      payload: Data(payload))
    }

    /// Companion: persist the user-preferred ANC mode via toggle config so it
    /// survives reconnects. Format: `[feature_id=1, category, sub]`.
    public static func saveANCPreference(_ mode: ANCMode, seq: UInt16) -> Packet {
        let payload: [UInt8] = {
            switch mode {
            case .off:          return [0x01, 0x00, 0x00]
            case .transparency: return [0x01, 0x02, 0x00]
            case .anc:          return [0x01, 0x01, 0x03]
            case .adaptive:     return [0x01, 0x01, 0x01]
            }
        }()
        return Packet(opcode: Opcode.setToggleConfig.rawValue, seq: seq,
                      payload: Data(payload))
    }

    /// Optional adaptive-hearing toggle. Independent of ANC mode.
    public static func setAdaptive(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setAdaptationStatus.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }

    public static func getANC(seq: UInt16) -> Packet {
        Packet(opcode: Opcode.getANCMode.rawValue, seq: seq)
    }

    // MARK: Find buds (opcode 0x405)

    /// Payload TBD — 1 byte side-flag is the most common convention:
    /// `0x00` = left, `0x01` = right, `0x02` = both. Verify with PacketLogger.
    public static func findBuds(side: BudSide, seq: UInt16) -> Packet {
        let sideByte: UInt8 = side == .left ? 0x00 : 0x01
        return Packet(opcode: Opcode.findMyDevice.rawValue, seq: seq, payload: Data([sideByte, 0x01]))
    }

    public static func stopFindBuds(seq: UInt16) -> Packet {
        Packet(opcode: Opcode.findMyDevice.rawValue, seq: seq, payload: Data([0x02, 0x00]))
    }

    // MARK: Dual connection

    public static func setDualConnection(_ on: Bool, seq: UInt16) -> Packet {
        // Per BudsProxy: payload is [config_marker, value]. We default
        // config_marker to 1 (no cached config), value to 0/1.
        Packet(opcode: Opcode.setDualConnection.rawValue, seq: seq,
               payload: Data([0x01, on ? 0x01 : 0x00]))
    }

    public static func getDualConnection(seq: UInt16) -> Packet {
        Packet(opcode: Opcode.getDualConnection.rawValue, seq: seq)
    }

    // MARK: In-ear detection

    public static func setInEarDetection(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setInEarDetection.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }

    // MARK: Audio enhancements

    public static func setBassEnhancement(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setBassEnhancement.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }

    public static func setVolumeBoost(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setVolumeBoost.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }

    public static func setHiRes(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setHiResMode.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }

    public static func setGameMode(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setGameMode.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }

    /// Adaptive hearing (feature 105). `setAdaptationStatus` (0x203) — single
    /// byte payload: 0=off, 1=on. TBD whether values are flipped.
    public static func setAdaptiveHearing(_ on: Bool, seq: UInt16) -> Packet {
        Packet(opcode: Opcode.setAdaptationStatus.rawValue, seq: seq,
               payload: Data([on ? 0x01 : 0x00]))
    }
}
