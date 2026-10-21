import SwiftData
import SwiftUI

/// Add or edit an entry. New entries can repeat, which creates a `RecurringPayment` schedule.
struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyService.self) private var currency
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @AppStorage(SettingsKey.lastEntryCurrency) private var lastEntryCurrency = ""

    private let entry: Entry?

    @State private var kind: EntryKind
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var title: String
    @State private var category: EntryCategory
    @State private var date: Date
    @State private var paymentMethod: PaymentMethod
    @State private var note: String
    @State private var repeatFrequency: Frequency?
    @State private var hasEndDate = false
    @State private var endDate: Date
    @State private var showingCurrencyPicker = false
    @FocusState private var amountFocused: Bool

    init(entry: Entry? = nil, presetRepeat: Frequency? = nil) {
        self.entry = entry
        let defaults = UserDefaults.standard
        let defaultCurrency = [SettingsKey.lastEntryCurrency, SettingsKey.reportCurrency]
            .compactMap { defaults.string(forKey: $0) }
            .first { !$0.isEmpty } ?? CurrencyCatalog.deviceCurrency

        _kind = State(initialValue: entry?.kind ?? .expense)
        _amountText = State(initialValue: entry.map { AmountParser.editingText(for: $0.amount) } ?? "")
        _currencyCode = State(initialValue: entry?.currencyCode ?? defaultCurrency)
        _title = State(initialValue: entry?.title ?? "")
        _category = State(initialValue: entry?.category ?? .otherExpense)
        _date = State(initialValue: entry?.date ?? .now)
        _paymentMethod = State(initialValue: entry?.paymentMethod ?? .debitCard)
        _note = State(initialValue: entry?.note ?? "")
        _repeatFrequency = State(initialValue: presetRepeat)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
    }

    private var parsedAmount: Decimal? { AmountParser.parse(amountText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(EntryKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                amountSection

                Section("Category") {
                    CategoryGrid(kind: kind, selection: $category)
                }

                Section {
                    TextField(kind == .expense ? "Description, e.g. Costco" : "Description, e.g. October salary", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    if kind == .expense {
                        Picker("Paid with", selection: $paymentMethod) {
                            ForEach(PaymentMethod.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    }
                } header: {
                    Text("Details")
                } footer: {
                    if category == .creditCard {
                        Text("Tip: log either your individual card purchases or the monthly card payment — not both — so spending isn't counted twice.")
                    }
                }

                if entry == nil {
                    repeatSection
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if entry?.recurringID != nil {
                    Section {
                        Label("Created by a repeating payment. Change the schedule in Settings › Repeating Payments.", systemImage: "repeat")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(parsedAmount == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(selection: $currencyCode, title: "Entry currency")
            }
            .onChange(of: kind) { _, newKind in
                if category.kind != newKind {
                    category = newKind == .income ? .salary : .otherExpense
                }
            }
            .onAppear {
                if entry == nil { amountFocused = true }
            }
        }
    }

    private var amountSection: some View {
        Section {
            HStack(spacing: 12) {
                Button { showingCurrencyPicker = true } label: {
                    CurrencyChip(code: currencyCode)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Currency \(CurrencyCatalog.name(for: currencyCode))")

                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .focused($amountFocused)
                    .accessibilityLabel("Amount")
            }
            if currencyCode != reportCurrency,
               let amount = parsedAmount,
               let converted = currency.converter.convert(amount, from: currencyCode, to: reportCurrency) {
                LabeledContent("In \(reportCurrency)") {
                    Text("≈ " + converted.money(reportCurrency)).monospacedDigit()
                }
                .font(.subheadline)
            }
        } header: {
            Text("Amount")
        }
    }

    private var repeatSection: some View {
        Section {
            Picker("Repeat", selection: $repeatFrequency) {
                Text("Never").tag(Frequency?.none)
                ForEach(Frequency.allCases) { Text($0.title).tag(Optional($0)) }
            }
            if repeatFrequency != nil {
                Toggle("Has an end date", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Ends", selection: $endDate, in: date..., displayedComponents: .date)
                }
            }
        } header: {
            Text("Repeat")
        } footer: {
            Text("Repeating entries are added automatically on each due date — ideal for mortgage, loans, insurance, bills and salary.")
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let method = kind == .income ? PaymentMethod.bankTransfer : paymentMethod
        lastEntryCurrency = currencyCode

        if let entry {
            entry.title = trimmedTitle
            entry.amount = amount
            entry.currencyCode = currencyCode
            entry.category = category
            entry.date = date
            entry.paymentMethod = method
            entry.note = trimmedNote
        } else if let repeatFrequency {
            let schedule = RecurringPayment(
                title: trimmedTitle,
                amount: amount,
                currencyCode: currencyCode,
                category: category,
                paymentMethod: method,
                frequency: repeatFrequency,
                startDate: date,
                endDate: hasEndDate ? endDate : nil,
                note: trimmedNote
            )
            modelContext.insert(schedule)
            RecurringScheduler.materialize(schedule, in: modelContext)
        } else {
            modelContext.insert(Entry(
                title: trimmedTitle,
                amount: amount,
                currencyCode: currencyCode,
                date: date,
                category: category,
                paymentMethod: method,
                note: trimmedNote
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}

struct CategoryGrid: View {
    let kind: EntryKind
    @Binding var selection: EntryCategory

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(EntryCategory.ordered(for: kind)) { category in
                Button { selection = category } label: {
                    VStack(spacing: 6) {
                        CategoryIcon(category: category, size: 40)
                            .overlay {
                                if selection == category {
                                    Circle().stroke(Color.accentColor, lineWidth: 3).padding(-4)
                                }
                            }
                        Text(category.shortTitle)
                            .font(.caption2.weight(selection == category ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.title)
                .accessibilityAddTraits(selection == category ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
