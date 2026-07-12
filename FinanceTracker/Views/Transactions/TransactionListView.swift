//
//  TransactionListView.swift
//  FinanceTracker
//
//  Uses SwiftData's @Query so the list updates automatically whenever
//  the background sync actor or a local write touches the store —
//  no manual refresh plumbing needed.
//

import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @StateObject private var viewModel: TransactionViewModel
    @State private var showingAddSheet = false

    init(container: ModelContainer) {
        _viewModel = StateObject(wrappedValue: TransactionViewModel(container: container))
    }

    var body: some View {
        List {
            ForEach(groupedByDay, id: \.key) { day, items in
                Section(day.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(items) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                    .onDelete { offsets in
                        Task {
                            for index in offsets {
                                await viewModel.delete(items[index])
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Transactions")
        .overlay {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to add your first one.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionView(viewModel: viewModel)
        }
    }

    private var groupedByDay: [(key: Date, value: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.category?.iconSystemName ?? "questionmark.circle")
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(transaction.category?.color ?? .gray)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category?.name ?? "Uncategorized")
                    .font(.body)
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(transaction.signedAmount, format: .currency(code: transaction.currencyCode))
                .foregroundStyle(transaction.type == .expense ? .primary : .green)
                .monospacedDigit()

            // Subtle sync indicator — useful for debugging + shows the
            // offline-first state honestly to the user.
            if transaction.syncState != .synced {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
