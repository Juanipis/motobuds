import SwiftUI

public struct DualConnectView: View {
    @Bindable var manager: BudsManager
    public init(manager: BudsManager) { self.manager = manager }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Conexión múltiple").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                Toggle(isOn: Binding(
                    get: { manager.state.dualConnect },
                    set: { manager.setDualConnect($0) }
                )) {
                    Text("Permitir conectar a dos dispositivos a la vez")
                        .font(.motoBody())
                        .foregroundStyle(MotoColor.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(MotoColor.accent)
                Text("Útil para alternar entre tu iPhone y este Mac sin re-emparejar.")
                    .font(.motoBody(11))
                    .foregroundStyle(MotoColor.textSecondary)
            }
        }
    }
}
