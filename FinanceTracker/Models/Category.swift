//
//  Category.swift
//  FinanceTracker
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var remoteID: String?

    var name: String
    var iconSystemName: String
    var colorHex: String
    var monthlyBudgetLimit: Decimal?

    var syncStateRaw: String
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingCreate }
        set { syncStateRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .nullify)
    var transactions: [Transaction]?

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String = "circle.fill",
        colorHex: String = "#4F8EF7",
        monthlyBudgetLimit: Decimal? = nil
    ) {
        self.id = id
        self.remoteID = nil
        self.name = name
        self.iconSystemName = iconSystemName
        self.colorHex = colorHex
        self.monthlyBudgetLimit = monthlyBudgetLimit
        self.syncStateRaw = SyncState.pendingCreate.rawValue
    }

    var color: Color {
        Color(hex: colorHex)
    }

    static let defaults: [Category] = [
        Category(name: "Groceries", iconSystemName: "cart.fill", colorHex: "#34C759"),
        Category(name: "Transport", iconSystemName: "car.fill", colorHex: "#FF9500"),
        Category(name: "Housing", iconSystemName: "house.fill", colorHex: "#5856D6"),
        Category(name: "Entertainment", iconSystemName: "gamecontroller.fill", colorHex: "#FF2D55"),
        Category(name: "Health", iconSystemName: "cross.case.fill", colorHex: "#FF3B30"),
        Category(name: "Salary", iconSystemName: "banknote.fill", colorHex: "#30B0C7")
    ]
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
