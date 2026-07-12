//
//  Transaction.swift
//  FinanceTracker
//
//  Core SwiftData model. This is the single source of truth on-device.
//  Firestore is treated as a sync target, not the source of truth —
//  the app must work fully offline.
//

import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case expense
    case income
}

/// Sync state lets us do offline-first writes: every local mutation is
/// immediately durable via SwiftData, and a background sync engine later
/// reconciles with Firestore. The UI never blocks on network state.
enum SyncState: String, Codable {
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
}

@Model
final class Transaction {
    // Local, stable identity — used as the SwiftData primary handle.
    @Attribute(.unique) var id: UUID

    // Firestore document id, set once the first sync succeeds. Nil while
    // the record exists only locally.
    var remoteID: String?

    var amount: Decimal
    var currencyCode: String
    var type: TransactionType
    var note: String
    var date: Date

    var createdAt: Date
    var updatedAt: Date

    // Relationship kept optional + nullify so deleting a category never
    // cascades into destroying transaction history.
    @Relationship(deleteRule: .nullify, inverse: \Category.transactions)
    var category: Category?

    var syncStateRaw: String
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingCreate }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        type: TransactionType,
        note: String = "",
        date: Date = .now,
        category: Category? = nil
    ) {
        self.id = id
        self.remoteID = nil
        self.amount = amount
        self.currencyCode = currencyCode
        self.type = type
        self.note = note
        self.date = date
        self.createdAt = .now
        self.updatedAt = .now
        self.category = category
        self.syncStateRaw = SyncState.pendingCreate.rawValue
    }
}

extension Transaction {
    /// Signed amount for chart math: expenses negative, income positive.
    var signedAmount: Decimal {
        type == .expense ? -amount : amount
    }
}
