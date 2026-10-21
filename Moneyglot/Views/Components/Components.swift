import SwiftUI

enum Theme {
    static let indigo = Color(red: 0.23, green: 0.18, blue: 0.62)
    static let teal = Color(red: 0.05, green: 0.62, blue: 0.56)
    static let brandGradient = LinearGradient(colors: [indigo, teal], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let pageBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: .rect(cornerRadius: 20))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

struct CategoryIcon: View {
    let category: EntryCategory
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.gradient, in: .circle)
            .accessibilityHidden(true)
    }
}

struct CardHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Horizontal bar showing a share of a whole.
struct ShareBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(color.gradient)
                    .frame(width: max(4, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

/// Currency code button with flag, used in forms and toolbars.
struct CurrencyChip: View {
    let code: String

    var body: some View {
        HStack(spacing: 4) {
            Text(CurrencyCatalog.flag(for: code))
            Text(code).font(.subheadline.weight(.semibold))
            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.14), in: .capsule)
        .foregroundStyle(.primary)
    }
}

struct EntryRow: View {
    let entry: Entry
    let reportCurrency: String
    @Environment(CurrencyService.self) private var currency

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: entry.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayTitle)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if entry.recurringID != nil {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Repeating")
                    }
                }
                Text("\(entry.category.title) · \(entry.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text((entry.kind == .income ? "+" : "") + entry.amount.money(entry.currencyCode))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(entry.kind == .income ? Color.green : Color.primary)
                if entry.currencyCode != reportCurrency,
                   let converted = currency.converter.convert(entry.amount, from: entry.currencyCode, to: reportCurrency) {
                    Text("≈ " + converted.money(reportCurrency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .contentShape(.rect)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .card()
    }
}
