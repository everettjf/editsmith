import SwiftUI
import CodeEditor

/// EditSmith's thin presentation layer around ZeeZide/CodeEditor.
/// Syntax highlighting, smart indentation, pairing, selection, and undo are
/// owned by the package rather than reimplemented in this project.
struct SourceEditorPane: View {
    let title: String
    @Binding var text: String
    let isEditable: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var fontSize: CGFloat = 13

    private var lineCount: Int {
        text.isEmpty ? 1 : text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: "curlybraces")
                    .font(.headline)
                Spacer()
                Text("JavaScript")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(lineCount) lines · \(text.utf8.count) bytes")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            CodeEditor(
                source: $text,
                language: .javascript,
                theme: colorScheme == .dark ? .atelierSavannaDark : .atelierSavannaLight,
                fontSize: $fontSize,
                flags: isEditable ? .defaultEditorFlags : .defaultViewerFlags,
                indentStyle: .softTab(width: 2),
                allowsUndo: true
            )
            .accessibilityLabel(title)
        }
        .background(.background)
        .clipShape(.rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
    }
}
