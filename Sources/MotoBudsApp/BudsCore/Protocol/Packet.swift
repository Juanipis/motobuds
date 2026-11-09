import Foundation

/// Wire format for the Moto Buds GATT control protocol, extracted from the
/// official Moto Buds Android app (`com.motorola.motobuds` 01.0.129.12).
/// See `docs/protocol.md` for the full reverse-engineering notes.
///
/// Header is exactly 8 bytes; payload is opcode-specific:
///
///     offset  size  field          encoding
///        0     2    opcode         big-endian u16
///        2     1    type           u8 (0x80 = command-ack — what we send)
///        3     1    result         u8 (0 for outgoing commands)
///        4     2    inner_length   little-endian u16 (= payload.count)
///        6     2    seq            little-endian u16
///        8     N    payload        raw bytes
public struct Packet: Equatable, Sendable {

    public enum PacketType: UInt8, Sendable {
        case commandNoAck      = 0x00
        case responseNoAck     = 0x20
        case notificationNoAck = 0x40
        case commandAck        = 0x80
        case responseAck       = 0xA0
        case notificationAck   = 0xC0
    }

    public let opcode: UInt16
    public let type: PacketType
    public let result: UInt8
    public let seq: UInt16
    public let payload: Data

    public init(opcode: UInt16, type: PacketType = .commandAck, result: UInt8 = 0, seq: UInt16 = 0, payload: Data = Data()) {
        self.opcode = opcode
        self.type = type
        self.result = result
        self.seq = seq
        self.payload = payload
    }

    public func encode() -> Data {
        var data = Data(capacity: 8 + payload.count)
        // opcode big-endian
        data.append(UInt8((opcode >> 8) & 0xff))
        data.append(UInt8(opcode & 0xff))
        // type, result
        data.append(type.rawValue)
        data.append(result)
        // length little-endian (payload only)
        let len = UInt16(payload.count)
        data.append(UInt8(len & 0xff))
        data.append(UInt8((len >> 8) & 0xff))
        // seq little-endian
        data.append(UInt8(seq & 0xff))
        data.append(UInt8((seq >> 8) & 0xff))
        // payload
        data.append(payload)
        return data
    }

    public static func decode(_ data: Data) -> Packet? {
        guard data.count >= 8 else { return nil }
        let i = data.startIndex
        let opcode = (UInt16(data[i]) << 8) | UInt16(data[i + 1])
        guard let type = PacketType(rawValue: data[i + 2]) else { return nil }
        let result = data[i + 3]
        let len = UInt16(data[i + 4]) | (UInt16(data[i + 5]) << 8)
        let seq = UInt16(data[i + 6]) | (UInt16(data[i + 7]) << 8)
        guard data.count >= 8 + Int(len) else { return nil }
        let payload = data.subdata(in: (i + 8)..<(i + 8 + Int(len)))
        return Packet(opcode: opcode, type: type, result: result, seq: seq, payload: payload)
    }
}
