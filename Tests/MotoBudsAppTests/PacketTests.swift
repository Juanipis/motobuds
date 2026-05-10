import XCTest
@testable import MotoBudsMac

final class PacketTests: XCTestCase {
    func testEncodeSetANC() {
        // ANC=on (byte 2). Expected wire (8 byte header + 1 byte payload):
        //   opcode 0x0201 BE → 02 01
        //   type 0x80, result 0x00
        //   length 1 (LE) → 01 00
        //   seq 0x0007 (LE) → 07 00
        //   payload → 02
        let pkt = Commands.setANC(.anc, seq: 7)
        XCTAssertEqual(pkt.opcode, Opcode.setANCMode.rawValue)
        XCTAssertEqual(pkt.encode(),
                       Data([0x02, 0x01, 0x80, 0x00, 0x01, 0x00, 0x07, 0x00, 0x02]))
    }

    func testEncodeGetBattery() {
        let pkt = Commands.getBattery(seq: 1)
        XCTAssertEqual(pkt.encode(),
                       Data([0x00, 0x05, 0x80, 0x00, 0x00, 0x00, 0x01, 0x00]))
    }

    func testRoundTrip() {
        let p = Packet(opcode: 0x405, type: .commandAck, result: 0, seq: 0x1234,
                       payload: Data([0x00, 0x01]))
        let decoded = Packet.decode(p.encode())
        XCTAssertEqual(decoded?.opcode, 0x405)
        XCTAssertEqual(decoded?.seq, 0x1234)
        XCTAssertEqual(decoded?.payload, Data([0x00, 0x01]))
    }
}
