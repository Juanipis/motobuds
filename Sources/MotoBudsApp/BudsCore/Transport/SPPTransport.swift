import Foundation
import IOBluetooth

/// SPP (Bluetooth Classic RFCOMM) transport for the Moto Buds.
///
/// Wire format: every PDU is wrapped as
///
///     "HEAD" (4) | outer_len (2 LE) | inner PDU (8 + payload) | CRC32 (4 LE) | "TAIL" (4)
///
/// `outer_len = 8 + payload.count`. CRC32 (java.util.zip.CRC32, poly
/// 0xEDB88320) is computed over `[HEAD .. end of inner PDU]`. Reception is
/// stream-oriented — the buds may concatenate multiple frames in a single
/// RFCOMM read; we scan for HEAD/TAIL boundaries.
public actor SPPTransport: Transport {
    public struct Config: Sendable {
        public let mac: String
        public let channel: BluetoothRFCOMMChannelID
        public init(mac: String, channel: BluetoothRFCOMMChannelID = 16) {
            self.mac = mac; self.channel = channel
        }
    }

    public private(set) var isConnected: Bool = false
    private let config: Config
    private var bridge: SPPBridge?
    private var continuation: AsyncStream<Data>.Continuation?
    private var stream: AsyncStream<Data>?
    private var rxBuffer = Data()

    public init(config: Config) {
        self.config = config
    }

    public func connect() async throws {
        guard !isConnected else { return }
        let mac = config.mac
        // Try the configured channel first, then fall back to the other
        // vendor SPP channels the buds expose. macOS occasionally keeps a
        // stale lock on one channel after a crash; the other usually opens.
        let channels: [BluetoothRFCOMMChannelID] =
            [config.channel] + [16, 20, 17].filter { $0 != config.channel }

        var lastCode: Int32 = -1
        for channel in channels {
            // IOBluetooth requires its synchronous calls to run on the main
            // thread; off-main calls return kIOReturnError even though
            // bluetoothd completes the connection 80 ms later. We hop to
            // MainActor and hand back a Sendable bridge.
            let result: (SPPBridge?, Int32) = await MainActor.run {
                let b = SPPBridge(mac: mac, channel: channel) { [weak self] data in
                    Task { await self?.ingest(data) }
                }
                let code = b.open()
                if code == 0 { return (b, 0) }
                b.close()
                return (nil, code)
            }
            if let bridge = result.0 {
                self.bridge = bridge
                self.isConnected = true
                return
            }
            lastCode = result.1
        }
        throw TransportError.channelOpenFailed(code: lastCode)
    }

    public func disconnect() async {
        let b = bridge
        bridge = nil
        isConnected = false
        rxBuffer.removeAll()
        continuation?.finish(); continuation = nil
        stream = nil
        await MainActor.run { b?.close() }
    }

    /// Send takes the *inner* 8-byte-header PDU bytes (i.e. the output of
    /// `Packet.encode()`), wraps them in the SPP frame and writes.
    public func send(_ packet: Data) async throws {
        guard let bridge, isConnected else { throw TransportError.notConnected }
        let framed = SPPFraming.wrap(innerPDU: packet)
        let code = await MainActor.run { bridge.write(framed) }
        guard code == 0 else { throw TransportError.writeFailed(code: code) }
    }

    public func incomingPackets() -> AsyncStream<Data> {
        if let s = stream { return s }
        let s = AsyncStream<Data> { cont in self.continuation = cont }
        self.stream = s
        return s
    }

    /// Buffer raw RFCOMM bytes, then yield each complete inner PDU we extract.
    private func ingest(_ chunk: Data) {
        rxBuffer.append(chunk)
        while let inner = SPPFraming.takeFrame(from: &rxBuffer) {
            continuation?.yield(inner)
        }
    }
}

// MARK: - Framing

enum SPPFraming {
    static let head: [UInt8] = [0x48, 0x45, 0x41, 0x44]
    static let tail: [UInt8] = [0x54, 0x41, 0x49, 0x4C]

    /// Wraps an inner PDU (`Packet.encode()` output) in the SPP envelope.
    static func wrap(innerPDU inner: Data) -> Data {
        var data = Data()
        data.append(contentsOf: head)
        let outer = UInt16(inner.count)
        data.append(UInt8(outer & 0xff))
        data.append(UInt8((outer >> 8) & 0xff))
        data.append(inner)
        let crc = crc32(data)
        data.append(UInt8(crc & 0xff))
        data.append(UInt8((crc >> 8) & 0xff))
        data.append(UInt8((crc >> 16) & 0xff))
        data.append(UInt8((crc >> 24) & 0xff))
        data.append(contentsOf: tail)
        return data
    }

    /// Extracts the next complete inner PDU from a streaming buffer. Removes
    /// the consumed bytes from the buffer. Returns nil if no full frame yet.
    static func takeFrame(from buffer: inout Data) -> Data? {
        // Find HEAD
        guard let headStart = indexOf(needle: head, in: buffer) else { return nil }
        // Need at least HEAD(4) + outer_len(2) to know inner length.
        guard buffer.count >= headStart + 6 else { return nil }
        let lenLo = buffer[headStart + 4]
        let lenHi = buffer[headStart + 5]
        let inner = Int(lenLo) | (Int(lenHi) << 8)
        let frameTotal = 4 /*HEAD*/ + 2 /*len*/ + inner + 4 /*CRC*/ + 4 /*TAIL*/
        guard buffer.count >= headStart + frameTotal else { return nil }

        let innerStart = headStart + 6
        let innerEnd   = innerStart + inner
        let tailStart  = innerEnd + 4
        // Sanity: TAIL marker present
        if buffer.subdata(in: tailStart..<tailStart + 4) != Data(tail) {
            // misframed — drop the HEAD byte and retry
            buffer.removeSubrange(headStart..<headStart + 1)
            return takeFrame(from: &buffer)
        }
        let innerPDU = buffer.subdata(in: innerStart..<innerEnd)
        // Drop any garbage before HEAD plus the consumed frame
        buffer.removeSubrange(buffer.startIndex..<(headStart + frameTotal))
        return innerPDU
    }

    private static func indexOf(needle: [UInt8], in data: Data) -> Int? {
        guard data.count >= needle.count else { return nil }
        outer: for i in 0...(data.count - needle.count) {
            for j in 0..<needle.count where data[data.startIndex + i + j] != needle[j] {
                continue outer
            }
            return i
        }
        return nil
    }

    /// Standard CRC32 (poly 0xEDB88320) — matches `java.util.zip.CRC32`.
    static func crc32(_ data: Data) -> UInt32 {
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
}

// MARK: - IOBluetooth bridge

final class SPPBridge: NSObject, IOBluetoothRFCOMMChannelDelegate, @unchecked Sendable {
    typealias OnData = @Sendable (Data) -> Void

    private let mac: String
    private let channelID: BluetoothRFCOMMChannelID
    private let onData: OnData
    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?

    init(mac: String, channel: BluetoothRFCOMMChannelID, onData: @escaping OnData) {
        self.mac = mac; self.channelID = channel; self.onData = onData
    }

    func open() -> Int32 {
        guard let dev = IOBluetoothDevice(addressString: mac) else { return -1 }
        device = dev
        if !dev.isConnected() { _ = dev.openConnection() }
        var c: IOBluetoothRFCOMMChannel?
        let r = dev.openRFCOMMChannelSync(&c, withChannelID: channelID, delegate: self)
        guard r == kIOReturnSuccess, let c else { return Int32(r) }
        channel = c
        return 0
    }

    func close() {
        channel?.close(); channel = nil
        device?.closeConnection(); device = nil
    }

    func write(_ data: Data) -> Int32 {
        guard let channel else { return -1 }
        var bytes = [UInt8](data)
        let r = bytes.withUnsafeMutableBufferPointer { buf -> IOReturn in
            channel.writeSync(buf.baseAddress, length: UInt16(buf.count))
        }
        return Int32(r)
    }

    // Delegate
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let buf = UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength)
        onData(Data(buf))
    }
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {}
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelControlSignalsChanged(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelFlowControlChanged(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {}
    func rfcommChannelQueueSpaceAvailable(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
}
