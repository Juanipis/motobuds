import SwiftUI

public struct FindBudsView: View {
    @Bindable var manager: BudsManager
    public init(manager: BudsManager) { self.manager = manager }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Buscar buds").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                Text("Reproduce un sonido fuerte en el aurícular para encontrarlo.")
                    .font(.motoBody())
                    .foregroundStyle(MotoColor.textSecondary)

                HStack(spacing: 10) {
                    Button("Sonar izquierdo") { manager.findBuds(side: .left) }
                        .buttonStyle(PillButtonStyle(selected: manager.state.findBuds == .findingLeft))
                    Button("Sonar derecho") { manager.findBuds(side: .right) }
                        .buttonStyle(PillButtonStyle(selected: manager.state.findBuds == .findingRight))
                    if manager.state.findBuds != .idle {
                        Button("Detener") { manager.stopFindBuds() }
                            .buttonStyle(PillButtonStyle(selected: false))
                    }
                }

                if manager.state.findBuds != .idle {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.3")
                            .foregroundStyle(MotoColor.accent)
                            .symbolEffect(.pulse, options: .repeating)
                        Text(activeText)
                            .font(.motoBody(12).weight(.medium))
                            .foregroundStyle(MotoColor.accent)
                    }
                }
            }
        }
    }

    private var activeText: String {
        switch manager.state.findBuds {
        case .findingLeft:  return "Sonando aurícular izquierdo…"
        case .findingRight: return "Sonando aurícular derecho…"
        case .findingBoth:  return "Sonando ambos…"
        case .idle:         return ""
        }
    }
}
