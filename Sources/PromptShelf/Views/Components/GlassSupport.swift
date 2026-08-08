import SwiftUI

enum ShelfColors {
    static let cyan = Color(red: 0.18, green: 0.78, blue: 1.0)
    static let azure = Color(red: 0.08, green: 0.48, blue: 1.0)
    static let indigo = Color(red: 0.31, green: 0.34, blue: 0.98)
    static let violet = Color(red: 0.62, green: 0.34, blue: 1.0)
    static let promptGold = Color(red: 0.92, green: 0.69, blue: 0.22)
}

extension View {
    @ViewBuilder
    func shelfGlassSurface(cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

#if compiler(>=6.2) && canImport(SwiftUI, _version: 7.0)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.thinMaterial, in: shape)
                .background(ShelfColors.azure.opacity(0.055), in: shape)
                .overlay {
                    shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                }
        }
#else
        self
            .background(.thinMaterial, in: shape)
            .background(ShelfColors.azure.opacity(0.055), in: shape)
            .overlay {
                shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
            }
#endif
    }
}

struct ShelfIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .shelfGlassSurface(cornerRadius: 9)
            .shadow(color: ShelfColors.azure.opacity(0.08), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ShelfCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat = 12
    var tint: Color = ShelfColors.indigo
    var tintOpacity: Double?
    var elevated = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let topHighlight = colorScheme == .dark
            ? Color.white.opacity(elevated ? 0.09 : 0.055)
            : Color.white.opacity(elevated ? 0.92 : 0.76)
        let bottomShade = colorScheme == .dark
            ? Color.black.opacity(0.08)
            : Color.black.opacity(0.018)
        let resolvedTintOpacity = tintOpacity.map { opacity in
            min(1, opacity + (elevated ? 0.035 : 0))
        } ?? (elevated ? 0.105 : 0.052)

        content
            .background(.thinMaterial, in: shape)
            .background(
                LinearGradient(
                    colors: [topHighlight, tint.opacity(resolvedTintOpacity), bottomShade],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.17 : 0.78),
                            tint.opacity(elevated ? 0.34 : 0.16),
                            Color(nsColor: .separatorColor).opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.85
                )
            }
            .shadow(
                color: colorScheme == .dark
                    ? tint.opacity(elevated ? 0.17 : 0.07)
                    : Color.black.opacity(elevated ? 0.11 : 0.055),
                radius: elevated ? 11 : 5,
                y: elevated ? 5 : 2
            )
    }
}

extension View {
    func shelfCard(
        cornerRadius: CGFloat = 12,
        tint: Color = ShelfColors.indigo,
        tintOpacity: Double? = nil,
        elevated: Bool = false
    ) -> some View {
        modifier(
            ShelfCardModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                tintOpacity: tintOpacity,
                elevated: elevated
            )
        )
    }
}
