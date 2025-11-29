import SwiftUI

enum BrandColor {
    static let ink = Color(hex: 0x0f1124)
    static let midnight = Color(hex: 0x171a33)
    static let orbit = Color(hex: 0x24305a)
    static let ion = Color(hex: 0x6cd6f5)
    static let ionStrong = Color(hex: 0x45c0eb)
    static let icing = Color(hex: 0xe7f7ff)
    static let flour = Color(hex: 0xffffff)

    static let mint = Color(hex: 0x66f2c1)
    static let berry = Color(hex: 0xff6f91)
    static let citrus = Color(hex: 0xffb347)
}

enum BrandRadius {
    static let xl: CGFloat = 16
    static let lg: CGFloat = 14
    static let md: CGFloat = 12
    static let sm: CGFloat = 10
    static let xs: CGFloat = 8
}

enum BrandShadow {
    // Glows removed per design request; keep soft shadow minimal if needed.
    static let glow = Shadow(color: .clear, radius: 0, y: 0)
    static let soft = Shadow(color: BrandColor.orbit.opacity(0.15), radius: 6, y: 2)

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat = 0
        let y: CGFloat
    }
}

extension BrandShadow.Shadow {
    static var soft: BrandShadow.Shadow { BrandShadow.soft }
    static var glow: BrandShadow.Shadow { BrandShadow.glow }
}

enum BrandFont {
    static func display(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func brandPanel(cornerRadius: CGFloat = BrandRadius.lg) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(BrandColor.midnight.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(BrandColor.orbit.opacity(0.35), lineWidth: 1.25)
        )
    }

    func brandCard(cornerRadius: CGFloat = BrandRadius.md) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(BrandColor.midnight.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(BrandColor.orbit.opacity(0.35), lineWidth: 1.1)
        )
    }

    func brandPill(active: Bool) -> some View {
        background(
            Capsule(style: .continuous)
                .fill(active ? BrandColor.ion.opacity(0.12) : BrandColor.midnight.opacity(0.8))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(active ? BrandColor.ion.opacity(0.85) : BrandColor.orbit.opacity(0.55), lineWidth: active ? 1.4 : 1)
        )
    }

    func brandFocus(cornerRadius: CGFloat = BrandRadius.md) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(BrandColor.ion.opacity(0.55), lineWidth: 2)
        )
    }

    func brandShadow(_ shadow: BrandShadow.Shadow = BrandShadow.glow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension ButtonStyle where Self == BrandButtonStyle {
    static var brandPrimary: BrandButtonStyle { BrandButtonStyle(kind: .primary) }
    static var brandGhost: BrandButtonStyle { BrandButtonStyle(kind: .ghost) }
    static var brandDanger: BrandButtonStyle { BrandButtonStyle(kind: .danger) }
}

struct BrandButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case ghost
        case danger
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandFont.ui(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(background(configuration: configuration))
            .foregroundStyle(foreground)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor(configuration: configuration), lineWidth: 1.25)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return BrandColor.ink
        case .ghost: return BrandColor.flour
        case .danger: return BrandColor.flour
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return BrandColor.ionStrong.opacity(configuration.isPressed ? 0.9 : 0.7)
        case .ghost:
            return BrandColor.orbit.opacity(configuration.isPressed ? 0.7 : 0.5)
        case .danger:
            return BrandColor.berry.opacity(configuration.isPressed ? 0.9 : 0.75)
        }
    }

    private func background(configuration: Configuration) -> some View {
        switch kind {
        case .primary:
            return Capsule(style: .continuous)
                .fill(configuration.isPressed ? BrandColor.ionStrong : BrandColor.ion)
        case .ghost:
            return Capsule(style: .continuous)
                .fill(configuration.isPressed ? BrandColor.orbit.opacity(0.4) : BrandColor.midnight)
        case .danger:
            return Capsule(style: .continuous)
                .fill(configuration.isPressed ? BrandColor.berry.opacity(0.85) : BrandColor.berry.opacity(0.7))
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex & 0xff0000) >> 16) / 255.0
        let green = Double((hex & 0x00ff00) >> 8) / 255.0
        let blue = Double(hex & 0x0000ff) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
