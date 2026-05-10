import SwiftUI

public struct BatteryView: View {
    let state: BudsState
    public init(state: BudsState) { self.state = state }
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Batería").font(.motoHeadline())
                    .foregroundStyle(MotoColor.textPrimary)
                HStack(spacing: 18) {
                    BatteryCell(label: "Izq", percent: state.batteryLeft,
                                inEar: state.live.leftInEar, inCase: state.live.leftInCase)
                    BatteryCell(label: "Der", percent: state.batteryRight,
                                inEar: state.live.rightInEar, inCase: state.live.rightInCase)
                    CaseBatteryCell(percent: state.batteryCase)
                }
            }
        }
    }
}

struct BatteryCell: View {
    let label: String
    let percent: Int?
    let inEar: Bool
    let inCase: Bool
    var color: Color {
        guard let p = percent else { return MotoColor.textSecondary }
        if p < 15 { return MotoColor.accent }
        if p < 30 { return MotoColor.warning }
        return MotoColor.success
    }
    var statusText: String {
        if inCase { return "en case" }
        if inEar { return "en oído" }
        return "—"
    }
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "earbuds")
                .font(.system(size: 22))
                .foregroundStyle(inEar ? MotoColor.accent : MotoColor.textSecondary)
            ZStack {
                Circle().stroke(MotoColor.bgCardAlt, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(percent ?? 0) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: percent)
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.motoBody(12).weight(.semibold))
                    .foregroundStyle(MotoColor.textPrimary)
            }
            .frame(width: 48, height: 48)
            Text(label).font(.motoBody(11)).foregroundStyle(MotoColor.textSecondary)
            Text(statusText).font(.motoMono(9)).foregroundStyle(MotoColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CaseBatteryCell: View {
    let percent: Int?
    var color: Color {
        guard let p = percent else { return MotoColor.textSecondary }
        if p < 15 { return MotoColor.accent }
        if p < 30 { return MotoColor.warning }
        return MotoColor.success
    }
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "battery.100")
                .font(.system(size: 22))
                .foregroundStyle(MotoColor.textSecondary)
            ZStack {
                Circle().stroke(MotoColor.bgCardAlt, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(percent ?? 0) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: percent)
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.motoBody(12).weight(.semibold))
                    .foregroundStyle(MotoColor.textPrimary)
            }
            .frame(width: 48, height: 48)
            Text("Estuche").font(.motoBody(11)).foregroundStyle(MotoColor.textSecondary)
            Text(percent == nil ? "no detect." : "—")
                .font(.motoMono(9)).foregroundStyle(MotoColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

