import Foundation

/// Persists lightweight built-in settings in UserDefaults and user-authored scripts as files.
/// The file boundary lets the scripts directory move to an iCloud container later without
/// changing the rest of the app or the Xcode extension.
public struct RecipeStore {
    public static let suiteName = "group.com.xnu.editsmith"

    private static let legacyKey = "swift.recipes.v2"
    private static let builtinKey = "swift.builtinRecipes.v3"
    private static let customOrderKey = "swift.customRecipeOrder.v1"
    private static let catalogVersionKey = "swift.capabilityCatalogVersion"
    private static let currentCatalogVersion = 3
    private static let scriptsDirectoryName = "Scripts"
    private static let scriptExtension = "editsmith-script"

    private let defaults: UserDefaults
    private let scriptsDirectoryURL: URL
    private let fileManager: FileManager

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: Self.suiteName),
        scriptsDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults ?? .standard
        self.fileManager = fileManager
        self.scriptsDirectoryURL = scriptsDirectoryURL
            ?? Self.defaultScriptsDirectory(fileManager: fileManager)
    }

    public func load() -> [Recipe] {
        migrateLegacyStorageIfNeeded()

        let savedBuiltins = defaults.data(forKey: Self.builtinKey)
            .flatMap { try? JSONDecoder().decode([Recipe].self, from: $0) }
            ?? []
        let customRecipes = orderedCustomRecipes(loadCustomRecipes())
        return mergeCatalog(with: savedBuiltins) + customRecipes
    }

    public func save(_ recipes: [Recipe]) throws {
        let customRecipes = recipes.filter { $0.kind == .javascript }
        try saveCustomRecipes(customRecipes)
        defaults.set(customRecipes.map(\.id), forKey: Self.customOrderKey)

        let builtins = recipes.filter { $0.kind != .javascript }
        defaults.set(try JSONEncoder().encode(builtins), forKey: Self.builtinKey)
        defaults.set(Self.currentCatalogVersion, forKey: Self.catalogVersionKey)
    }

    private static func defaultScriptsDirectory(fileManager: FileManager) -> URL {
        if let groupContainer = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) {
            return groupContainer.appending(path: scriptsDirectoryName, directoryHint: .isDirectory)
        }

        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appending(path: "EditSmith", directoryHint: .isDirectory)
            .appending(path: scriptsDirectoryName, directoryHint: .isDirectory)
    }

    private func mergeCatalog(with saved: [Recipe]) -> [Recipe] {
        let isUpgrading = defaults.integer(forKey: Self.catalogVersionKey) < Self.currentCatalogVersion
        let savedByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        return BuiltinRecipes.all.map { catalogRecipe in
            guard let existing = savedByID[catalogRecipe.id] else { return catalogRecipe }
            var merged = catalogRecipe
            if !isUpgrading { merged.isEnabled = existing.isEnabled }
            merged.isFavorite = existing.isFavorite
            merged.keyboardShortcut = existing.keyboardShortcut
            merged.parameters.merge(existing.parameters) { _, savedValue in savedValue }
            return merged
        }
    }

    private func loadCustomRecipes() -> [Recipe] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: scriptsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == Self.scriptExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let recipe = try? JSONDecoder().decode(Recipe.self, from: data),
                      recipe.kind == .javascript else { return nil }
                return recipe
            }
    }

    private func orderedCustomRecipes(_ recipes: [Recipe]) -> [Recipe] {
        let order = defaults.stringArray(forKey: Self.customOrderKey) ?? []
        let positions = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return recipes.sorted {
            (positions[$0.id] ?? .max, $0.name, $0.id)
                < (positions[$1.id] ?? .max, $1.name, $1.id)
        }
    }

    private func saveCustomRecipes(_ recipes: [Recipe]) throws {
        try fileManager.createDirectory(
            at: scriptsDirectoryURL,
            withIntermediateDirectories: true
        )

        let desiredFileNames = Set(recipes.map { scriptURL(for: $0).lastPathComponent })
        for recipe in recipes {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(recipe).write(to: scriptURL(for: recipe), options: .atomic)
        }

        let existingURLs = try fileManager.contentsOfDirectory(
            at: scriptsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == Self.scriptExtension }
        for staleURL in existingURLs where !desiredFileNames.contains(staleURL.lastPathComponent) {
            try fileManager.removeItem(at: staleURL)
        }
    }

    private func scriptURL(for recipe: Recipe) -> URL {
        let safeID = Data(recipe.id.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return scriptsDirectoryURL
            .appending(path: safeID)
            .appendingPathExtension(Self.scriptExtension)
    }

    private func migrateLegacyStorageIfNeeded() {
        guard defaults.data(forKey: Self.builtinKey) == nil,
              let legacyData = defaults.data(forKey: Self.legacyKey),
              let legacyRecipes = try? JSONDecoder().decode([Recipe].self, from: legacyData)
        else { return }

        do {
            let catalogIDs = Set(BuiltinRecipes.all.map(\.id))
            let customRecipes = legacyRecipes.filter {
                $0.kind == .javascript && !catalogIDs.contains($0.id)
            }
            if loadCustomRecipes().isEmpty {
                try saveCustomRecipes(customRecipes)
            }
            defaults.set(customRecipes.map(\.id), forKey: Self.customOrderKey)
            let builtins = legacyRecipes.filter { catalogIDs.contains($0.id) }
            defaults.set(try JSONEncoder().encode(builtins), forKey: Self.builtinKey)
            defaults.set(Self.currentCatalogVersion, forKey: Self.catalogVersionKey)
            defaults.removeObject(forKey: Self.legacyKey)
        } catch {
            // Keep the legacy payload intact so a later launch can retry without data loss.
        }
    }
}
