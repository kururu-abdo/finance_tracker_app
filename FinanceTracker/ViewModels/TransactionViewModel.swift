//
//  TransactionViewModel.swift
//  FinanceTracker
//
//  Handles create/update/delete. Heavy aggregation work (monthly totals,
//  category breakdowns) is done with SwiftData's #Predicate + fetch on a
//  background context via ModelActor rather than pulling everything into
//  memory on the main thread, so large histories don't cause UI hitches.
//

import Foundation
import SwiftData
import Combine

@ModelActor
actor TransactionStore {
    func addTransaction(
        amount: Decimal,
        type: TransactionType,
        note: String,
        date: Date,
        categoryID: PersistentIdentifier?
    ) throws {
        var category: Category?
        if let categoryID {
            category = modelContext.model(for: categoryID) as? Category
        }
        let tx = Transaction(amount: amount, type: type, note: note, date: date, category: category)
        modelContext.insert(tx)
        try modelContext.save()
    }

    func delete(transactionID: PersistentIdentifier) throws {
        guard let tx = modelContext.model(for: transactionID) as? Transaction else { return }
        // Soft-delete via sync state so a remote copy gets cleaned up too;
        // the row is removed locally once the sync actor confirms deletion.
        tx.syncState = .pendingDelete
        tx.updatedAt = .now
        try modelContext.save()
    }

    /// Runs entirely off the main thread. Returns plain value types so the
    /// caller never has to reach back across actor boundaries into
    /// SwiftData model objects from the main actor.
    func monthlyBreakdown(month: Int, year: Int) throws -> [CategorySpend] {
        let calendar = Calendar.current
        guard
            let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else { return [] }
        let targetType = TransactionType.expense
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.date >= startOfMonth && tx.date < startOfNextMonth &&  tx.type == targetType
            }
        )

        let transactions = try modelContext.fetch(descriptor)

        var totals: [String: (name: String, colorHex: String, amount: Decimal)] = [:]
        for tx in transactions {
            let key = tx.category?.name ?? "Uncategorized"
            let colorHex = tx.category?.colorHex ?? "#8E8E93"
            let running = totals[key]?.amount ?? 0
            totals[key] = (key, colorHex, running + tx.amount)
        }

        return totals.values
            .map { CategorySpend(categoryName: $0.name, colorHex: $0.colorHex, total: $0.amount) }
            .sorted { $0.total > $1.total }
    }
}

/// Lightweight, Sendable value type for chart consumption — deliberately
/// not a SwiftData model so it can cross actor boundaries freely.
struct CategorySpend: Identifiable, Sendable {
    var id: String { categoryName }
    let categoryName: String
    let colorHex: String
    let total: Decimal
}

 class TransactionViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let store: TransactionStore

    init(container: ModelContainer) {
        store = TransactionStore(modelContainer: container)
    }

    func addTransaction(
        amount: Decimal,
        type: TransactionType,
        note: String,
        date: Date,
        category: Category?
    ) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.addTransaction(
                amount: amount,
                type: type,
                note: note,
                date: date,
                categoryID: category?.persistentModelID
            )
            // Fire-and-forget background sync; UI already reflects the
            // change locally via SwiftData's @Query auto-refresh.
            Task { await SyncService.shared.syncNow() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ transaction: Transaction) async {
        do {
            try await store.delete(transactionID: transaction.persistentModelID)
            Task { await SyncService.shared.syncNow() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
