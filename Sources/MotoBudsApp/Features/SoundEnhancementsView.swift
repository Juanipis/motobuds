import SwiftUI

public struct SoundEnhancementsView: View {
    @Bindable var manager: BudsManager
    public init(manager: BudsManager) { self.manager = manager }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mejoras de sonido").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                toggleRow("Audio de alta resolución", "hifispeaker",
                          isOn: Binding(get: { manager.state.toggles.hiRes },
                                        set: { manager.setHiRes($0) }))
                toggleRow("Refuerzo de graves", "waveform.path",
                          isOn: Binding(get: { manager.state.toggles.bassEnhancement },
                                        set: { manager.setBassEnhancement($0) }))
                toggleRow("Volume Boost", "speaker.wave.3",
                          isOn: Binding(get: { manager.state.toggles.volumeBoost },
                                        set: { manager.setVolumeBoost($0) }))
                toggleRow("Modo gaming (baja latencia)", "gamecontroller",
                          isOn: Binding(get: { manager.state.toggles.gameMode },
                                        set: { manager.setGameMode($0) }))
                toggleRow("Adaptive hearing", "wand.and.stars",
                          isOn: Binding(get: { manager.state.toggles.adaptiveHearing },
                                        set: { manager.setAdaptiveHearing($0) }))
            }
        }
    }
    @ViewBuilder
    private func toggleRow(_ label: String, _ symbol: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(MotoColor.textSecondary)
            Text(label)
                .font(.motoBody())
                .foregroundStyle(MotoColor.textPrimary)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(MotoColor.accent)
        }
    }
}

public struct WearDetectionView: View {
    @Bindable var manager: BudsManager
    public init(manager: BudsManager) { self.manager = manager }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Detección en oído").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                Toggle(isOn: Binding(
                    get: { manager.state.toggles.inEarDetection },
                    set: { manager.setInEarDetection($0) }
                )) {
                    Text("Pausar al quitarme un aurícular")
                        .font(.motoBody())
                        .foregroundStyle(MotoColor.textPrimary)
                }
                .toggleStyle(.switch).tint(MotoColor.accent)
            }
        }
    }
}
