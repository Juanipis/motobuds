import SwiftUI

public struct ContentView: View {
    @Bindable var manager: BudsManager

    public enum Section: String, CaseIterable, Identifiable {
        case home, sound, connection, find, about
        public var id: String { rawValue }
        var title: String {
            switch self {
            case .home: return "Inicio"
            case .sound: return "Sonido"
            case .connection: return "Conexión"
            case .find: return "Buscar"
            case .about: return "Acerca de"
            }
        }
        var symbol: String {
            switch self {
            case .home: return "house.fill"
            case .sound: return "waveform"
            case .connection: return "antenna.radiowaves.left.and.right"
            case .find: return "location.magnifyingglass"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selection: Section = .home

    public init(manager: BudsManager) { self.manager = manager }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MotoColor.bgDeep)
        }
        .frame(minWidth: 820, minHeight: 560)
        .toolbarBackground(MotoColor.bgDeep, for: .windowToolbar)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(MotoColor.accent)
                    .frame(width: 18, height: 18)
                Text("MotoBuds").font(.motoTitle(20))
                    .foregroundStyle(MotoColor.textPrimary)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 18)

            ForEach(Section.allCases) { s in
                Button {
                    selection = s
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: s.symbol).frame(width: 18)
                        Text(s.title).font(.motoBody(13))
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .foregroundStyle(selection == s ? MotoColor.accent : MotoColor.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selection == s ? MotoColor.accentSoft : .clear)
                            .padding(.horizontal, 6)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(manager.state.connection == .connected ? MotoColor.success
                          : manager.state.connection == .connecting ? MotoColor.warning
                          : Color.gray)
                    .frame(width: 7, height: 7)
                Text(manager.usingMockTransport ? "Mock"
                     : (manager.state.connection == .connected ? "Conectado" : "Desconectado"))
                    .font(.motoMono(10))
                    .foregroundStyle(MotoColor.textSecondary)
            }
            .padding(14)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        .background(MotoColor.bgDeep)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selection {
                case .home:
                    BudsHeroView(state: manager.state)
                    BatteryView(state: manager.state)
                    ANCView(manager: manager)
                case .sound:
                    ANCView(manager: manager)
                    SoundEnhancementsView(manager: manager)
                    WearDetectionView(manager: manager)
                case .connection:
                    DualConnectView(manager: manager)
                    if !manager.usingMockTransport {
                        connectionControls
                    }
                case .find:
                    FindBudsView(manager: manager)
                case .about:
                    FirmwareView(manager: manager)
                    debugLog
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var connectionHint: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(MotoColor.warning)
                    Text("Buds no detectados por BLE")
                        .font(.motoHeadline(14))
                        .foregroundStyle(MotoColor.textPrimary)
                }
                Text("macOS necesita ver los buds anunciando BLE al menos una vez. Abre el case por unos segundos cerca del Mac y dale Reconectar — después se conectará solo.")
                    .font(.motoBody())
                    .foregroundStyle(MotoColor.textSecondary)
                Button("Reconectar") { manager.connect() }
                    .buttonStyle(PillButtonStyle(selected: false))
            }
        }
    }

    @ViewBuilder
    private var connectionControls: some View {
        Card {
            HStack {
                Button(manager.state.connection == .connected ? "Desconectar" : "Conectar") {
                    if manager.state.connection == .connected { manager.disconnect() }
                    else { manager.connect() }
                }
                .buttonStyle(PillButtonStyle(selected: manager.state.connection == .connected))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var debugLog: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Registro").font(.motoHeadline())
                        .foregroundStyle(MotoColor.textPrimary)
                    Spacer()
                    Button("Copiar todo") {
                        let all = manager.debugLog.joined(separator: "\n")
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(all, forType: .string)
                    }
                    .buttonStyle(PillButtonStyle(selected: false))
                }
                // TextEditor allows native text selection + copy/paste.
                TextEditor(text: .constant(manager.debugLog.joined(separator: "\n")))
                    .font(.motoMono(10))
                    .foregroundStyle(MotoColor.textSecondary)
                    .scrollContentBackground(.hidden)
                    .background(MotoColor.bgCardAlt)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("También en: ~/Library/Logs/MotoBuds.log")
                    .font(.motoMono(9))
                    .foregroundStyle(MotoColor.textSecondary)
            }
        }
    }
}
