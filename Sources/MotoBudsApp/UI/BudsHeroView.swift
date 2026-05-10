import SwiftUI

/// Hand-rolled illustration of the buds + case. Canvas instead of SF Symbol
/// so the buds glow when they're in-ear (live signal) and the case glows
/// when at least one bud is docked. We don't ship Motorola's official art —
/// this is a generic stylised render under MIT.
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

            HStack(spacing: 36) {
                BudShape(side: .left,
                         active: state.live.leftInEar,
                         dimmed: state.live.leftInCase)
                CaseShape(open: state.live.leftInCase || state.live.rightInCase,
                          chargingLeft: state.live.leftInCase,
                          chargingRight: state.live.rightInCase)
                BudShape(side: .right,
                         active: state.live.rightInEar,
                         dimmed: state.live.rightInCase)
            }
            .scaleEffect(hover ? 1.02 : 1.0)
            .rotation3DEffect(.degrees(hover ? 4 : 0), axis: (x: 1, y: 0, z: 0))
            .animation(.smooth(duration: 0.6), value: hover)
            .shadow(color: .black.opacity(0.55), radius: 18, y: 10)

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

/// One bud — stem + tip. Mirrored on the X axis for the right side.
struct BudShape: View {
    let side: BudSide
    let active: Bool
    let dimmed: Bool

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let mirror = side == .right

            // Drawing in a normalized 1.0 × 1.0 box centered on (0.5, 0.7).
            // The stem points up and slightly outward.
            var stem = Path()
            stem.move(to: pt(0.42, 0.05, s, mirror))
            stem.addCurve(to:      pt(0.36, 0.55, s, mirror),
                          control1: pt(0.40, 0.20, s, mirror),
                          control2: pt(0.36, 0.40, s, mirror))
            stem.addLine(to:       pt(0.55, 0.60, s, mirror))
            stem.addCurve(to:      pt(0.58, 0.10, s, mirror),
                          control1: pt(0.55, 0.40, s, mirror),
                          control2: pt(0.55, 0.20, s, mirror))
            stem.closeSubpath()

            // Tip — squashed ellipse for the in-ear bulb.
            let tipRect = CGRect(
                x: (mirror ? size.width - 0.78 * s : 0.20 * s),
                y: 0.45 * s,
                width: 0.40 * s, height: 0.50 * s
            )
            let tip = Path(ellipseIn: tipRect)

            // Base shading.
            let body = stem.union(tip)
            ctx.fill(body, with: .linearGradient(
                Gradient(colors: shellColors),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            ))

            // Highlight along the stem.
            var highlight = Path()
            highlight.move(to: pt(0.45, 0.10, s, mirror))
            highlight.addCurve(to:      pt(0.42, 0.45, s, mirror),
                               control1: pt(0.44, 0.20, s, mirror),
                               control2: pt(0.42, 0.32, s, mirror))
            ctx.stroke(highlight, with: .color(.white.opacity(0.18)),
                       style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round))

            // Speaker mesh dot (active glow when in ear).
            let speakerCenter = CGPoint(
                x: (mirror ? size.width - 0.40 * s : 0.40 * s),
                y: 0.70 * s
            )
            let speaker = Path(ellipseIn: CGRect(
                x: speakerCenter.x - s * 0.05,
                y: speakerCenter.y - s * 0.05,
                width: s * 0.10, height: s * 0.10
            ))
            ctx.fill(speaker, with: .color(active ? MotoColor.accent : .black.opacity(0.4)))
            if active {
                ctx.drawLayer { layer in
                    layer.addFilter(.shadow(color: MotoColor.accent.opacity(0.8),
                                            radius: s * 0.05))
                    layer.fill(speaker, with: .color(MotoColor.accent))
                }
            }
        }
        .frame(width: 80, height: 110)
        .opacity(dimmed ? 0.55 : 1.0)
        .animation(.smooth(duration: 0.4), value: active)
        .animation(.smooth(duration: 0.4), value: dimmed)
    }

    private var shellColors: [Color] {
        [MotoColor.bgCardAlt, Color(red: 0.18, green: 0.18, blue: 0.20),
         MotoColor.bgCardAlt]
    }

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ mirror: Bool) -> CGPoint {
        let xx = mirror ? (1 - x) : x
        return CGPoint(x: xx * s, y: y * s)
    }
}

/// The case — rounded pill that opens slightly when at least one bud is in.
struct CaseShape: View {
    let open: Bool
    let chargingLeft: Bool
    let chargingRight: Bool

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let body = CGRect(
                x: 0.05 * size.width, y: 0.20 * size.height,
                width: 0.90 * size.width, height: 0.60 * size.height
            )
            let path = Path(roundedRect: body,
                            cornerSize: CGSize(width: s * 0.18, height: s * 0.18))
            ctx.fill(path, with: .linearGradient(
                Gradient(colors: [Color(red: 0.14, green: 0.14, blue: 0.17),
                                  Color(red: 0.22, green: 0.22, blue: 0.25)]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ))
            ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)

            // Hinge line — slightly higher when "open".
            let hingeY = body.minY + body.height * (open ? 0.42 : 0.50)
            var hinge = Path()
            hinge.move(to: CGPoint(x: body.minX + 6, y: hingeY))
            hinge.addLine(to: CGPoint(x: body.maxX - 6, y: hingeY))
            ctx.stroke(hinge, with: .color(.white.opacity(0.10)),
                       style: StrokeStyle(lineWidth: 1.5))

            // Charging LED.
            let ledColor: Color = (chargingLeft || chargingRight)
                ? MotoColor.success : .gray.opacity(0.4)
            let led = Path(ellipseIn: CGRect(
                x: body.midX - 3, y: body.maxY - 12,
                width: 6, height: 6
            ))
            ctx.fill(led, with: .color(ledColor))
            if chargingLeft || chargingRight {
                ctx.drawLayer { layer in
                    layer.addFilter(.shadow(color: MotoColor.success.opacity(0.8),
                                            radius: 4))
                    layer.fill(led, with: .color(MotoColor.success))
                }
            }
        }
        .frame(width: 110, height: 110)
        .animation(.smooth(duration: 0.4), value: open)
        .animation(.smooth(duration: 0.4), value: chargingLeft)
        .animation(.smooth(duration: 0.4), value: chargingRight)
    }
}
