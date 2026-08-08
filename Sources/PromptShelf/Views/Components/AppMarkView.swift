import SwiftUI

struct AppMarkView: View {
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ShelfColors.cyan, ShelfColors.azure, ShelfColors.violet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear, .black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: size * 0.065) {
                HStack(spacing: size * 0.035) {
                    Image(systemName: "quote.opening")
                    Image(systemName: "quote.opening")
                }
                .font(.system(size: size * 0.25, weight: .heavy))

                VStack(spacing: size * 0.055) {
                    Capsule().frame(width: size * 0.48, height: size * 0.055)
                    Capsule().frame(width: size * 0.39, height: size * 0.055)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .blue.opacity(0.45), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
        }
        .shadow(color: ShelfColors.azure.opacity(0.28), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}
