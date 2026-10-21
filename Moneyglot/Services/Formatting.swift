import Foundation

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    func money(_ currencyCode: String) -> String {
        formatted(.currency(code: currencyCode))
    }

    /// Whole-unit amount, e.g. "$1,250" — used where cents are noise.
    func wholeMoney(_ currencyCode: String) -> String {
        formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}

extension Double {
    var percentText: String { formatted(.percent.precision(.fractionLength(0))) }

    /// Short axis label such as "$1.2K".
    func compactMoney(_ currencyCode: String) -> String {
        CurrencyCatalog.symbol(for: currencyCode) + formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}

enum AmountParser {
    /// Parses user input like "1,234.56", "1 234,56" or "١٢٣٤" using the current locale.
    /// Returns nil for anything that isn't a positive number (e.g. pasted text).
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        var normalized = ""
        var hasSeparator = false

        for character in text {
            if character.isNumber, let digit = character.wholeNumberValue {
                normalized += String(digit)
            } else if String(character) == decimalSeparator {
                guard !hasSeparator else { return nil }
                hasSeparator = true
                normalized += "."
            } else if String(character) == groupingSeparator || character.isWhitespace {
                continue
            } else {
                return nil
            }
        }
        guard let value = Decimal(string: normalized), value > 0 else { return nil }
        return value
    }

    static func editingText(for amount: Decimal, locale: Locale = .current) -> String {
        amount.formatted(.number.grouping(.never).locale(locale))
    }
}

enum SettingsKey {
    static let reportCurrency = "reportCurrency"
    static let favoriteCurrencies = "favoriteCurrencies"
    static let lastEntryCurrency = "lastEntryCurrency"
}

enum AppLinks {
    static let privacyPolicy = URL(string: "https://asfateh.github.io/moneyglot/privacy.html")!
    static let support = URL(string: "https://asfateh.github.io/moneyglot/")!
    /// Apple's standard licence agreement, accepted for auto-renewable subscriptions.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let exchangeRateAttribution = URL(string: "https://www.exchangerate-api.com")!
}
