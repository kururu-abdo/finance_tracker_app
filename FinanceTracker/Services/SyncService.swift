//
//  SyncService.swift
//  FinanceTracker
//
//  Offline-first sync engine.
//
//  Design:
//  1. Every local write sets syncState = .pendingCreate/.pendingUpdate/.pendingDelete
//     immediately and synchronously via SwiftData — the UI never waits on network.
//  2. This service runs on a background ModelActor context, walks pending
//     records, pushes them to Firestore, then flips syncState = .synced.
//  3. Last-write-wins on `updatedAt` for remote conflicts — simple and
//     predictable for a personal single-user finance app. A CRDT/vector-clock
//     approach would be overkill here since there's no real multi-writer case
//     outside of a user's own two devices.
//  4. Runs off the main actor entirely so large syncs never touch UI performance.
//
//  Requires: FirebaseFirestore
//

import Foundation
import SwiftData
import FirebaseFirestore
import Combine
@ModelActor
actor SyncActor {
    private var db: Firestore { Firestore.firestore() }

    func pushPendingTransactions(userID: String) async throws {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        let pending = try modelContext.fetch(descriptor)
        guard !pending.isEmpty else { return }

        let collection = db.collection("users").document(userID).collection("transactions")

        // Batch writes in chunks of 400 (Firestore batch limit is 500).
        for chunk in pending.chunked(into: 400) {
            let batch = db.batch()

            for tx in chunk {
                let docRef = tx.remoteID.map { collection.document($0) } ?? collection.document()

                switch tx.syncState {
                case .pendingDelete:
                    batch.deleteDocument(docRef)
                case .pendingCreate, .pendingUpdate:
                    batch.setData(tx.asFirestoreDictionary(), forDocument: docRef, merge: true)
                case .synced:
                    continue
                }

                // Stamp the remote id locally before commit so a retry
                // after partial failure doesn't create duplicate docs.
                if tx.remoteID == nil, tx.syncState != .pendingDelete {
                    tx.remoteID = docRef.documentID
                }
            }

            try await batch.commit()

            for tx in chunk {
                if tx.syncState == .pendingDelete {
                    modelContext.delete(tx)
                } else {
                    tx.syncState = .synced
                }
            }
            try modelContext.save()
        }
    }

    /// Pulls remote changes newer than the last known local timestamp and
    /// applies last-write-wins merge against local records.
    func pullRemoteChanges(userID: String, since: Date) async throws {
        let collection = db.collection("users").document(userID).collection("transactions")
        let snapshot = try await collection
            .whereField("updatedAt", isGreaterThan: since)
            .getDocuments()

        for doc in snapshot.documents {
            guard let remote = Transaction.fromFirestore(doc) else { continue }

            let remoteID = doc.documentID
            var descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.remoteID == remoteID }
            )
            descriptor.fetchLimit = 1

            if let existing = try modelContext.fetch(descriptor).first {
                // Last-write-wins: only overwrite if remote is newer.
                if remote.updatedAt > existing.updatedAt {
                    existing.amount = remote.amount
                    existing.note = remote.note
                    existing.date = remote.date
                    existing.updatedAt = remote.updatedAt
                    existing.syncState = .synced
                }
            } else {
                remote.remoteID = remoteID
                remote.syncState = .synced
                modelContext.insert(remote)
            }
        }
        try modelContext.save()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private extension Transaction {
    func asFirestoreDictionary() -> [String: Any] {
        [
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "currencyCode": currencyCode,
            "type": type.rawValue,
            "note": note,
            "date": Timestamp(date: date),
            "updatedAt": Timestamp(date: updatedAt),
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    static func fromFirestore(_ doc: QueryDocumentSnapshot) -> Transaction? {
        let data = doc.data()
        guard
            let amountValue = data["amount"] as? Double,
            let typeRaw = data["type"] as? String,
            let type = TransactionType(rawValue: typeRaw),
            let dateTS = data["date"] as? Timestamp,
            let updatedTS = data["updatedAt"] as? Timestamp
        else { return nil }

        let tx = Transaction(
            amount: Decimal(amountValue),
            currencyCode: data["currencyCode"] as? String ?? "USD",
            type: type,
            note: data["note"] as? String ?? "",
            date: dateTS.dateValue()
        )
        tx.updatedAt = updatedTS.dateValue()
        return tx
    }
}

/// Main-actor facing coordinator that owns scheduling (call this from a
/// background task / on foreground / after each local mutation batch).
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastSyncError: String?

    private var syncActor: SyncActor!

       init() {
           // 2. Safely initialize it immediately after super.init or inside setup
           self.syncActor = SyncActor(modelContainer: PersistenceController.shared.container)
       }
    func syncNow() async {
        guard let userID = FirebaseAuthService.shared.currentUserID else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await syncActor.pushPendingTransactions(userID: userID)
            
            // FIX: Fallback to Unix Epoch (1970) instead of Year 1 (.distantPast)
            let safeSyncAnchor = lastSyncedAt ?? Date(timeIntervalSince1970: 0)
            
            try await syncActor.pullRemoteChanges(
                userID: userID,
                since: safeSyncAnchor
            )
            
            lastSyncedAt = .now
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

}
