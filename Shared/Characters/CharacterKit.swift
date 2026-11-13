import SwiftUI

struct ReplayOnTap: ViewModifier {
    let autoplay: Bool
    @Binding var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var played = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { trigger += 1 }
            .onAppear {
                guard autoplay, !played, !reduceMotion else { return }
                played = true
                trigger += 1
            }
    }
}

extension View {
    func replayOnTap(autoplay: Bool, trigger: Binding<Int>) -> some View {
        modifier(ReplayOnTap(autoplay: autoplay, trigger: trigger))
    }
}

/// The mockups draw every character in an SVG viewBox; this maps those coordinates onto the view.
struct ViewBox {
    let width: CGFloat
    let height: CGFloat

    func scale(in size: CGSize) -> CGFloat { min(size.width / width, size.height / height) }

    func transform(in size: CGSize) -> CGAffineTransform {
        let s = scale(in: size)
        return CGAffineTransform(translationX: (size.width - width * s) / 2, y: (size.height - height * s) / 2).scaledBy(x: s, y: s)
    }
}
