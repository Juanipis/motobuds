import SwiftUI

/// Render simbólico de los buds + estuche. No es el modelo real (no licenciamos
/// arte de Motorola); usamos SF Symbols + capas para lograr un look limpio.
public struct BudsHeroView: View {
    let state: BudsState
    @State private var hover = false

    public init(state: BudsState) { self.state = state }

    public var body: some View {
        ZStack {
            RadialGradient(
                colors: [MotoColor.accent.opacity(0.14), .clear],
                center: .center, startRadius: 10, endRadius: 220
            )
            .blur(radius: 4)

            Image(systemName: "airpodspro.chargingcase.wireless")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(MotoColor.textPrimary, MotoColor.bgCardAlt)
                .frame(width: 220, height: 160)
                .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
                .scaleEffect(hover ? 1.02 : 1.0)
                .rotation3DEffect(.degrees(hover ? 6 : 0), axis: (x: 1, y: 0, z: 0))
                .animation(.smooth(duration: 0.6), value: hover)

            statusOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
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
}
