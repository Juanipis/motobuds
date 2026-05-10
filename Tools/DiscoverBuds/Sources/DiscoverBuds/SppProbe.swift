import Foundation
import IOBluetooth

/// Builds a Moto Buds SPP frame matching `T0/RunnableC1833w` case 4 in the APK.
///   "HEAD" (4) | outer_len (2 LE) | opcode (2 BE) | type (1) | result (1)
///   | inner_len (2 LE) | seq (2 LE) | payload (N) | CRC32 (4 LE) | "TAIL" (4)
func buildSppFrame(opcode: UInt16, type: UInt8 = 0x80, result: UInt8 = 0,
                   seq: UInt16 = 0, payload: Data = Data()) -> Data {
    var inner = Data()
    inner.append(UInt8((opcode >> 8) & 0xff))
    inner.append(UInt8(opcode & 0xff))
    inner.append(type)
    inner.append(result)
    inner.append(UInt8(payload.count & 0xff))
    inner.append(UInt8((payload.count >> 8) & 0xff))
    inner.append(UInt8(seq & 0xff))
    inner.append(UInt8((seq >> 8) & 0xff))
    inner.append(payload)

    let outerLen = UInt16(inner.count)
    var head = Data()
    head.append(contentsOf: [0x48, 0x45, 0x41, 0x44])
    head.append(UInt8(outerLen & 0xff))
    head.append(UInt8((outerLen >> 8) & 0xff))
    head.append(inner)

    let crc = crc32(head)
    var frame = head
    frame.append(UInt8(crc & 0xff))
    frame.append(UInt8((crc >> 8) & 0xff))
    frame.append(UInt8((crc >> 16) & 0xff))
    frame.append(UInt8((crc >> 24) & 0xff))
    frame.append(contentsOf: [0x54, 0x41, 0x49, 0x4C])
    return frame
}

func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFFFFFF
    for b in data {
        crc ^= UInt32(b)
        for _ in 0..<8 {
            if (crc & 1) != 0 { crc = (crc >> 1) ^ 0xEDB88320 }
            else              { crc >>= 1 }
        }
    }
    return crc ^ 0xFFFFFFFF
}

func parseHex(_ s: String) -> Data {
    let cleaned = s.replacingOccurrences(of: " ", with: "")
                   .replacingOccurrences(of: ":", with: "")
                   .replacingOccurrences(of: ",", with: "")
    var data = Data()
    var i = cleaned.startIndex
    while i < cleaned.endIndex {
        let next = cleaned.index(i, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
        if let b = UInt8(cleaned[i..<next], radix: 16) { data.append(b) }
        i = next
    }
    return data
}

func extractFrames(from buf: inout Data) -> [(opcode: UInt16, type: UInt8, result: UInt8, seq: UInt16, payload: Data)] {
    var out: [(opcode: UInt16, type: UInt8, result: UInt8, seq: UInt16, payload: Data)] = []
    while true {
        // Find HEAD
        guard let h = indexOf([0x48, 0x45, 0x41, 0x44], in: buf) else { return out }
        guard buf.count >= h + 6 else { return out }
        let lenLo = buf[h + 4], lenHi = buf[h + 5]
        let inner = Int(lenLo) | (Int(lenHi) << 8)
        let frameTotal = 4 + 2 + inner + 4 + 4
        guard buf.count >= h + frameTotal else { return out }
        let innerStart = h + 6
        let opcode = (UInt16(buf[innerStart]) << 8) | UInt16(buf[innerStart + 1])
        let type = buf[innerStart + 2]
        let result = buf[innerStart + 3]
        let payloadLen = Int(buf[innerStart + 4]) | (Int(buf[innerStart + 5]) << 8)
        let seq = UInt16(buf[innerStart + 6]) | (UInt16(buf[innerStart + 7]) << 8)
        let payload = buf.subdata(in: (innerStart + 8)..<(innerStart + 8 + payloadLen))
        out.append((opcode, type, result, seq, payload))
        buf.removeSubrange(buf.startIndex..<(h + frameTotal))
    }
}

private func indexOf(_ needle: [UInt8], in data: Data) -> Int? {
    guard data.count >= needle.count else { return nil }
    outer: for i in 0...(data.count - needle.count) {
        for j in 0..<needle.count where data[data.startIndex + i + j] != needle[j] {
            continue outer
        }
        return i
    }
    return nil
}

/// One step of a script: send a command and label what's expected.
struct ProbeStep {
    let label: String
    let opcode: UInt16
    let payload: Data
    /// Seconds to wait after sending before next step. Default 1.5s.
    let waitAfter: TimeInterval

    init(_ label: String, _ opcode: UInt16, _ payloadHex: String = "", waitAfter: TimeInterval = 1.5) {
        self.label = label
        self.opcode = opcode
        self.payload = parseHex(payloadHex)
        self.waitAfter = waitAfter
    }
}

final class SppProbe: NSObject, IOBluetoothRFCOMMChannelDelegate {
    let mac: String
    let channel: BluetoothRFCOMMChannelID
    let steps: [ProbeStep]
    var done = false
    var ch: IOBluetoothRFCOMMChannel?
    var rxBuf = Data()
    var seq: UInt16 = 0
    let rxLock = NSLock()

    init(mac: String, channel: BluetoothRFCOMMChannelID, steps: [ProbeStep]) {
        self.mac = mac; self.channel = channel; self.steps = steps
    }

    func run() {
        head("SPP probe — mac=\(mac) ch=\(channel) steps=\(steps.count)")
        guard let dev = IOBluetoothDevice(addressString: mac) else {
            line("invalid MAC"); done = true; return
        }
        line("device: \(dev.name ?? "?") connected=\(dev.isConnected())")
        if !dev.isConnected() { _ = dev.openConnection() }

        var c: IOBluetoothRFCOMMChannel?
        let r = dev.openRFCOMMChannelSync(&c, withChannelID: channel, delegate: self)
        guard r == kIOReturnSuccess, let c else {
            line("openRFCOMMChannelSync failed: \(String(format:"0x%x", r))")
            done = true; return
        }
        ch = c
        line("✓ channel opened")

        // Run script on a background thread so we can sleep between steps,
        // while the main runloop processes IOBluetooth callbacks.
        Thread.detachNewThread { [weak self] in
            guard let self else { return }
            // Initial settle. The buds dump a substantial init burst (profile
            // version + support features + configs + several state notifs)
            // when the SPP channel opens; if we send commands during that
            // burst, the responses end up arriving out of order and are hard
            // to correlate. 4s is enough to drain it.
            Thread.sleep(forTimeInterval: 4.0)
            line("--- init burst ---")
            self.flushPending(prefix: "  ")
            line("--- script begins ---")

            for (i, step) in self.steps.enumerated() {
                self.seq &+= 1
                let frame = buildSppFrame(opcode: step.opcode, type: 0x80, seq: self.seq,
                                          payload: step.payload)
                let payHex = step.payload.map { String(format: "%02x", $0) }.joined(separator: " ")
                line("")
                line(String(format: "[%02d] %@", i + 1, step.label))
                line(String(format: "  → tx op=0x%03x seq=%d payload=[%@]",
                            step.opcode, self.seq, payHex.isEmpty ? "—" : payHex))
                var bytes = [UInt8](frame)
                let wr = bytes.withUnsafeMutableBufferPointer { buf -> IOReturn in
                    c.writeSync(buf.baseAddress, length: UInt16(buf.count))
                }
                if wr != kIOReturnSuccess {
                    line(String(format: "  writeSync failed: 0x%x", wr))
                }
                Thread.sleep(forTimeInterval: step.waitAfter)
                self.flushPending()
            }
            line("")
            line("--- script done ---")
            self.done = true
            DispatchQueue.main.async { c.close() }
        }
    }

    func flushPending(prefix: String = "  ") {
        rxLock.lock()
        let frames = extractFrames(from: &rxBuf)
        rxLock.unlock()
        if frames.isEmpty { return }
        for f in frames {
            let pay = f.payload.map { String(format: "%02x", $0) }.joined(separator: " ")
            let typeName: String = {
                switch f.type {
                case 0x00: return "cmd"
                case 0x20: return "rsp"
                case 0x40: return "notif"
                case 0x80: return "cmd-ack"
                case 0xA0: return "rsp-ack"
                case 0xC0: return "notif-ack"
                default:   return String(format: "?0x%02x", f.type)
                }
            }()
            line(String(format: "%@← op=0x%03x %@ seq=%d res=%d payload=[%@]",
                        prefix, f.opcode, typeName, f.seq, f.result, pay))
        }
    }

    // Delegate
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let buf = UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength)
        let chunk = Data(buf)
        rxLock.lock()
        rxBuf.append(chunk)
        rxLock.unlock()
        // Also dump raw incoming bytes to aid debugging.
        let hex = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
        line("    [raw rx \(dataLength)B] \(hex)")
    }
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {}
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        line("rfcommChannelClosed by peer")
        done = true
    }
    func rfcommChannelControlSignalsChanged(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelFlowControlChanged(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {}
    func rfcommChannelQueueSpaceAvailable(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
}
