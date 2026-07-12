//
//  DashboardViewModel.swift
//  FinanceTracker
//

import Foundation
import SwiftData
import Combine

 class DashboardViewModel: ObservableObject {
    @Published var categoryBreakdown: [CategorySpend] = []
    @Published var isLoading = false

    private let store: TransactionStore

    init(container: ModelContainer) {
        store = TransactionStore(modelContainer: container)
    }

    func loadCurrentMonth() async {
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        do {
            categoryBreakdown = try await store.monthlyBreakdown(month: month, year: year)
        } catch {
            categoryBreakdown = []
        }
    }

    var totalSpent: Decimal {
        categoryBreakdown.reduce(0) { $0 + $1.total }
    }
}
