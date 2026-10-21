import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum CSVExporter {
    static let header = [
        "Date", "Description", "Type", "Category", "Payment method",
        "Amount", "Currency", "Converted amount", "Report currency", "Note",
    ]

    static func csv(for entries: [Entry], converter: CurrencyConverter, reportCurrency: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let rows = entries.sorted { $0.date < $1.date }.map { entry in
            let converted = converter.convert(entry.amount, from: entry.currencyCode, to: reportCurrency)
            return [
                formatter.string(from: entry.date),
                entry.displayTitle,
                entry.kind.title,
                entry.category.title,
                entry.kind == .expense ? entry.paymentMethod.title : "",
                "\(entry.amount)",
                entry.currencyCode,
                converted.map { "\($0.rounded(scale: 2))" } ?? "",
                reportCurrency,
                entry.note,
            ]
        }
        let lines = ([header] + rows).map { fields in fields.map { escape($0) }.joined(separator: ",") }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A CSV file that can be handed to `ShareLink`.
nonisolated struct CSVDocument: Transferable {
    let filename: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        }
        .suggestedFileName { $0.filename }
    }
}
