import SwiftUI

// Liquid Glass on iOS 26, material fallbacks below it.
extension View {
    @ViewBuilder func glassSurface(_ radius: CGFloat = 20) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }

    @ViewBuilder func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }

    @ViewBuilder func prominentGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

extension CardState.Status {
    var label: String {
        switch self {
        case .new: "New"
        case .learned: "Learned"
        case .learning: "Learning"
        case .hard: "Hard"
        case .missed: "Again"
        }
    }
    var color: Color {
        switch self {
        case .learned: .green
        case .learning: .mint
        case .hard: .orange
        case .missed: .red
        case .new: Color(.systemGray3)
        }
    }
}
