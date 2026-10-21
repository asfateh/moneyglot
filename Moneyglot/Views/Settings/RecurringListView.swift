import SwiftData
import SwiftUI

struct RecurringListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyService.self) private var currency
    @Query(sort: \RecurringPayment.createdAt) private var schedules: [RecurringPayment]
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @State private var showingNew = false
    @State private var editing: RecurringPayment?

    private var monthlyCommitment: Decimal {
        schedules
            .map(\.snapshot)
            .filter { $0.isActive && $0.category.kind == .expense }
            .compactMap { currency.converter.convert($0.monthlyAmount, from: $0.currencyCode, to: reportCurrency) }
            .reduce(0, +)
    }

    var body: some View {
        List {
            if !schedules.isEmpty {
                Section {
                    LabeledContent("Monthly commitments") {
                        Text(monthlyCommitment.money(reportCurrency))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Active repeating expenses, converted to \(reportCurrency) and averaged per month.")
                }
            }

            ForEach(CategoryGroup.allCases) { group in
                let items = schedules.filter { $0.category.group == group }
                if !items.isEmpty {
                    Section(group.title) {
                        ForEach(items) { schedule in
                            Button { editing = schedule } label: {
                                RecurringRow(schedule: schedule)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(schedule) }
                            }
                            .swipeActions(edge: .leading) {
                                Button(
                                    schedule.isActive ? "Pause" : "Resume",
                                    systemImage: schedule.isActive ? "pause.fill" : "play.fill"
                                ) { toggle(schedule) }
                                    .tint(schedule.isActive ? .orange : .green)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if schedules.isEmpty {
                ContentUnavailableView {
                    Label("No repeating payments", systemImage: "repeat")
                } description: {
                    Text("Add your mortgage, car loan, insurance, bills or salary once — Moneyglot records them every period.")
                } actions: {
                    Button("Add repeating payment") { showingNew = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Repeating Payments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { showingNew = true }
            }
        }
        .sheet(isPresented: $showingNew) { EntryEditorView(presetRepeat: .monthly) }
        .sheet(item: $editing) { RecurringEditorView(schedule: $0) }
    }

    private func toggle(_ schedule: RecurringPayment) {
        if schedule.isActive {
            schedule.isActive = false
        } else {
            // Skip periods missed while paused instead of back-filling them.
            schedule.generatedCount = RecurringScheduler.firstUpcomingIndex(
                frequency: schedule.frequency,
                startDate: schedule.startDate,
                from: schedule.generatedCount,
                now: .now
            )
            schedule.isActive = true
            RecurringScheduler.materialize(schedule, in: modelContext)
        }
        try? modelContext.save()
    }

    private func delete(_ schedule: RecurringPayment) {
        modelContext.delete(schedule)
        try? modelContext.save()
    }
}

private struct RecurringRow: View {
    let schedule: RecurringPayment

    private var status: String {
        if !schedule.isActive { return "Paused" }
        guard let next = schedule.nextDueDate else { return "Finished" }
        return "\(schedule.frequency.title) · next \(next.formatted(.dateTime.month(.abbreviated).day()))"
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: schedule.category)
                .opacity(schedule.isActive ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.displayTitle).font(.body.weight(.medium))
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(schedule.amount.money(schedule.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(schedule.category.kind == .income ? Color.green : Color.primary)
        }
        .contentShape(.rect)
    }
}

/// Edits a schedule. Changes apply to future entries; entries already recorded stay as they were.
struct RecurringEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let schedule: RecurringPayment

    @State private var title: String
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var category: EntryCategory
    @State private var paymentMethod: PaymentMethod
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var note: String
    @State private var showingCurrencyPicker = false
    @State private var confirmingDelete = false

    init(schedule: RecurringPayment) {
        self.schedule = schedule
        _title = State(initialValue: schedule.title)
        _amountText = State(initialValue: AmountParser.editingText(for: schedule.amount))
        _currencyCode = State(initialValue: schedule.currencyCode)
        _category = State(initialValue: schedule.category)
        _paymentMethod = State(initialValue: schedule.paymentMethod)
        _hasEndDate = State(initialValue: schedule.endDate != nil)
        _endDate = State(initialValue: schedule.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
        _note = State(initialValue: schedule.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack(spacing: 12) {
                        Button { showingCurrencyPicker = true } label: { CurrencyChip(code: currencyCode) }
                            .buttonStyle(.borderless)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Category") {
                    CategoryGrid(kind: category.kind, selection: $category)
                }
                Section("Details") {
                    TextField("Description", text: $title)
                    if category.kind == .expense {
                        Picker("Paid with", selection: $paymentMethod) {
                            ForEach(PaymentMethod.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    }
                    LabeledContent("Repeats", value: schedule.frequency.title)
                    LabeledContent("Started", value: schedule.startDate.formatted(date: .abbreviated, time: .omitted))
                    Toggle("Has an end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, in: schedule.startDate..., displayedComponents: .date)
                    }
                    TextField("Note", text: $note, axis: .vertical)
                }
                Section {
                    Button("Delete schedule", role: .destructive) { confirmingDelete = true }
                } footer: {
                    Text("Entries already recorded stay in your history.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Repeating Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(AmountParser.parse(amountText) == nil)
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(selection: $currencyCode)
            }
            .confirmationDialog("Delete this repeating payment?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(schedule)
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let amount = AmountParser.parse(amountText) else { return }
        schedule.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        schedule.amount = amount
        schedule.currencyCode = currencyCode
        schedule.category = category
        schedule.paymentMethod = category.kind == .income ? .bankTransfer : paymentMethod
        schedule.endDate = hasEndDate ? endDate : nil
        schedule.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}
