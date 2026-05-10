import Foundation
import IOBluetooth
import CoreBluetooth

// MARK: - argv parsing
//
//   DiscoverBuds                    -> discover (stdout)
//   DiscoverBuds <outfile>          -> discover, dump to file
//   DiscoverBuds discover [outfile] -> same as above
//   DiscoverBuds sniff <mac> <ch> [<seconds>] [<outfile>]
//                                   -> open RFCOMM channel and dump bytes

setbuf(stdout, nil)
setbuf(stderr, nil)

var args = Array(CommandLine.arguments.dropFirst())
var mode: String = "discover"
if let first = args.first, ["discover", "sniff", "probe", "listen"].contains(first) {
    mode = first
    args.removeFirst()
}

// Output file is the LAST arg only when it ends with .txt; otherwise stdout.
var outFilePath: String? = {
    if let last = args.last, last.hasSuffix(".txt") {
        args.removeLast()
        return last
    }
    return nil
}()
let outFileHandle: FileHandle? = {
    guard let p = outFilePath else { return nil }
    FileManager.default.createFile(atPath: p, contents: nil)
    return FileHandle(forWritingAtPath: p)
}()

func line(_ s: String = "") {
    print(s)
    fflush(stdout)
    if let h = outFileHandle, let d = (s + "\n").data(using: .utf8) {
        try? h.write(contentsOf: d)
    }
}
func head(_ s: String) {
    line("")
    line("=== \(s) " + String(repeating: "=", count: max(0, 70 - s.count)))
}
func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined(separator: " ")
}
func ascii(_ data: Data) -> String {
    String(data.map { (32...126).contains($0) ? Character(UnicodeScalar($0)) : "." })
}

FileHandle.standardError.write(
    "DiscoverBuds: mode=\(mode) pid=\(getpid()) out=\(outFilePath ?? "stdout")\n".data(using: .utf8)!
)

// MARK: - Discover mode

func dumpClassic() {
    head("Bluetooth Classic — paired devices (IOBluetooth)")
    guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
        line("(no paired devices array)"); return
    }
    for dev in devices {
        let name = dev.name ?? "(unnamed)"
        let addr = dev.addressString ?? "??"
        let connected = dev.isConnected() ? "connected" : "not connected"
        let cls = String(format: "0x%06x", dev.classOfDevice)
        line("")
        line("• \(name)  [\(addr)]  \(connected)  classOfDevice=\(cls)")
        line("  serviceClassMajor=0x\(String(dev.serviceClassMajor, radix: 16))" +
             " deviceClassMajor=0x\(String(dev.deviceClassMajor, radix: 16))" +
             " deviceClassMinor=0x\(String(dev.deviceClassMinor, radix: 16))")
        guard let services = dev.services as? [IOBluetoothSDPServiceRecord], !services.isEmpty else {
            line("  (no SDP service records cached)"); continue
        }
        line("  SDP records: \(services.count)")
        for (i, rec) in services.enumerated() {
            line("    [\(i)] \(rec.getServiceName() ?? "(unnamed service)")")
            var channelID: BluetoothRFCOMMChannelID = 0
            if rec.getRFCOMMChannelID(&channelID) == kIOReturnSuccess {
                line("        RFCOMM channel: \(channelID)")
            }
            var psm: BluetoothL2CAPPSM = 0
            if rec.getL2CAPPSM(&psm) == kIOReturnSuccess {
                line("        L2CAP PSM: 0x\(String(psm, radix: 16))")
            }
            if let attrs = rec.attributes as? [NSNumber: IOBluetoothSDPDataElement] {
                if let scl = attrs[NSNumber(value: 0x0001)] {
                    line("        ServiceClassIDList: \(scl)")
                }
                if let pdl = attrs[NSNumber(value: 0x0009)] {
                    line("        ProfileDescriptorList: \(pdl)")
                }
            }
        }
    }
}

final class GATTScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var central: CBCentralManager!
    let targetNameSubstrings = ["moto", "buds"]
    var discovered: [CBPeripheral] = []
    var connecting: CBPeripheral?
    var pendingServices = 0
    let scanDuration: TimeInterval = 8.0
    var done = false

    func start() { central = CBCentralManager(delegate: self, queue: nil) }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            line("BLE central: poweredOn — scanning \(Int(scanDuration))s for *moto/buds*…")
            central.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + scanDuration) { [weak self] in
                self?.finishScan()
            }
        default:
            line("BLE central state: \(central.state.rawValue) — aborting LE scan")
            done = true
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = (peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "").lowercased()
        guard !name.isEmpty, targetNameSubstrings.contains(where: { name.contains($0) }) else { return }
        guard !discovered.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        discovered.append(peripheral)
        line("  • adv: name=\"\(peripheral.name ?? "")\" rssi=\(RSSI) id=\(peripheral.identifier)")
        if let svc = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            line("    advertised serviceUUIDs: \(svc.map { $0.uuidString })")
        }
        if let mfg = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            line("    manufacturerData: \(hex(mfg))")
        }
    }
    func finishScan() {
        central.stopScan()
        if discovered.isEmpty { line("(no LE peripherals matched)"); done = true; return }
        connectNext()
    }
    func connectNext() {
        guard let p = discovered.first else { done = true; return }
        discovered.removeFirst()
        connecting = p
        p.delegate = self
        line("→ connecting to \(p.name ?? "?")…")
        central.connect(p, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            guard let self, self.connecting === p else { return }
            line("  (timeout)"); self.central.cancelPeripheralConnection(p); self.connectNext()
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        line("  connected — discovering services…")
        peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        line("  failed: \(error?.localizedDescription ?? "?")"); connectNext()
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { line("  discoverServices: \(error)"); central.cancelPeripheralConnection(peripheral); connectNext(); return }
        let services = peripheral.services ?? []
        line("  services: \(services.count)")
        pendingServices = services.count
        if pendingServices == 0 { central.cancelPeripheralConnection(peripheral); connectNext(); return }
        for s in services {
            line("    service \(s.uuid.uuidString)  primary=\(s.isPrimary)")
            peripheral.discoverCharacteristics(nil, for: s)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        defer {
            pendingServices -= 1
            if pendingServices <= 0 { central.cancelPeripheralConnection(peripheral); connectNext() }
        }
        if let error { line("      err: \(error)"); return }
        for c in service.characteristics ?? [] {
            var props: [String] = []
            let p = c.properties
            if p.contains(.read) { props.append("read") }
            if p.contains(.write) { props.append("write") }
            if p.contains(.writeWithoutResponse) { props.append("writeNoRsp") }
            if p.contains(.notify) { props.append("notify") }
            if p.contains(.indicate) { props.append("indicate") }
            line("      char  \(c.uuid.uuidString)  [\(props.joined(separator: ","))]")
        }
    }
}

// MARK: - Sniff mode (RFCOMM passive listen)

final class RFCOMMSniffer: NSObject, IOBluetoothRFCOMMChannelDelegate {
    let mac: String
    let channel: BluetoothRFCOMMChannelID
    let duration: TimeInterval
    var done = false
    var channelRef: IOBluetoothRFCOMMChannel?
    var byteCount: Int = 0
    var startedAt: Date?

    init(mac: String, channel: BluetoothRFCOMMChannelID, duration: TimeInterval) {
        self.mac = mac; self.channel = channel; self.duration = duration
    }

    func start() {
        head("RFCOMM sniff — mac=\(mac) ch=\(channel) duration=\(Int(duration))s")
        guard let dev = IOBluetoothDevice(addressString: mac) else {
            line("could not parse MAC"); done = true; return
        }
        line("device: \(dev.name ?? "?")  connected=\(dev.isConnected())")
        if !dev.isConnected() {
            line("attempting baseband connect…")
            let r = dev.openConnection()
            line("openConnection -> \(r)")
        }
        var ch: IOBluetoothRFCOMMChannel?
        let result = dev.openRFCOMMChannelSync(&ch, withChannelID: channel, delegate: self)
        if result != kIOReturnSuccess {
            line("openRFCOMMChannelSync failed: \(String(format: "0x%x", result))")
            done = true; return
        }
        channelRef = ch
        startedAt = Date()
        line("✓ RFCOMM channel \(channel) opened. Listening \(Int(duration))s for spontaneous traffic…")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.finish(reason: "timer")
        }
    }

    func finish(reason: String) {
        guard !done else { return }
        done = true
        line("")
        line("--- end (\(reason)). bytes received: \(byteCount) ---")
        channelRef?.close()
    }

    // Delegate
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        byteCount += dataLength
        let t = startedAt.map { String(format: "+%.3f", Date().timeIntervalSince($0)) } ?? "?"
        line("[\(t)s] (\(dataLength) bytes)")
        line("  hex   : \(hex(data))")
        line("  ascii : \(ascii(data))")
    }
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        line("rfcommChannelOpenComplete: \(String(format: "0x%x", error))")
    }
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        line("rfcommChannelClosed")
        finish(reason: "closed by peer")
    }
    func rfcommChannelControlSignalsChanged(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelFlowControlChanged(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {}
    func rfcommChannelQueueSpaceAvailable(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {}
}

// MARK: - Main dispatch

head("MotoBuds tool — \(mode) mode")
line("date: \(Date())")

switch mode {
case "discover":
    dumpClassic()
    head("Bluetooth LE — GATT scan")
    let scanner = GATTScanner(); scanner.start()
    let started = Date()
    while !scanner.done {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        if Date().timeIntervalSince(started) > 30.0 { break }
    }

case "sniff":
    guard args.count >= 2 else {
        line("usage: DiscoverBuds sniff <MAC> <channel> [<seconds>] [<outfile.txt>]")
        exit(2)
    }
    let mac = args[0]
    guard let ch = UInt8(args[1]) else { line("bad channel"); exit(2) }
    let seconds = args.count >= 3 ? (TimeInterval(args[2]) ?? 15.0) : 15.0
    let s = RFCOMMSniffer(mac: mac, channel: ch, duration: seconds)
    s.start()
    while !s.done {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }

case "listen":
    // Passive listener: opens RFCOMM ch and dumps every frame received.
    //   DiscoverBuds listen <MAC> <channel> [<seconds>]
    guard args.count >= 2 else {
        line("usage: DiscoverBuds listen <MAC> <channel> [<seconds>]")
        exit(2)
    }
    let mac = args[0]
    guard let ch = UInt8(args[1]) else { line("bad channel"); exit(2) }
    let secs = args.count >= 3 ? (TimeInterval(args[2]) ?? 60.0) : 60.0
    // Use SppProbe with empty steps — just opens, sleeps, dumps.
    let p = SppProbe(mac: mac, channel: ch, steps: [
        ProbeStep("(passive listen)", 0x000, waitAfter: secs),
    ])
    p.run()
    while !p.done {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }

case "probe":
    // Two forms:
    //   DiscoverBuds probe <MAC> <channel> <script-name>
    //   DiscoverBuds probe <MAC> <channel> "raw:<opcode>:<payloadhex>" "raw:..." …
    guard args.count >= 3 else {
        line("usage: DiscoverBuds probe <MAC> <channel> <scriptName | raw:OPCODE:PAYLOAD ...>")
        line("scripts: anc-cycle, audio-toggles, find-buds, dual-connect, getters, fit-test")
        exit(2)
    }
    let mac = args[0]
    guard let ch = UInt8(args[1]) else { line("bad channel"); exit(2) }
    let scriptArgs = Array(args.dropFirst(2))

    // Predefined scripts.
    let scripts: [String: [ProbeStep]] = [
        "getters": [
            ProbeStep("get profile version", 0x000),
            ProbeStep("get support features", 0x001),
            ProbeStep("get support configurations", 0x002),
            ProbeStep("get device name", 0x003),
            ProbeStep("get hardware info", 0x004),
            ProbeStep("get battery level", 0x005),
            ProbeStep("get earbuds color", 0x00A),
            ProbeStep("list support info+configs", 0x00B),
            ProbeStep("get ANC mode", 0x200),
            ProbeStep("get adaptation status", 0x202),
            ProbeStep("get hi-res mode", 0x30C),
            ProbeStep("get game mode", 0x30E),
            ProbeStep("get volume boost", 0x313),
            ProbeStep("get bass enhancement", 0x31C),
            ProbeStep("get in-ear detection", 0x402),
            ProbeStep("get dual connection state", 0x406),
        ],
        "anc-cycle": [
            ProbeStep("get ANC current",            0x200, waitAfter: 1.0),
            ProbeStep("set ANC = 0 (off)",          0x201, "00", waitAfter: 2.5),
            ProbeStep("get ANC after off",          0x200, waitAfter: 1.0),
            ProbeStep("set ANC = 1 (transparency)", 0x201, "01", waitAfter: 2.5),
            ProbeStep("get ANC after transp",       0x200, waitAfter: 1.0),
            ProbeStep("set ANC = 2 (anc on)",       0x201, "02", waitAfter: 2.5),
            ProbeStep("get ANC after anc-on",       0x200, waitAfter: 1.0),
            ProbeStep("set ANC = 0 (off, restore)", 0x201, "00", waitAfter: 1.5),
        ],
        "audio-toggles": [
            ProbeStep("get bass",     0x31C),
            ProbeStep("set bass = 1", 0x31D, "01", waitAfter: 1.5),
            ProbeStep("get bass",     0x31C),
            ProbeStep("set bass = 0", 0x31D, "00", waitAfter: 1.0),
            ProbeStep("get vboost",     0x313),
            ProbeStep("set vboost = 1", 0x314, "01", waitAfter: 1.5),
            ProbeStep("get vboost",     0x313),
            ProbeStep("set vboost = 0", 0x314, "00", waitAfter: 1.0),
            ProbeStep("get hi-res",     0x30C),
            ProbeStep("set hi-res = 1", 0x30D, "01", waitAfter: 1.5),
            ProbeStep("get hi-res",     0x30C),
            ProbeStep("set hi-res = 0", 0x30D, "00", waitAfter: 1.0),
            ProbeStep("get game-mode",     0x30E),
            ProbeStep("set game-mode = 1", 0x30F, "01", waitAfter: 1.5),
            ProbeStep("get game-mode",     0x30E),
            ProbeStep("set game-mode = 0", 0x30F, "00", waitAfter: 1.0),
        ],
        "find-buds": [
            ProbeStep("find left = 0x00 0x01",  0x405, "00 01", waitAfter: 3.0),
            ProbeStep("stop = 0x02 0x00",       0x405, "02 00", waitAfter: 1.0),
            ProbeStep("find right = 0x01 0x01", 0x405, "01 01", waitAfter: 3.0),
            ProbeStep("stop = 0x02 0x00",       0x405, "02 00", waitAfter: 1.0),
        ],
        "find-buds-alt": [
            // Some BES firmwares: single byte side. 0=L, 1=R, 2=both
            ProbeStep("find side=0",  0x405, "00", waitAfter: 3.0),
            ProbeStep("find side=1",  0x405, "01", waitAfter: 3.0),
            ProbeStep("find side=2",  0x405, "02", waitAfter: 3.0),
        ],
        "dual-connect": [
            ProbeStep("get dual-conn state", 0x406),
            ProbeStep("set dual-conn = [01, 01]", 0x407, "01 01", waitAfter: 2.0),
            ProbeStep("get state",           0x406),
            ProbeStep("set dual-conn = [01, 00]", 0x407, "01 00", waitAfter: 2.0),
            ProbeStep("get state",           0x406),
        ],
        "fit-test": [
            ProbeStep("set fit state = 01", 0x400, "01", waitAfter: 5.0),
            ProbeStep("set fit state = 00", 0x400, "00", waitAfter: 1.0),
        ],
        "anc-audible": [
            // No setAdaptive — purely the toggle config.
            // 8 seconds between modes so the user has time to focus
            // and notice any auto-revert.
            ProbeStep(">>> APAGADO (off)",         0x102, "01 00 00", waitAfter: 8.0),
            ProbeStep(">>> TRANSPARENCIA",         0x102, "01 02 00", waitAfter: 8.0),
            ProbeStep(">>> CANCELACION strength 2",0x102, "01 01 02", waitAfter: 8.0),
            ProbeStep(">>> ADAPTATIVO (str 1)",    0x102, "01 01 01", waitAfter: 8.0),
            ProbeStep(">>> APAGADO final",         0x102, "01 00 00", waitAfter: 2.0),
        ],
        "anc-with-adapt": [
            // Same modes but with setAdaptationStatus(false) before each.
            ProbeStep(">>> adapt off, APAGADO",   0x203, "00", waitAfter: 0.3),
            ProbeStep("    +setToggle off",       0x102, "01 00 00", waitAfter: 8.0),
            ProbeStep(">>> adapt off, TRANSP",    0x203, "00", waitAfter: 0.3),
            ProbeStep("    +setToggle transp",    0x102, "01 02 00", waitAfter: 8.0),
            ProbeStep(">>> adapt off, ANC",       0x203, "00", waitAfter: 0.3),
            ProbeStep("    +setToggle anc",       0x102, "01 01 02", waitAfter: 8.0),
            ProbeStep(">>> adapt on, ADAPTIVE",   0x203, "01", waitAfter: 0.3),
            ProbeStep("    +setToggle anc str 1", 0x102, "01 01 01", waitAfter: 8.0),
        ],
    ]

    var steps: [ProbeStep] = []
    if scriptArgs.count == 1, let s = scripts[scriptArgs[0]] {
        steps = s
    } else {
        for arg in scriptArgs {
            // raw:OPCODE_HEX:PAYLOAD_HEX  or  raw:OPCODE_HEX
            let parts = arg.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count >= 2, parts[0] == "raw",
               let op = UInt16(parts[1], radix: 16) {
                let pay = parts.count >= 3 ? String(parts[2]) : ""
                steps.append(ProbeStep("raw 0x\(String(op, radix: 16))", op, pay, waitAfter: 1.5))
            } else {
                line("bad arg: \(arg)"); exit(2)
            }
        }
    }
    if steps.isEmpty { line("no steps"); exit(2) }
    let p = SppProbe(mac: mac, channel: ch, steps: steps)
    p.run()
    while !p.done {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }

default:
    line("unknown mode: \(mode)"); exit(2)
}

head("done")
