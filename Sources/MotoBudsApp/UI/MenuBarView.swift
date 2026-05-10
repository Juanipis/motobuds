import SwiftUI

public struct MenuBarView: View {
    @Bindable var manager: BudsManager
    let openMain: () -> Void
    public init(manager: BudsManager, openMain: @escaping () -> Void) {
        self.manager = manager; self.openMain = openMain
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(manager.state.deviceName)
                .font(.motoHeadline(15))
                .foregroundStyle(MotoColor.textPrimary)
            HStack(spacing: 12) {
                miniBattery("L", manager.state.batteryLeft)
                miniBattery("R", manager.state.batteryRight)
                miniBattery("C", manager.state.batteryCase)
            }
            Divider()
            Text("Cancelación de ruido")
                .font(.motoBody(11).weight(.medium))
                .foregroundStyle(MotoColor.textSecondary)
            HStack(spacing: 6) {
                ForEach(ANCMode.allCases) { m in
                    Button {
                        manager.setANC(m)
                    } label: {
                        Image(systemName: m.symbol)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(manager.state.ancMode == m
                                  ? MotoColor.accentSoft : MotoColor.bgCardAlt)
                    )
                    .foregroundStyle(manager.state.ancMode == m
                                     ? MotoColor.accent : MotoColor.textPrimary)
                    .help(m.displayName)
                }
            }
            Divider()
            Button(action: openMain) {
                HStack { Text("Abrir MotoBuds"); Spacer(); Image(systemName: "arrow.up.right.square") }
            }
            .buttonStyle(.plain)
            .font(.motoBody(12))
            .foregroundStyle(MotoColor.textPrimary)
            Button(action: { NSApp.terminate(nil) }) {
                HStack { Text("Salir"); Spacer(); Image(systemName: "power") }
            }
            .buttonStyle(.plain)
            .font(.motoBody(12))
            .foregroundStyle(MotoColor.textSecondary)
        }
        .padding(14)
        .frame(width: 260)
        .background(MotoColor.bgDeep)
    }
    @ViewBuilder
    private func miniBattery(_ label: String, _ pct: Int?) -> some View {
        VStack(spacing: 3) {
            Text(pct.map { "\($0)%" } ?? "—")
                .font(.motoMono(12).weight(.semibold))
                .foregroundStyle(MotoColor.textPrimary)
            Text(label)
                .font(.motoMono(9))
                .foregroundStyle(MotoColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
