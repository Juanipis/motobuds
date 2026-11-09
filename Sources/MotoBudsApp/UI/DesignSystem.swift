import SwiftUI

/// Sistema de diseño "Moto-style". No usa fuentes ni assets propietarios:
/// solo SF Pro con tracking + paleta inspirada en la app Moto.
public enum MotoColor {
    public static let bgDeep    = Color(red: 0.043, green: 0.043, blue: 0.060)   // #0B0B0F
    public static let bgCard    = Color(red: 0.110, green: 0.110, blue: 0.130)   // #1C1C21
    public static let bgCardAlt = Color(red: 0.150, green: 0.150, blue: 0.175)   // #26262C
    public static let accent    = Color(red: 0.882, green: 0.145, blue: 0.106)   // #E1251B (Motorola red)
    public static let accentSoft = Color(red: 0.882, green: 0.145, blue: 0.106).opacity(0.18)
    public static let textPrimary = Color(red: 0.96, green: 0.96, blue: 0.97)
    public static let textSecondary = Color(red: 0.62, green: 0.62, blue: 0.66)
    public static let separator = Color.white.opacity(0.06)
    public static let success = Color(red: 0.30, green: 0.78, blue: 0.49)
    public static let warning = Color(red: 0.98, green: 0.74, blue: 0.27)
}

public extension Font {
    static func motoTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func motoHeadline(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func motoBody(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func motoMono(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

public struct Card<Content: View>: View {
    let content: Content
    public init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MotoColor.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(MotoColor.separator, lineWidth: 1)
            )
    }
}

public struct PillButtonStyle: ButtonStyle {
    let selected: Bool
    public init(selected: Bool) { self.selected = selected }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.motoBody(12).weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? MotoColor.accent : MotoColor.bgCardAlt)
            )
            .foregroundStyle(selected ? Color.white : MotoColor.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
