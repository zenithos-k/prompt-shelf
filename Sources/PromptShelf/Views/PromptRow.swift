import SwiftUI

struct PromptRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let prompt: PromptSnippet
    @ObservedObject var store: PromptStore
    let isReorderingEnabled: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var dragTranslation: CGFloat = 0

    private let rowHeight: CGFloat = 80
    private let rowSpacing: CGFloat = 9

    private var variableCount: Int {
        PromptTemplate.variables(in: prompt.body).count
    }

    private var preview: String {
        prompt.body.replacingOccurrences(of: "\n", with: " ")
    }

    private var isDragging: Bool {
        store.draggedPromptID == prompt.id
    }

    private var rowStride: CGFloat {
        rowHeight + rowSpacing
    }

    private var displayOffset: CGFloat {
        if isDragging {
            return dragTranslation
        }

        guard let origin = store.dragOriginIndex,
              let target = store.dragTargetIndex,
              let current = store.index(of: prompt.id) else {
            return 0
        }

        if origin < target, current > origin, current <= target {
            return -rowStride
        }
        if target < origin, current >= target, current < origin {
            return rowStride
        }
        return 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    isDragging
                        ? ShelfColors.azure
                        : Color.secondary.opacity(isHovering ? 0.82 : 0.48)
                )
                .frame(width: 24, height: 44)
                .background(
                    isDragging
                        ? ShelfColors.azure.opacity(0.12)
                        : (isHovering ? Color.primary.opacity(0.055) : .clear),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(Rectangle())
                .highPriorityGesture(
                    reorderGesture,
                    including: isReorderingEnabled ? .all : .none
                )
                .help(isReorderingEnabled ? "Drag to reorder" : "Clear search to reorder")

            Button(action: onCopy) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(prompt.title)
                            .font(.system(size: 13.25, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if variableCount > 0 {
                            Label("\(variableCount)", systemImage: "curlybraces")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ShelfColors.violet)
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ShelfColors.violet.opacity(0.11), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(ShelfColors.violet.opacity(0.2), lineWidth: 0.6)
                                }
                        }
                    }

                    Text(preview)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(variableCount > 0 ? "Fill variables and copy" : "Copy prompt")

            HStack(spacing: 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Color.primary.opacity(isHovering ? 0.045 : 0),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red.opacity(isHovering ? 0.88 : 0.68))
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(isHovering ? 0.075 : 0), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(isHovering ? 1 : 0.62)
        }
        .padding(.horizontal, 9)
        .frame(minHeight: rowHeight)
        .shelfCard(
            cornerRadius: 14,
            tint: colorScheme == .light ? ShelfColors.promptGold : ShelfColors.indigo,
            tintOpacity: colorScheme == .light ? 0.145 : nil,
            elevated: isHovering
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            ShelfColors.indigo.opacity(0.32),
                            ShelfColors.violet.opacity(0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 42)
                .padding(.leading, 1)
                .opacity(isHovering ? 1 : 0.34)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .offset(y: displayOffset)
        .scaleEffect(isDragging ? 1.018 : (isHovering ? 1.004 : 1))
        .opacity(isDragging ? 0.88 : 1)
        .shadow(
            color: isDragging ? ShelfColors.azure.opacity(0.2) : .clear,
            radius: isDragging ? 12 : 0,
            y: isDragging ? 6 : 0
        )
        .zIndex(isDragging ? 2 : 0)
        .animation(
            isDragging ? nil : .interactiveSpring(response: 0.2, dampingFraction: 0.9),
            value: store.dragTargetIndex
        )
        .onHover { hovering in
            guard !isDragging else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                guard isReorderingEnabled else { return }

                if !isDragging {
                    store.beginDragging(id: prompt.id)
                }
                dragTranslation = value.translation.height

                guard let dragOriginIndex = store.dragOriginIndex else { return }
                let indexOffset = Int((dragTranslation / rowStride).rounded())
                store.updateDragTarget(to: dragOriginIndex + indexOffset)
            }
            .onEnded { _ in
                guard isDragging else {
                    store.finishDragging()
                    return
                }

                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                    dragTranslation = 0
                    store.commitDragging()
                }
            }
    }
}
