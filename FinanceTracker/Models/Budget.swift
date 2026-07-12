//
//  Budget.swift
//  FinanceTracker
//

import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var remoteID: String?
    var month: Int
    var year: Int
    var totalLimit: Decimal
    var syncStateRaw: String

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingCreate }
        set { syncStateRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), month: Int, year: Int, totalLimit: Decimal) {
        self.id = id
        self.month = month
        self.year = year
        self.totalLimit = totalLimit
        self.syncStateRaw = SyncState.pendingCreate.rawValue
    }
}
