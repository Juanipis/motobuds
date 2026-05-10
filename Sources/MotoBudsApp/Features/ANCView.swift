import SwiftUI

public struct ANCView: View {
    @Bindable var manager: BudsManager
    public init(manager: BudsManager) { self.manager = manager }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Cancelación de ruido").font(.motoHeadline())
                        .foregroundStyle(MotoColor.textPrimary)
                    Spacer()
                    Text(manager.state.ancMode.displayName)
                        .font(.motoMono(10))
                        .foregroundStyle(MotoColor.accent)
                }
                HStack(spacing: 10) {
                    ForEach(ANCMode.allCases) { mode in
                        let selected = manager.state.ancMode == mode
                        Button {
                            manager.setANC(mode)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: mode.symbol)
                                    .font(.system(size: 20))
                                Text(mode.displayName)
                                    .font(.motoBody(11).weight(.medium))
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .padding(8)
                            .foregroundStyle(selected ? MotoColor.accent : MotoColor.textPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? MotoColor.accentSoft : MotoColor.bgCardAlt)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selected ? MotoColor.accent : .clear,
                                                  lineWidth: 1.5)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
