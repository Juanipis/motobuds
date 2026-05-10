import XCTest
@testable import MotoBudsApp

final class PacketTests: XCTestCase {

    func testEncodeSetANCAnc() {
        // ANC = .anc → opcode 0x201, payload [01, 03] (category 1 = ANC, sub 3 = high).
        // Wire: opcode BE | type | result | len LE | seq LE | payload
        //       02 01    | 80   | 00     | 02 00  | 07 00  | 01 03
        let pkt = Commands.setANC(.anc, seq: 7)
        XCTAssertEqual(pkt.opcode, Opcode.setANCMode.rawValue)
        XCTAssertEqual(pkt.encode(),
                       Data([0x02, 0x01, 0x80, 0x00, 0x02, 0x00, 0x07, 0x00, 0x01, 0x03]))
    }

    func testEncodeSetANCOff() {
        let pkt = Commands.setANC(.off, seq: 1)
        XCTAssertEqual(pkt.encode(),
                       Data([0x02, 0x01, 0x80, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00, 0x00]))
    }

    func testEncodeSetANCTransparency() {
        let pkt = Commands.setANC(.transparency, seq: 1)
        XCTAssertEqual(pkt.encode(),
                       Data([0x02, 0x01, 0x80, 0x00, 0x02, 0x00, 0x01, 0x00, 0x02, 0x00]))
    }

    func testEncodeSetANCAdaptive() {
        let pkt = Commands.setANC(.adaptive, seq: 1)
        XCTAssertEqual(pkt.encode(),
                       Data([0x02, 0x01, 0x80, 0x00, 0x02, 0x00, 0x01, 0x00, 0x01, 0x01]))
    }

    func testEncodeGetBattery() {
        let pkt = Commands.getBattery(seq: 1)
        XCTAssertEqual(pkt.encode(),
                       Data([0x00, 0x05, 0x80, 0x00, 0x00, 0x00, 0x01, 0x00]))
    }

    func testEncodeFindBudsLeft() {
        // Official path: setToggleConfig (0x102) feature 7 = [07, L, R].
        let pkt = Commands.findBuds(side: .left, seq: 1)
        XCTAssertEqual(pkt.opcode, Opcode.setToggleConfig.rawValue)
        XCTAssertEqual(pkt.payload, Data([0x07, 0x01, 0x00]))
    }

    func testEncodeFindBudsRight() {
        let pkt = Commands.findBuds(side: .right, seq: 1)
        XCTAssertEqual(pkt.opcode, Opcode.setToggleConfig.rawValue)
        XCTAssertEqual(pkt.payload, Data([0x07, 0x00, 0x01]))
    }

    func testEncodeStopFindBuds() {
        let pkt = Commands.stopFindBuds(seq: 1)
        XCTAssertEqual(pkt.opcode, Opcode.setToggleConfig.rawValue)
        XCTAssertEqual(pkt.payload, Data([0x07, 0x00, 0x00]))
    }

    func testEncodeSetDualConnection() {
        let on = Commands.setDualConnection(true, seq: 1)
        XCTAssertEqual(on.payload, Data([0x01, 0x01]))
        let off = Commands.setDualConnection(false, seq: 1)
        XCTAssertEqual(off.payload, Data([0x01, 0x00]))
    }

    func testRoundTrip() {
        let p = Packet(opcode: 0x405, type: .commandAck, result: 0, seq: 0x1234,
                       payload: Data([0x00, 0x01]))
        let decoded = Packet.decode(p.encode())
        XCTAssertEqual(decoded?.opcode, 0x405)
        XCTAssertEqual(decoded?.seq, 0x1234)
        XCTAssertEqual(decoded?.payload, Data([0x00, 0x01]))
    }

    func testDecodeBatteryNotification() {
        // What the buds emit on battery change: [L%, R%, case%].
        let raw = Data([0x00, 0x09, 0x40, 0x00, 0x03, 0x00, 0x01, 0x00, 0x56, 0x57, 0x51])
        let pkt = Packet.decode(raw)
        XCTAssertEqual(pkt?.opcode, Opcode.batteryLevelChanged.rawValue)
        XCTAssertEqual(pkt?.type, .notificationNoAck)
        XCTAssertEqual(pkt?.payload, Data([0x56, 0x57, 0x51]))
    }
}
