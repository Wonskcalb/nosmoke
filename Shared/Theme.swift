import SwiftUI

enum Jardin {
    static let cream = Color(hex: 0xF4EFE6)
    static let ink = Color(hex: 0x2F3A2E)
    static let terra = Color(hex: 0xC47A57)
    static let paper = Color(hex: 0xFBF8F2)
    static let line = Color(hex: 0xD9D1C1)
    static let muted = Color(hex: 0x6E6A5E)

    // ponytail: New York stands in for the mockup's Fraunces; bundle Fraunces and swap here if the difference matters.
    static func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .serif) }
    static func serifItalic(_ size: CGFloat) -> Font { .system(size: size, design: .serif).italic() }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }

    static let outline: CGFloat = 2
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.6)
}

enum Theme {
    static let accent = Jardin.terra
    static let onAccent = Jardin.paper
    static let warn = Jardin.terra
    static let muted = Jardin.muted
    static let cardFill = Jardin.paper
    static let hairline = Jardin.line
    static let background = LinearGradient(colors: [Jardin.cream, Jardin.cream], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

extension View {
    func card() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline))
    }

    func screenBackground() -> some View { background(Jardin.cream.ignoresSafeArea()) }
    func themedForm() -> some View { scrollContentBackground(.hidden).screenBackground() }
    func bigNumber(_ size: CGFloat = 44) -> some View { font(Jardin.serif(size)).monospacedDigit() }
    func sectionLabel() -> some View { font(Jardin.sans(12, weight: .semibold)).tracking(1).textCase(.uppercase).foregroundStyle(Jardin.muted) }
    func hairline() -> some View { overlay(alignment: .bottom) { Rectangle().fill(Jardin.line).frame(height: 1) } }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).sectionLabel()
            content
        }
        .card()
    }
}

struct Ring: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle().stroke(Jardin.line, lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(max(progress, 0.01), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct DotsRow: View {
    let filled: Int
    let total: Int
    var tint: Color = Theme.accent

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 16), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle().fill(i < filled ? tint : Jardin.line).frame(width: 16, height: 16)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Jardin.sans(16, weight: .semibold))
            .foregroundStyle(Jardin.paper)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(Jardin.terra, in: Capsule())
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Jardin.sans(15, weight: .medium))
            .foregroundStyle(Jardin.ink)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .overlay(Capsule().strokeBorder(Jardin.line, lineWidth: 1.5))
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
    }
}

struct ChoiceChip: View {
    let title: String
    var icon: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(Jardin.sans(14, weight: .medium))
            .foregroundStyle(selected ? Jardin.paper : Jardin.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? Jardin.terra : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? .clear : Jardin.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
