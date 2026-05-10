import SwiftUI

/// Hero render of the buds. We use the system SF Symbol because it scales
/// crisply at every size and looks unmistakably like a pair of earbuds in
/// a case — much better than my hand-rolled Canvas attempt. We layer
/// status pills on top to surface in-ear / in-case state at a glance.
public struct BudsHeroView: View {
    let state: BudsState
    @State private var hover = false

    public init(state: BudsState) { self.state = state }

    public var body: some View {
        ZStack {
            RadialGradient(
                colors: [MotoColor.accent.opacity(0.18), .clear],
                center: .center, startRadius: 10, endRadius: 240
            )
            .blur(radius: 6)

            Image(systemName: "airpodspro.chargingcase.wireless.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    state.connection == .connected
                        ? MotoColor.textPrimary : MotoColor.textSecondary,
                    MotoColor.bgCardAlt
                )
                .frame(height: 140)
                .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
                .scaleEffect(hover ? 1.03 : 1.0)
                .rotation3DEffect(.degrees(hover ? 6 : 0), axis: (x: 1, y: 0, z: 0))
                .animation(.smooth(duration: 0.6), value: hover)

            // Top-left: connection state.
            statusOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)

            // Bottom row: in-ear / in-case live indicators.
            wearStatusOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
        }
        .frame(height: 220)
        .onHover { hover = $0 }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.connection == .connected ? MotoColor.success
                      : state.connection == .connecting ? MotoColor.warning
                      : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
            Text(state.connection == .connected ? "Conectado"
                 : state.connection == .connecting ? "Conectando…"
                 : "Desconectado")
                .font(.motoBody(11).weight(.medium))
                .foregroundStyle(MotoColor.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(MotoColor.bgCard.opacity(0.85)))
    }

    @ViewBuilder
    private var wearStatusOverlay: some View {
        HStack(spacing: 8) {
            wearPill(label: "Izq",
                     active: state.live.leftInEar,
                     docked: state.live.leftInCase)
            wearPill(label: "Der",
                     active: state.live.rightInEar,
                     docked: state.live.rightInCase)
        }
    }

    @ViewBuilder
    private func wearPill(label: String, active: Bool, docked: Bool) -> some View {
        let icon = docked ? "battery.100.bolt"
                  : active ? "ear.fill" : "ear"
        let color: Color = docked ? MotoColor.success
                          : active ? MotoColor.accent : MotoColor.textSecondary
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.motoMono(10).weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(MotoColor.bgCard.opacity(0.9)))
        .overlay(
            Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1)
        )
    }
}
