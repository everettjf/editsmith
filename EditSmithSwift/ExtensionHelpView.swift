import SwiftUI
import EditSmithCore

struct ExtensionHelpView: View {
    @State private var dryRun = ExtensionPreferences().dryRun
    @State private var snapshot = ExtensionPreferences().lastSnapshot
    var body: some View {
        Form {
            Section("Enable EditSmith") {
                Text("Open System Settings → Privacy & Security → Extensions → Xcode Source Editor, then enable EditSmith.")
                Button("Open Extensions Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
            }
            Section("Safe Changes") {
                Toggle("Dry Run in Xcode", isOn: $dryRun).onChange(of: dryRun) { _, value in var preferences = ExtensionPreferences(); preferences.dryRun = value }
                Text("Dry Run executes the recipe and saves a before/after preview without modifying the Xcode buffer.")
                if let snapshot {
                    LabeledContent("Last Preview", value: snapshot.recipeName)
                    Text(snapshot.date.formatted(date: .abbreviated, time: .standard)).foregroundStyle(.secondary)
                    DiffView(before: snapshot.before, after: snapshot.after).frame(height: 180)
                    Text("Use Editor → EditSmith → Undo Last EditSmith Change to restore the saved buffer snapshot.").font(.caption)
                }
            }
            Section("Privacy") {
                Text("Recipes, fixtures, logs, and sample text stay on this Mac. JavaScript recipes receive only the text Xcode passes to the extension.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 720, height: 600)
        .onAppear { snapshot = ExtensionPreferences().lastSnapshot }
    }
}
