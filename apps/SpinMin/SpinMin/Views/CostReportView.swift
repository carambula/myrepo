//
//  CostReportView.swift
//  SpinMin
//
//  Maintenance spending report: yearly totals, category breakdown,
//  and cost per kilometer
//

import SwiftUI
import SwiftData
import Charts

struct CostReportView: View {
    let bike: BikeConfiguration
    
    private var recordsWithCost: [MaintenanceRecord] {
        bike.maintenanceRecords.filter { ($0.cost ?? 0) > 0 }
    }
    
    private var totalSpent: Double {
        recordsWithCost.reduce(0) { $0 + ($1.cost ?? 0) }
    }
    
    private var thisYearSpent: Double {
        let year = Calendar.current.component(.year, from: Date())
        return recordsWithCost
            .filter { Calendar.current.component(.year, from: $0.maintenanceDate) == year }
            .reduce(0) { $0 + ($1.cost ?? 0) }
    }
    
    private var costPerKm: Double? {
        guard bike.totalMileageKm > 0, totalSpent > 0 else { return nil }
        return totalSpent / bike.totalMileageKm
    }
    
    /// Spend aggregated by calendar year
    private var yearlySpend: [(year: Int, total: Double)] {
        let grouped = Dictionary(grouping: recordsWithCost) {
            Calendar.current.component(.year, from: $0.maintenanceDate)
        }
        return grouped
            .map { (year: $0.key, total: $0.value.reduce(0) { $0 + ($1.cost ?? 0) }) }
            .sorted { $0.year < $1.year }
    }
    
    /// Spend aggregated by maintenance category
    private var categorySpend: [(category: MaintenanceCategory, total: Double)] {
        let grouped = Dictionary(grouping: recordsWithCost) { $0.type.category }
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + ($1.cost ?? 0) }) }
            .sorted { $0.total > $1.total }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                if recordsWithCost.isEmpty {
                    ContentUnavailableView(
                        "No Costs Recorded",
                        systemImage: "dollarsign.circle",
                        description: Text("Add costs when logging maintenance to build your spending report.")
                    )
                    .padding(.top, DesignSystem.Spacing.xxl)
                } else {
                    summaryCards
                    yearlyChart
                    categoryBreakdown
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Color.background)
        .navigationTitle("Spending")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Summary
    
    private var summaryCards: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            summaryCard(title: "All Time", value: currency(totalSpent))
            summaryCard(title: "This Year", value: currency(thisYearSpent))
            if let perKm = costPerKm {
                summaryCard(title: "Per km", value: currency(perKm, precision: 2))
            }
        }
    }
    
    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .captionMedium()
                .foregroundStyle(.secondary)
            Text(value)
                .bodyLarge()
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }
    
    // MARK: - Yearly Chart
    
    private var yearlyChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("By Year")
                .h3()
            
            Chart(yearlySpend, id: \.year) { entry in
                BarMark(
                    x: .value("Year", String(entry.year)),
                    y: .value("Spend", entry.total)
                )
                .foregroundStyle(DesignSystem.Color.accent)
                .cornerRadius(DesignSystem.CornerRadius.xs)
            }
            .frame(height: 180)
        }
    }
    
    // MARK: - Category Breakdown
    
    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("By Category")
                .h3()
            
            VStack(spacing: 0) {
                ForEach(categorySpend, id: \.category) { entry in
                    HStack {
                        Text(entry.category.displayName)
                            .bodyMedium()
                        Spacer()
                        Text(currency(entry.total))
                            .bodyMedium()
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    
                    if entry.category != categorySpend.last?.category {
                        Divider()
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        }
    }
    
    // MARK: - Formatting
    
    private func currency(_ value: Double, precision: Int = 0) -> String {
        value.formatted(
            .currency(code: Locale.current.currency?.identifier ?? "USD")
            .precision(.fractionLength(precision))
        )
    }
}
