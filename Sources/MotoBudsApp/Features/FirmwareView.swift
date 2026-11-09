import SwiftUI

public struct FirmwareView: View {
    let manager: BudsManager
    @EnvironmentObject private var updater: Updater
    @State private var loginItemState: LoginItem.State = .disabled
    @State private var loginItemError: String?

    public init(manager: BudsManager) { self.manager = manager }

    public var body: some View {
        VStack(spacing: 16) {
            preferencesCard
            aboutCard
        }
        .onAppear { loginItemState = LoginItem.current }
    }

    @ViewBuilder
    private var preferencesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preferencias").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                Toggle(isOn: Binding(
                    get: { loginItemState == .enabled || loginItemState == .requiresApproval },
                    set: { newValue in
                        switch LoginItem.setEnabled(newValue) {
                        case .success(let s):
                            loginItemState = s
                            loginItemError = nil
                        case .failure(let err):
                            loginItemError = err.localizedDescription
                        }
                    }
                )) {
                    Text("Abrir al iniciar sesión")
                        .font(.motoBody()).foregroundStyle(MotoColor.textPrimary)
                }
                .toggleStyle(.switch).tint(MotoColor.accent)
                .disabled(loginItemState == .unsupported)

                if loginItemState == .requiresApproval {
                    Text("Esperando aprobación en Ajustes del Sistema → General → Ítems de inicio.")
                        .font(.motoBody(11))
                        .foregroundStyle(MotoColor.warning)
                }
                if let err = loginItemError {
                    Text("Error: \(err)").font(.motoMono(10))
                        .foregroundStyle(MotoColor.accent)
                }
                if loginItemState == .unsupported {
                    Text("Requiere macOS 13 o superior, app instalada en /Applications.")
                        .font(.motoBody(11))
                        .foregroundStyle(MotoColor.textSecondary)
                }
                Divider().background(MotoColor.separator).padding(.vertical, 2)
                Button {
                    updater.checkNow()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(updater.canCheck ? "Buscar actualizaciones" : "Buscando…")
                    }
                }
                .buttonStyle(PillButtonStyle(selected: false))
                .disabled(!updater.canCheck)
            }
        }
    }

    @ViewBuilder
    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Buds").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                row("Modelo", "XT2443-1 (guitar)")
                row("Nombre", manager.state.deviceName)
                row("MAC", manager.state.deviceMAC.isEmpty ? "—" : manager.state.deviceMAC)
                row("Firmware", manager.state.hardware.profileVersion ?? "—")
                row("Serial izq.", manager.state.hardware.leftSerial ?? "—")
                row("Serial der.", manager.state.hardware.rightSerial ?? "—")
                row("Serial estuche", manager.state.hardware.caseSerial ?? "—")
                row("SKU", manager.state.hardware.sku ?? "—")
                Divider().background(MotoColor.separator).padding(.vertical, 4)
                Text("App").font(.motoBody(12).weight(.semibold))
                    .foregroundStyle(MotoColor.textSecondary)
                row("Versión",
                    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    ?? "?")
                row("Transporte", manager.usingMockTransport ? "Mock (UI)" : "RFCOMM SPP ch 16")
                row("Repositorio", "github.com/Juanipis/motobuds")
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
