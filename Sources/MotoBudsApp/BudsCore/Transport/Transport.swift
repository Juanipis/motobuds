import Foundation

/// Resultado de transporte tipo enum.
public enum TransportError: Error, Sendable, CustomStringConvertible {
    case notConnected
    case channelOpenFailed(code: Int32)
    case writeFailed(code: Int32)
    case timeout
    case notImplemented(String)
    case budsNotAdvertising
    case bluetoothOff

    public var description: String {
        switch self {
        case .notConnected: return "no connection"
        case .channelOpenFailed(let c): return "channel open failed (\(c))"
        case .writeFailed(let c): return "write failed (\(c))"
        case .timeout: return "timeout"
        case .notImplemented(let s): return "not implemented: \(s)"
        case .budsNotAdvertising:
            return "buds no encontrados por BLE — abre el case unos segundos y reintenta"
        case .bluetoothOff: return "Bluetooth apagado"
        }
    }
}

/// Abstracción sobre cómo hablamos con los buds.
/// Tiene dos implementaciones:
///   - `MockTransport`: para desarrollar la UI sin hardware.
///   - `RFCOMMTransport`: protocolo real BES sobre RFCOMM (pendiente de opcodes).
public protocol Transport: Actor {
    func connect() async throws
    func disconnect() async
    func send(_ packet: Data) async throws
    /// Stream asíncrono de paquetes recibidos.
    func incomingPackets() -> AsyncStream<Data>
    var isConnected: Bool { get }
}
