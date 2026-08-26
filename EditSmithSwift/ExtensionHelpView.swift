import SwiftUI
import EditSmithCore

struct ExtensionHelpView: View {
    @State private var dryRun = ExtensionPreferences().dryRun
    @State private var snapshot = ExtensionPreferences().lastSnapshot
    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()

            Form {
                Section {
                    LabeledContent {
                        Button("Open Extensions Settings", systemImage: "arrow.up.forward.app") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                        }
                        .buttonStyle(.borderedProminent)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Enable the Xcode Extension")
                                    .font(.headline)
                                Text("Privacy & Security → Extensions → Xcode Source Editor")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "puzzlepiece.extension")
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Section {
                    Toggle("Dry Run in Xcode", isOn: $dryRun)
                        .onChange(of: dryRun) { _, value in var preferences = ExtensionPreferences(); preferences.dryRun = value }
                    Text("Run actions and save a before/after preview without modifying the Xcode buffer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let snapshot {
                        LabeledContent("Last Preview", value: snapshot.recipeName)
                        Text(snapshot.date, format: .dateTime.year().month().day().hour().minute())
                            .foregroundStyle(.secondary)
                        DiffView(before: snapshot.before, after: snapshot.after)
                            .frame(minHeight: 180, idealHeight: 230)
                        Label("Use Editor → EditSmith → Undo Last EditSmith Change to restore the saved buffer.", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Safe Changes", systemImage: "checkmark.shield")
                }

                Section {
                    providerRow("Apple On-Device", detail: "Private, offline, built into macOS 26+", icon: "apple.intelligence")
                    providerRow("Private Cloud Compute", detail: "macOS 27+ · Apple eligibility and entitlement required", icon: "cloud")
                    providerRow("Ollama / Local LLaMA", detail: "Connects to a model server you run on this Mac", icon: "server.rack")
                } header: {
                    Label("Model Providers", systemImage: "brain.head.profile")
                }

                Section {
                    Label("Recipes, fixtures, logs, and sample text remain on this Mac unless you explicitly choose a network-backed model provider.", systemImage: "hand.raised")
                    Text("JavaScript actions are sandboxed. Model actions receive only the selected text and the prompt template you configure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Privacy", systemImage: "lock.shield")
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 560, idealHeight: 680)
        .onAppear { snapshot = ExtensionPreferences().lastSnapshot }
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("EditSmith Settings")
                    .font(.title2.weight(.semibold))
                Text("Connect Xcode, protect edits, and choose how intelligent actions run.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }

    private func providerRow(_ title: String, detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
        }
    }
}
