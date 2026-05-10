import Foundation
import Observation

/// Estado vivo de los buds expuesto a SwiftUI vía `@Observable`.
/// Orquesta el `Transport`, serializa comandos y mantiene `BudsState`.
@Observable
@MainActor
public final class BudsManager {
    public private(set) var state = BudsState()
    public var debugLog: [String] = []

    /// `true` si el transporte real está cableado.
    public let usingMockTransport: Bool

    private let transport: any Transport
    private var sendSeq: UInt16 = 0
    private var listenerTask: Task<Void, Never>?
    private var batteryTickTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    public init(transport: any Transport, usingMock: Bool) {
        self.transport = transport
        self.usingMockTransport = usingMock
        if usingMock { applyMockInitialState() }
    }

    public static func mock() -> BudsManager {
        BudsManager(transport: MockTransport(), usingMock: true)
    }

    public func connect() { Task { await self.connectAsync() } }
    public func disconnect() { Task { await self.disconnectAsync() } }

    private func connectAsync() async {
        guard state.connection != .connected else { return }
        state.connection = .connecting
        log("Conectando…")
        do {
            try await transport.connect()
            state.connection = .connected
            log("Conectado.")
            startListening()
            if usingMockTransport {
                startMockBatteryTick()
            } else {
                // Buds dump ~5 init frames over the first ~3 seconds:
                // profile version, support features, configs, toggle configs,
                // hardware info, plus battery + in-ear notifications. Wait
                // for that to drain before proactively querying state.
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                _ = try? await sendCommand(Commands.getBattery(seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = try? await sendCommand(Packet(opcode: Opcode.getToggleConfigs.rawValue, seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = try? await sendCommand(Packet(opcode: Opcode.getDualConnection.rawValue, seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = try? await sendCommand(Packet(opcode: Opcode.getHiResMode.rawValue, seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = try? await sendCommand(Packet(opcode: Opcode.getGameMode.rawValue, seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = try? await sendCommand(Packet(opcode: Opcode.getBassEnhancement.rawValue, seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = try? await sendCommand(Packet(opcode: Opcode.getVolumeBoost.rawValue, seq: nextSeq()))
                startPeriodicRefresh()
            }
        } catch {
            state.connection = .disconnected
            log("Falló conexión: \(error)")
        }
    }

    /// Re-poll battery every 60s and the toggles every 5 minutes. Notifications
    /// usually keep state fresh, but a periodic refresh is a cheap safety net.
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let self else { return }
                _ = try? await self.sendCommand(Commands.getBattery(seq: self.nextSeq()))
                ticks += 1
                if ticks % 5 == 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    _ = try? await self.sendCommand(Packet(opcode: Opcode.getANCMode.rawValue, seq: self.nextSeq()))
                }
            }
        }
    }

    private func disconnectAsync() async {
        listenerTask?.cancel(); listenerTask = nil
        batteryTickTask?.cancel(); batteryTickTask = nil
        refreshTask?.cancel(); refreshTask = nil
        await transport.disconnect()
        state.connection = .disconnected
        log("Desconectado.")
    }

    // MARK: - Public commands

    public func setANC(_ mode: ANCMode) {
        state.ancMode = mode
        log("ANC → \(mode.displayName)")
        if !usingMockTransport {
            // 1) `setANCMode` (0x201) with [category, sub] is what fires the
            //    audible mode switch. Same payload as the bud's touch-button.
            // 2) `setToggleConfig` (0x102) persists the user preference so the
            //    bud retains the mode across reconnects.
            Task {
                _ = try? await sendCommand(Commands.setANC(mode, seq: nextSeq()))
                try? await Task.sleep(nanoseconds: 80_000_000)
                _ = try? await sendCommand(Commands.saveANCPreference(mode, seq: nextSeq()))
            }
        }
    }

    public func findBuds(side: BudSide) {
        log("Sonando bud \(side.displayName)…")
        state.findBuds = side == .left ? .findingLeft : .findingRight
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.findBuds(side: side, seq: nextSeq())) }
        }
    }

    public func stopFindBuds() {
        log("Detener sonido de buds")
        state.findBuds = .idle
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.stopFindBuds(seq: nextSeq())) }
        }
    }

    public func setDualConnect(_ on: Bool) {
        state.dualConnect = on
        log("Dual connect: \(on ? "ON" : "OFF")")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setDualConnection(on, seq: nextSeq())) }
        }
    }

    public func setBassEnhancement(_ on: Bool) {
        state.toggles.bassEnhancement = on
        log("Bass: \(on)")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setBassEnhancement(on, seq: nextSeq())) }
        }
    }

    public func setVolumeBoost(_ on: Bool) {
        state.toggles.volumeBoost = on
        log("Volume boost: \(on)")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setVolumeBoost(on, seq: nextSeq())) }
        }
    }

    public func setHiRes(_ on: Bool) {
        state.toggles.hiRes = on
        log("Hi-res: \(on)")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setHiRes(on, seq: nextSeq())) }
        }
    }

    public func setGameMode(_ on: Bool) {
        state.toggles.gameMode = on
        log("Game mode: \(on)")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setGameMode(on, seq: nextSeq())) }
        }
    }

    public func setInEarDetection(_ on: Bool) {
        state.toggles.inEarDetection = on
        log("In-ear: \(on)")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setInEarDetection(on, seq: nextSeq())) }
        }
    }

    public func setAdaptiveHearing(_ on: Bool) {
        state.toggles.adaptiveHearing = on
        log("Adaptive hearing: \(on)")
        if !usingMockTransport {
            Task { _ = try? await sendCommand(Commands.setAdaptiveHearing(on, seq: nextSeq())) }
        }
    }

    // MARK: - Internals

    private func nextSeq() -> UInt16 {
        sendSeq &+= 1
        return sendSeq
    }

    private func sendCommand(_ packet: Packet) async throws {
        let bytes = packet.encode()
        try await transport.send(bytes)
        log(String(format: "→ tx %dB op=0x%03x seq=%d", bytes.count, packet.opcode, packet.seq))
    }

    private func startListening() {
        listenerTask?.cancel()
        let t = transport
        listenerTask = Task { [weak self] in
            let s = await t.incomingPackets()
            for await chunk in s {
                guard let self else { break }
                self.handleIncoming(chunk)
            }
        }
    }

    private func handleIncoming(_ data: Data) {
        log(String(format: "← rx %dB", data.count))
        guard let pkt = Packet.decode(data) else {
            log("  (could not decode)")
            return
        }
        let payloadHex = pkt.payload.map { String(format: "%02x", $0) }.joined(separator: " ")
        log(String(format: "  op=0x%03x type=0x%02x len=%d payload=[%@]",
                   pkt.opcode, pkt.type.rawValue, pkt.payload.count, payloadHex))

        switch pkt.opcode {
        case Opcode.batteryLevelChanged.rawValue, Opcode.getBatteryLevel.rawValue:
            // Verified empirically: payload = [left%, right%, case%]. 0xFF = unknown.
            if pkt.payload.count >= 3 {
                state.batteryLeft  = pkt.payload[0] == 0xFF ? nil : Int(pkt.payload[0])
                state.batteryRight = pkt.payload[1] == 0xFF ? nil : Int(pkt.payload[1])
                state.batteryCase  = pkt.payload[2] == 0xFF ? nil : Int(pkt.payload[2])
            }
        case Opcode.toggleConfigChanged.rawValue:
            // Notification when a toggle config changed (after we set one).
            // Payload format: [feature_id, category, sub]. Feature 1 = ANC.
            if pkt.payload.count >= 3, pkt.payload[0] == 0x01 {
                state.ancMode = decodeANC(category: pkt.payload[1], sub: pkt.payload[2])
            }
        case Opcode.getToggleConfigs.rawValue:
            // List response with all toggle configs. Walks entries of form
            // [feature_id, category, sub] (3 bytes each) — verified
            // empirically with our buds. The first byte is a count.
            if let count = pkt.payload.first, pkt.payload.count >= 1 + Int(count) * 3 {
                var i = 1
                for _ in 0..<Int(count) {
                    if i + 2 < pkt.payload.count, pkt.payload[i] == 0x01 {
                        state.ancMode = decodeANC(category: pkt.payload[i + 1],
                                                  sub: pkt.payload[i + 2])
                    }
                    i += 3
                }
            }
        case Opcode.ancModeChanged.rawValue, Opcode.getANCMode.rawValue:
            // Verified empirically (and matches what the touch button emits):
            // payload = [category, sub] using the same mapping as toggle config.
            // Authoritative — fires both when the user touches the bud and
            // when we send setANCMode.
            if pkt.payload.count >= 2 {
                state.ancMode = decodeANC(category: pkt.payload[0], sub: pkt.payload[1])
            }
        case Opcode.inEarStatusChanged.rawValue, Opcode.inEarDetectionNotif.rawValue,
             Opcode.getInEarDetection.rawValue:
            if pkt.payload.count >= 2 {
                state.live.leftInEar  = pkt.payload[0] != 0
                state.live.rightInEar = pkt.payload[1] != 0
            }
        case Opcode.inCaseStatusIndication.rawValue:
            if pkt.payload.count >= 2 {
                state.live.leftInCase  = pkt.payload[0] != 0
                state.live.rightInCase = pkt.payload[1] != 0
            }
        case Opcode.fitStatusChanged.rawValue:
            if pkt.payload.count >= 2 {
                state.live.leftFit  = Int(pkt.payload[0])
                state.live.rightFit = Int(pkt.payload[1])
            }
        case Opcode.findMyDeviceNotif.rawValue:
            // Payload = [side, on/off]. side: 0=L, 1=R, 2=both.
            if pkt.payload.count >= 2 {
                let active = pkt.payload[1] != 0
                let side = pkt.payload[0]
                if active {
                    state.findBuds = side == 0 ? .findingLeft
                                   : side == 1 ? .findingRight : .findingBoth
                } else {
                    state.findBuds = .idle
                }
            }
        case Opcode.getDualConnection.rawValue, Opcode.dualConnectionChanged.rawValue:
            // Payload = [feature_enabled, current_state]. We only care about [1].
            if pkt.payload.count >= 2 {
                state.dualConnect = pkt.payload[1] != 0
            }
        case Opcode.getHiResMode.rawValue, Opcode.hiResStateChanged.rawValue:
            // get response: [state]. notif: [old, new] (use [new]).
            if pkt.type == .responseNoAck, let b = pkt.payload.first {
                state.toggles.hiRes = b != 0
            } else if pkt.payload.count >= 2 {
                state.toggles.hiRes = pkt.payload[1] != 0
            }
        case Opcode.getGameMode.rawValue, Opcode.gameModeStateChanged.rawValue:
            if pkt.type == .responseNoAck, let b = pkt.payload.first {
                state.toggles.gameMode = b != 0
            } else if pkt.payload.count >= 2 {
                state.toggles.gameMode = pkt.payload[1] != 0
            }
        case Opcode.getBassEnhancement.rawValue, Opcode.bassEnhancementChanged.rawValue:
            if pkt.type == .responseNoAck, let b = pkt.payload.first {
                state.toggles.bassEnhancement = b != 0
            } else if pkt.payload.count >= 2 {
                state.toggles.bassEnhancement = pkt.payload[1] != 0
            }
        case Opcode.getVolumeBoost.rawValue, Opcode.volumeBoostChanged.rawValue:
            if pkt.type == .responseNoAck, let b = pkt.payload.first {
                state.toggles.volumeBoost = b != 0
            } else if pkt.payload.count >= 2 {
                state.toggles.volumeBoost = pkt.payload[1] != 0
            }
        case Opcode.getHardwareInfo.rawValue:
            // Verified: payload contains device name (30 padded bytes) +
            // 3x serial number (20 padded bytes) + SKU (7 bytes).
            if pkt.payload.count >= 30 {
                let nameBytes = pkt.payload.prefix(30).split(separator: 0).first ?? []
                if !nameBytes.isEmpty,
                   let name = String(bytes: nameBytes, encoding: .utf8)?
                       .trimmingCharacters(in: .whitespaces),
                   !name.isEmpty {
                    state.deviceName = name
                }
            }
        default: break
        }
    }

    private func log(_ s: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(ts.suffix(8))] \(s)"
        debugLog.append(entry)
        if debugLog.count > 200 { debugLog.removeFirst(debugLog.count - 200) }
        // Side-channel: also append to a tail-able file. Useful for
        // diagnosing connection issues from the terminal.
        let path = NSHomeDirectory() + "/Library/Logs/MotoBudsMac.log"
        if let data = (entry + "\n").data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: path) {
                _ = try? fh.seekToEnd(); try? fh.write(contentsOf: data); try? fh.close()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }

    /// Public hook so the diagnostic scanner can append entries.
    public func appendDebug(_ s: String) { log(s) }

    // MARK: - Mock simulation

    private func applyMockInitialState() {
        state.deviceName = "Moto Buds (Mock)"
        state.deviceMAC = "a4:05:6e:d9:c9:14"
        state.batteryLeft = 84
        state.batteryRight = 78
        state.batteryCase = 62
        state.firmware = FirmwareInfo(leftBud: "1.4.2", rightBud: "1.4.2", caseFW: "1.4.0")
    }

    private func startMockBatteryTick() {
        batteryTickTask?.cancel()
        batteryTickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await MainActor.run {
                    guard let self else { return }
                    if let l = self.state.batteryLeft, l > 0 { self.state.batteryLeft = l - 1 }
                    if let r = self.state.batteryRight, r > 0 { self.state.batteryRight = r - 1 }
                }
            }
        }
    }
}

/// Decode the (category, sub) pair used everywhere: `setANCMode` (0x201),
/// `ancModeChanged` (0x204) notif, `setToggleConfig` (0x102) feature 1, and
/// `toggleConfigChanged` (0x105) notif feature 1.
///
/// category 0 = off; 1 = ANC; 2 = transparency. Sub is strength when
/// category == 1: 1 = light (treated as adaptive in the UI), 2 or 3 = full ANC.
private func decodeANC(category: UInt8, sub: UInt8) -> ANCMode {
    switch category {
    case 0: return .off
    case 1: return sub == 1 ? .adaptive : .anc
    case 2: return .transparency
    default: return .off
    }
}
