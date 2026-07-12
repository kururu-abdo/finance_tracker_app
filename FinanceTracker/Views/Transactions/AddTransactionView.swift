//
//  AddTransactionView.swift
//  FinanceTracker
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]

    @ObservedObject var viewModel: TransactionViewModel

    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var note = ""
    @State private var date = Date()
    @State private var selectedCategory: Category?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(Locale.current.currencySymbol ?? "$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(nil as Category?)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.iconSystemName)
                                .tag(category as Category?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || viewModel.isSaving)
                }
            }
        }
    }

    private var isValid: Bool {
        Decimal(string: amountText).map { $0 > 0 } ?? false
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        Task {
            await viewModel.addTransaction(
                amount: amount,
                type: type,
                note: note,
                date: date,
                category: selectedCategory
            )
            dismiss()
        }
    }
}
