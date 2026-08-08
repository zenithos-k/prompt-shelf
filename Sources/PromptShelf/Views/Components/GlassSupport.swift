import SwiftUI

enum ShelfColors {
    static let cyan = Color(red: 0.18, green: 0.78, blue: 1.0)
    static let azure = Color(red: 0.08, green: 0.48, blue: 1.0)
    static let indigo = Color(red: 0.31, green: 0.34, blue: 0.98)
    static let violet = Color(red: 0.62, green: 0.34, blue: 1.0)
    static let promptGold = Color(red: 0.92, green: 0.69, blue: 0.22)
    static let paper = Color(red: 0.969, green: 0.957, blue: 0.929)
    static let sand = Color(red: 0.933, green: 0.918, blue: 0.875)
    static let warmWhite = Color(red: 1.0, green: 0.992, blue: 0.973)
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let warmLine = Color(red: 0.82, green: 0.79, blue: 0.73)
}

struct ShelfGlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if colorScheme == .light {
            content
                .background(
                    LinearGradient(
                        colors: [ShelfColors.warmWhite, ShelfColors.paper.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.96), ShelfColors.warmLine.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                }
        } else {
#if compiler(>=6.2) && canImport(SwiftUI, _version: 7.0)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                darkSurface(content, shape: shape)
            }
#else
            darkSurface(content, shape: shape)
#endif
        }
    }

    private func darkSurface(_ content: Content, shape: RoundedRectangle) -> some View {
        content
            .background(.thinMaterial, in: shape)
            .background(ShelfColors.azure.opacity(0.055), in: shape)
            .overlay {
                shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
            }
    }
}

extension View {
    func shelfGlassSurface(cornerRadius: CGFloat = 14) -> some View {
        modifier(ShelfGlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}

struct ShelfIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(colorScheme == .light ? ShelfColors.ink : Color.primary)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .shelfGlassSurface(cornerRadius: 9)
            .shadow(
                color: colorScheme == .light
                    ? ShelfColors.ink.opacity(0.07)
                    : ShelfColors.azure.opacity(0.08),
                radius: 5,
                y: 2
            )
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
        let resolvedTintOpacity = tintOpacity.map { opacity in
            min(1, opacity + (elevated ? 0.035 : 0))
        } ?? (elevated ? 0.105 : 0.052)

        if colorScheme == .light {
            content
                .background(
                    LinearGradient(
                        colors: [
                            ShelfColors.warmWhite,
                            tint.opacity(resolvedTintOpacity),
                            ShelfColors.paper.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.96),
                                tint.opacity(elevated ? 0.3 : 0.16),
                                ShelfColors.warmLine.opacity(0.46)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                }
                .shadow(
                    color: ShelfColors.ink.opacity(elevated ? 0.12 : 0.06),
                    radius: elevated ? 12 : 6,
                    y: elevated ? 6 : 3
                )
        } else {
            content
                .background(.thinMaterial, in: shape)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(elevated ? 0.09 : 0.055),
                            tint.opacity(resolvedTintOpacity),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.17),
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
                    color: tint.opacity(elevated ? 0.17 : 0.07),
                    radius: elevated ? 11 : 5,
                    y: elevated ? 5 : 2
                )
        }
    }
}

struct ShelfChromeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Color.black.opacity(0.07)
            } else {
                LinearGradient(
                    colors: [ShelfColors.warmWhite, ShelfColors.paper, ShelfColors.sand.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [ShelfColors.azure.opacity(0.065), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 250
                )

                RadialGradient(
                    colors: [ShelfColors.violet.opacity(0.04), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 210
                )
            }
        }
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
