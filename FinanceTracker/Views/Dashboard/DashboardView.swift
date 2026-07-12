//
//  DashboardView.swift
//  FinanceTracker
//
//  Interactive donut + bar breakdown using Apple's native Charts framework.
//  Tapping/dragging over the donut highlights a category (gesture-driven
//  selection) — a common recruiter-facing "wow" detail for Charts.
//

import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var selectedCategory: String?
    @State private var selectedAngle: Double?

    init(container: ModelContainer) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(container: container))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if viewModel.categoryBreakdown.isEmpty {
                    emptyState
                } else {
                    donutChart
                    categoryList
                }
            }
            .padding()
        }
        .navigationTitle("This Month")
        .task { await viewModel.loadCurrentMonth() }
        .refreshable { await viewModel.loadCurrentMonth() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) { // Explicit spacing makes layout predictable
                Text(viewModel.totalSpent, format: .number) // Ensures localized digit shapes
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                
                Image("SAR")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
            }
            .environment(\.layoutDirection, .rightToLeft) // Use this line ONLY to force test RTL

            
            
            
        }
    }

    private var donutChart: some View {
        Chart(viewModel.categoryBreakdown) { item in
            SectorMark(
                angle: .value("Amount", NSDecimalNumber(decimal: item.total).doubleValue),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: item.colorHex))
            .opacity(selectedCategory == nil || selectedCategory == item.categoryName ? 1 : 0.3)
            .cornerRadius(4)
        }
        .frame(height: 240)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, newAngle in
            guard let newAngle else {
                selectedCategory = nil
                return
            }
            // Walk the cumulative angle ranges to find which sector the
            // gesture landed on, since SectorMark selection gives us a
            // raw angle value rather than the category directly.
            var cumulative: Double = 0
            for item in viewModel.categoryBreakdown {
                let value = NSDecimalNumber(decimal: item.total).doubleValue
                cumulative += value
                if newAngle <= cumulative {
                    withAnimation(.snappy) { selectedCategory = item.categoryName }
                    break
                }
            }
        }
        .chartBackground { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame {
                    let frame = geo[plotFrame]
                    VStack(spacing: 2) {
                        Text(selectedCategory ?? "All Categories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let selected = viewModel.categoryBreakdown.first(where: { $0.categoryName == selectedCategory }) {
                            Text(selected.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.headline)
                        }
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .accessibilityLabel("Spending breakdown by category")
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.categoryBreakdown) { item in
                Button {
                    withAnimation(.snappy) {
                        selectedCategory = (selectedCategory == item.categoryName) ? nil : item.categoryName
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: item.colorHex))
                            .frame(width: 10, height: 10)
                        Text(item.categoryName)
                            .foregroundStyle(.primary)
                        Spacer()
                        
                       
                        Text(item.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        
                        
                        
                        
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if item.id != viewModel.categoryBreakdown.last?.id {
                    Divider()
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Spending Yet",
            systemImage: "chart.pie",
            description: Text("Add a transaction to see your monthly breakdown.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
