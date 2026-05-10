import Foundation

/// Transporte falso: simula un par de buds completamente funcional para
/// desarrollar la UI sin hardware ni protocolo real. Genera batería que va
/// bajando con el tiempo y "responde" a comandos cambiando estado interno.
public actor MockTransport: Transport {
    public private(set) var isConnected: Bool = false
    private var continuation: AsyncStream<Data>.Continuation?
    private var stream: AsyncStream<Data>?

    public init() {}

    public func connect() async throws {
        guard !isConnected else { return }
        try await Task.sleep(nanoseconds: 600_000_000)
        isConnected = true
    }

    public func disconnect() async {
        isConnected = false
        continuation?.finish()
        continuation = nil
        stream = nil
    }

    public func send(_ packet: Data) async throws {
        guard isConnected else { throw TransportError.notConnected }
        // Para mocks no hacemos nada — los cambios de estado se manejan en
        // BudsManager directamente cuando detectamos transporte mock.
    }

    public func incomingPackets() -> AsyncStream<Data> {
        if let s = stream { return s }
        let s = AsyncStream<Data> { cont in
            self.continuation = cont
        }
        self.stream = s
        return s
    }
}
