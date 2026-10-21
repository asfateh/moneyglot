import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(CurrencyService.self) private var currency
    @Environment(StoreManager.self) private var store
    @Environment(AIAdvisor.self) private var advisor
    @Query private var entries: [Entry]
    @Query private var schedules: [RecurringPayment]
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @State private var showingPaywall = false

    var body: some View {
        let engine = InsightsEngine(converter: currency.converter)
        let snapshots = entries.map(\.snapshot)
        let readiness = engine.readiness(snapshots)
        let financials = engine.snapshot(entries: snapshots, recurring: schedules.map(\.snapshot), currency: reportCurrency)
        let insights = readiness.isReady ? engine.insights(for: financials) : []

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.hasPro {
                        if readiness.isReady {
                            AICoachCard(financials: financials, insights: insights)
                            if !insights.isEmpty {
                                Text("Smart insights · \(financials.periodLabel)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                            ForEach(insights) { InsightCard(insight: $0, currency: reportCurrency) }
                        } else {
                            ReadinessCard(readiness: readiness)
                        }
                    } else {
                        ProTeaser(readiness: readiness, insights: insights, currency: reportCurrency) {
                            showingPaywall = true
                        }
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Insights")
            .toolbar {
                if store.hasPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("PRO")
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.brandGradient, in: .capsule)
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }
}

private struct AICoachCard: View {
    let financials: FinancialSnapshot
    let insights: [Insight]
    @Environment(AIAdvisor.self) private var advisor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Theme.brandGradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your AI savings plan").font(.headline)
                    Text("Private, on-device Apple Intelligence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            switch advisor.status {
            case .available:
                if let plan = advisor.plan, plan.currency == financials.currency {
                    planContent(plan)
                } else {
                    Text("Get 3–5 personal suggestions based on your last \(financials.monthsAnalyzed) month\(financials.monthsAnalyzed == 1 ? "" : "s") of income and spending.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                generateButton
                if let error = advisor.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            case .unavailable(let reason):
                Label(reason, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Suggestions are for information only and aren't financial advice.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .card()
    }

    private var generateButton: some View {
        Button {
            Task { await advisor.generatePlan(from: financials, insights: insights) }
        } label: {
            HStack {
                if advisor.isGenerating {
                    ProgressView().tint(.white)
                    Text("Thinking…")
                } else {
                    Image(systemName: advisor.plan == nil ? "wand.and.stars" : "arrow.clockwise")
                    Text(advisor.plan == nil ? "Create my plan" : "Refresh plan")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(advisor.isGenerating)
    }

    private func planContent(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(plan.overview).font(.subheadline)
            ForEach(Array(plan.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Theme.teal.opacity(0.15), in: .circle)
                        .foregroundStyle(Theme.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title).font(.subheadline.weight(.semibold))
                        Text(suggestion.detail).font(.footnote).foregroundStyle(.secondary)
                        if suggestion.monthlySavings >= 1 {
                            SavingsBadge(text: "Save ~\(Decimal(suggestion.monthlySavings).wholeMoney(plan.currency))/mo")
                        }
                    }
                }
            }
            Text("Created \(plan.generatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

struct InsightCard: View {
    let insight: Insight
    let currency: String

    private var tint: Color {
        switch insight.tone {
        case .warning: .orange
        case .tip: .blue
        case .positive: .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: insight.symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title).font(.subheadline.weight(.semibold))
                Text(insight.message).font(.footnote).foregroundStyle(.secondary)
                if let savings = insight.monthlySavings, savings >= 1 {
                    SavingsBadge(text: "Potential: \(savings.wholeMoney(currency))/mo")
                }
            }
        }
        .card()
    }
}

private struct SavingsBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15), in: .capsule)
            .foregroundStyle(.green)
    }
}

private struct ReadinessCard: View {
    let readiness: DataReadiness

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Building your picture", systemImage: "hourglass")
                .font(.headline)
            ProgressView(value: readiness.progress)
                .tint(Theme.teal)
            Text(readiness.remainingDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(readiness.entryCount) entries · \(readiness.daysCovered) days of history")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}

private struct ProTeaser: View {
    let readiness: DataReadiness
    let insights: [Insight]
    let currency: String
    let onUpgrade: () -> Void
    @Environment(StoreManager.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                Text("Your AI money coach")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Moneyglot Pro studies your income, loans, bills and spending — in every currency — and shows you exactly where to save.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                Button(action: onUpgrade) {
                    Text(trialButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: .rect(cornerRadius: 14))
                        .foregroundStyle(Theme.indigo)
                }
                .buttonStyle(.plain)
                if let price = store.proProduct?.displayPrice {
                    Text("Then \(price)/month. Cancel anytime.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.brandGradient, in: .rect(cornerRadius: 24))

            if readiness.isReady, let first = insights.first {
                Text("We found \(insights.count) insight\(insights.count == 1 ? "" : "s") in your data")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                InsightCard(insight: first, currency: currency)
                ForEach(insights.dropFirst().prefix(2)) { insight in
                    InsightCard(insight: insight, currency: currency)
                        .redacted(reason: .placeholder)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Locked insight. Upgrade to Pro to see it.")
                }
            } else {
                ReadinessCard(readiness: readiness)
            }

            VStack(alignment: .leading, spacing: 14) {
                Feature(symbol: "wand.and.stars", title: "Personal AI savings plan", detail: "Generated privately on your iPhone.")
                Feature(symbol: "chart.line.uptrend.xyaxis", title: "Spending spikes & trends", detail: "Know when a category jumps.")
                Feature(symbol: "building.columns.fill", title: "Debt & housing checks", detail: "Mortgage, loans and cards vs. income.")
                Feature(symbol: "globe", title: "Foreign-fee alerts", detail: "See what card FX fees cost you.")
            }
            .card()
        }
    }

    private var trialButtonTitle: String {
        store.proProduct?.subscription?.introductoryOffer != nil ? "Start free trial" : "Unlock Moneyglot Pro"
    }
}

private struct Feature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.teal)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
