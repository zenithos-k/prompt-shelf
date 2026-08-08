import SwiftUI
import UniformTypeIdentifiers

struct PromptRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let prompt: PromptSnippet
    @ObservedObject var store: PromptStore
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var showsDeleteConfirmation = false

    private let rowHeight: CGFloat = 80

    private var variableCount: Int {
        PromptTemplate.variables(in: prompt.body).count
    }

    private var preview: String {
        prompt.body.replacingOccurrences(of: "\n", with: " ")
    }

    private var isDragging: Bool {
        store.draggedPromptID == prompt.id
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(isHovering ? 0.82 : 0.48))
                .frame(width: 24, height: 44)
                .background(
                    isHovering ? Color.primary.opacity(0.055) : .clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(Rectangle())
                .help("Drag to reorder")

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

                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
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
            tintOpacity: colorScheme == .light ? 0.115 : nil,
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
        .onDrag {
            store.beginDragging(id: prompt.id)
            return NSItemProvider(object: prompt.id.uuidString as NSString)
        } preview: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                Text(prompt.title)
                    .lineLimit(1)
            }
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
        }
        .scaleEffect(isDragging ? 0.985 : (isHovering ? 1.004 : 1))
        .opacity(isDragging ? 0.62 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        .onDrop(
            of: [UTType.text],
            delegate: PromptDropDelegate(target: prompt, rowHeight: rowHeight, store: store)
        )
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .alert(prompt.title, isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
