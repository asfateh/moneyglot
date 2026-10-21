import Foundation

/// Display helpers for ISO 4217 currency codes.
enum CurrencyCatalog {
    static var deviceCurrency: String { Locale.current.currency?.identifier ?? "USD" }

    static func name(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    private static let isoRegions = Set(Locale.Region.isoRegions.map(\.identifier))

    /// Flag emoji derived from the code's country prefix (USD → 🇺🇸). Falls back to a globe for
    /// codes without a current country (XAF, ANG…).
    static func flag(for code: String) -> String {
        if code == "EUR" { return "🇪🇺" }
        guard code.count == 3, isoRegions.contains(String(code.prefix(2))) else { return "🌐" }
        var scalars = String.UnicodeScalarView()
        for letter in code.prefix(2).unicodeScalars {
            guard let scalar = UnicodeScalar(127_397 + letter.value) else { return "🌐" }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    static func symbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    static func label(for code: String) -> String { "\(flag(for: code)) \(code)" }
}

/// The short list of currencies a person actually uses, stored as a comma-separated string.
enum FavoriteCurrencies {
    static func decode(_ raw: String) -> [String] {
        let codes = raw.split(separator: ",").map(String.init).filter { $0.count == 3 }
        return codes.isEmpty ? defaults : codes
    }

    static func encode(_ codes: [String]) -> String { codes.joined(separator: ",") }

    static var defaults: [String] {
        var seen = Set<String>()
        return [CurrencyCatalog.deviceCurrency, "USD", "EUR"].filter { seen.insert($0).inserted }
    }
}
