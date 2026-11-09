import Foundation

/// Verbatim opcode table from `o4/C1435c.java` (the canonical HashMap).
/// Names preserved as in the original to make cross-referencing easy.
public enum Opcode: UInt16, Sendable {
    // System / general (0x000)
    case getProfileVersion       = 0x000
    case getSupportFeatures      = 0x001
    case getSupportConfigurations = 0x002
    case getDeviceName           = 0x003
    case getHardwareInfo         = 0x004
    case getBatteryLevel         = 0x005
    case getPrimaryEarbud        = 0x006
    case setDeviceName           = 0x007
    case primaryEarbudChanged    = 0x008    // notif
    case batteryLevelChanged     = 0x009    // notif
    case getEarbudsColor         = 0x00A
    case listSupportInfoConfigs  = 0x00B
    case getChannelId            = 0x00C
    case setSupportConfigurations = 0x00D
    case supportConfigsChanged   = 0x00E    // notif

    // Toggle (0x100)
    case getToggleConfigs        = 0x100
    case getToggleConfig         = 0x101
    case setToggleConfig         = 0x102
    case toggleConfigChanged     = 0x105    // notif

    // ANC (0x200)
    case getANCMode              = 0x200
    case setANCMode              = 0x201
    case getAdaptationStatus     = 0x202
    case setAdaptationStatus     = 0x203
    case ancModeChanged          = 0x204    // notif
    case adaptationStatusChanged = 0x205    // notif
    case setEarCanalState        = 0x206
    case earCanalStatusChanged   = 0x207    // notif
    case getDangerDetection      = 0x208
    case setDangerDetection      = 0x209
    case dangerDetectionChanged  = 0x20A    // notif

    // EQ / sound (0x300)
    case getEQState              = 0x300
    case getAvailableEQSets      = 0x301
    case getEQSet                = 0x302
    case setEQSet                = 0x303
    case getUserEQNumBands       = 0x304
    case getUserEQConfig         = 0x305
    case setUserEQConfig         = 0x306
    case eqStateChanged          = 0x307    // notif
    case eqSetChanged            = 0x308    // notif
    case eqUserBandsChanged      = 0x309    // notif
    case getSpatialAudio         = 0x30A
    case setSpatialAudio         = 0x30B
    case getHiResMode            = 0x30C
    case setHiResMode            = 0x30D
    case getGameMode             = 0x30E
    case setGameMode             = 0x30F
    case spatialAudioChanged     = 0x310    // notif
    case hiResStateChanged       = 0x311    // notif
    case gameModeStateChanged    = 0x312    // notif
    case getVolumeBoost          = 0x313
    case setVolumeBoost          = 0x314
    case volumeBoostChanged      = 0x315    // notif
    case getAutoVolume           = 0x316
    case setAutoVolume           = 0x317
    case getCaseRecording        = 0x318
    case setCaseRecording        = 0x319
    case autoVolumeChanged       = 0x31A    // notif
    case caseRecordingChanged    = 0x31B    // notif
    case getBassEnhancement      = 0x31C
    case setBassEnhancement      = 0x31D
    case bassEnhancementChanged  = 0x31E    // notif

    // Wear / find / dual (0x400)
    case setFitState             = 0x400
    case fitStatusChanged        = 0x401    // notif
    case getInEarDetection       = 0x402
    case setInEarDetection       = 0x403
    case inEarStatusChanged      = 0x404    // notif
    case findMyDevice            = 0x405
    case getDualConnection       = 0x406
    case setDualConnection       = 0x407
    case getDualConnectionDevice = 0x408
    case dualConnectionDeviceChanged = 0x409 // notif
    case getLeAudioState         = 0x40A
    case setLeAudioState         = 0x40B
    case inCaseStatusIndication  = 0x40C    // notif
    case inEarDetectionNotif     = 0x40D    // notif
    case findMyDeviceNotif       = 0x40E    // notif
    case dualConnectionChanged   = 0x40F    // notif
    case leAudioChanged          = 0x410    // notif

    // Time / checkpoint (0x500)
    case setCurrentTime          = 0x500
    // 0x501..0x503 are log/checkpoint — we don't touch them.

    // FMD (0x600) — find my device extended
    case getFmdConfig            = 0x600
    case setFmdConfig            = 0x601
}
