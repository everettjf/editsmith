import SwiftUI
import UniformTypeIdentifiers
import EditSmithCore
#if canImport(FoundationModels)
import FoundationModels
#endif

struct RecipeWorkbench: View {
    @State private var library = RecipeLibrary()
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = RecipeArchiveDocument()
    @State private var isShowingAssistant = false

    var body: some View {
        @Bindable var library = library
        NavigationSplitView {
            CapabilitySidebar(library: library)
            .toolbar {
                Menu("Add Recipe", systemImage: "plus") {
                    Button("Blank JavaScript Recipe", action: library.addRecipe)
                    Section("Templates") { ForEach(RecipeTemplates.javascript) { template in Button(template.name) { library.addTemplate(template) } } }
                }
                Button("Delete Recipe", systemImage: "trash", role: .destructive, action: library.deleteSelection)
                    .disabled(library.selectedIndex.map { library.recipes[$0].kind == .builtin } ?? true)
                Menu("Library", systemImage: "ellipsis.circle") {
                    Button("Duplicate Action", systemImage: "plus.square.on.square", action: library.duplicateSelection)
                        .disabled(library.selectedIndex == nil)
                    Button("Copy Built-in as Script", systemImage: "doc.on.doc", action: library.copyBuiltinToScript)
                        .disabled(library.selectedIndex.map { library.recipes[$0].kind == .javascript } ?? true)
                    Divider()
                    Button("Import Actions…", systemImage: "square.and.arrow.down") { isImporting = true }
                    Button("Export User Actions…", systemImage: "square.and.arrow.up") {
                        guard let document = library.exportDocument() else { return }
                        exportDocument = document
                        isExporting = true
                    }
                }
#if canImport(FoundationModels)
                if #available(macOS 26.0, *) {
                    Button("Draft with Apple Intelligence", systemImage: "apple.intelligence") {
                        isShowingAssistant = true
                    }
                }
#endif
            }
        } detail: {
            if let index = library.selectedIndex {
                RecipeEditor(recipe: $library.recipes[index], library: library)
                    .id(library.recipes[index].id)
            } else {
                ContentUnavailableView("Select a recipe", systemImage: "curlybraces")
            }
        }
        .onChange(of: library.selection) { library.synchronizeTestSelection() }
        .alert("Recipe Error", isPresented: $library.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(library.errorMessage ?? "") }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): library.importArchive(from: url)
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "EditSmith Actions"
        ) { result in
            if case .failure(let error) = result { library.errorMessage = error.localizedDescription }
        }
#if canImport(FoundationModels)
        .sheet(isPresented: $isShowingAssistant) {
            if #available(macOS 26.0, *) {
                ActionDraftAssistantView { name, source, prompt in
                    library.addGeneratedDraft(name: name, source: source, prompt: prompt)
                    isShowingAssistant = false
                }
            }
        }
#endif
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private struct ActionDraftAssistantView: View {
    let onCreate: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Generated Action"
    @State private var prompt = ""
    @State private var draft = ""
    @State private var errorMessage: String?
    @State private var isGenerating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Draft an Action").font(.title2.bold())
            Text("Apple Intelligence creates JavaScript locally. The draft stays disabled until you test and enable it.")
                .foregroundStyle(.secondary)
            TextField("Action name", text: $name)
            TextField("Describe the text transformation", text: $prompt, axis: .vertical)
                .lineLimit(3...6)
            if !draft.isEmpty {
                TextEditor(text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .accessibilityLabel("Generated JavaScript draft")
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Generate") { generate() }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                Button("Create Disabled Draft") { onCreate(name, draft, prompt) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 420)
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let model = SystemLanguageModel.default
                guard model.isAvailable else {
                    throw ActionAssistantError.modelUnavailable
                }
                let session = LanguageModelSession(instructions: """
                    You create deterministic, local EditSmith JavaScript actions. Return only JavaScript source defining function transform(input) that returns a string. Do not use network, files, processes, imports, eval, or dynamic code generation.
                    """)
                let response = try await session.respond(to: prompt)
                draft = Self.cleaned(response.content)
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private static func cleaned(_ source: String) -> String {
        source
            .replacingOccurrences(of: "```javascript", with: "")
            .replacingOccurrences(of: "```js", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@available(macOS 26.0, *)
private enum ActionAssistantError: LocalizedError {
    case modelUnavailable
    var errorDescription: String? { "Apple Intelligence is not available on this Mac." }
}
#endif

struct RecipeArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data = Data()

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
