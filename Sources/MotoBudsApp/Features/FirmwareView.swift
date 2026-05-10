import SwiftUI

public struct FirmwareView: View {
    let manager: BudsManager
    public init(manager: BudsManager) { self.manager = manager }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Acerca de").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                row("Modelo", "XT2443-1 (guitar)")
                row("Nombre", manager.state.deviceName)
                row("MAC", manager.state.deviceMAC.isEmpty ? "—" : manager.state.deviceMAC)
                row("Firmware izq.", manager.state.firmware.leftBud ?? "—")
                row("Firmware der.", manager.state.firmware.rightBud ?? "—")
                row("Firmware estuche", manager.state.firmware.caseFW ?? "—")
                row("Transporte", manager.usingMockTransport ? "Mock (UI)" : "GATT")
            }
        }
    }
    @ViewBuilder
    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.motoBody()).foregroundStyle(MotoColor.textSecondary)
            Spacer()
            Text(v).font(.motoBody().monospaced()).foregroundStyle(MotoColor.textPrimary)
        }
    }
}
