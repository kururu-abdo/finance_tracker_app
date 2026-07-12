//
//  PersistenceController.swift
//  FinanceTracker
//
//  Single place that owns the ModelContainer. Encrypts the store at rest
//  via file protection and seeds default categories on first launch.
//

import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([Transaction.self, Category.self, Budget.self])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
            // Local db lives in the app's default application-support store.
        )

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        applyFileProtection()
        seedDefaultCategoriesIfNeeded()
    }

    /// Local security requirement: mark the SQLite store file
    /// `.completeUntilFirstUserAuthentication` so it's encrypted on disk
    /// and unreadable before the device is first unlocked after boot.
    /// (Combined with the FaceID app-lock gate for in-session protection.)
    private func applyFileProtection() {
        guard let url = container.configurations.first?.url else { return }
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            guard fm.fileExists(atPath: path) else { continue }
            try? fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: path
            )
        }
    }

    private func seedDefaultCategoriesIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Category>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for category in Category.defaults {
            context.insert(category)
        }
        try? context.save()
    }
}
