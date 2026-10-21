import Foundation
import Observation

/// Exchange rates expressed as "units of currency per 1 USD".
struct RatesSnapshot: Codable, Equatable {
    var base: String
    var rates: [String: Double]
    /// When the provider published these rates.
    var updatedAt: Date
    /// When this device downloaded them.
    var fetchedAt: Date
}

/// Pure conversion logic, separated from networking so it can be unit tested.
struct CurrencyConverter {
    var ratesPerUSD: [String: Double]

    func canConvert(_ code: String) -> Bool { ratesPerUSD[code] != nil }

    /// How many units of `to` one unit of `from` buys.
    func rate(from: String, to: String) -> Decimal? {
        if from == to { return 1 }
        guard let fromRate = ratesPerUSD[from], let toRate = ratesPerUSD[to], fromRate > 0 else { return nil }
        return Decimal(toRate / fromRate)
    }

    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        if from == to { return amount }
        guard let rate = rate(from: from, to: to) else { return nil }
        return amount * rate
    }
}

/// Downloads, caches and serves exchange rates. Falls back to rates bundled with the app when offline.
@MainActor
@Observable
final class CurrencyService {
    enum Source { case bundled, live }

    private(set) var snapshot: RatesSnapshot
    private(set) var source: Source
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    private static let endpoint = URL(string: "https://open.er-api.com/v6/latest/USD")!
    private static let staleInterval: TimeInterval = 12 * 60 * 60

    init() {
        if let cached = Self.loadCache() {
            snapshot = cached
            source = .live
        } else {
            snapshot = Self.loadBundled()
            source = .bundled
        }
    }

    var converter: CurrencyConverter { CurrencyConverter(ratesPerUSD: snapshot.rates) }
    var lastUpdated: Date { snapshot.updatedAt }
    var availableCodes: [String] { snapshot.rates.keys.sorted() }

    func refreshIfStale() async {
        if source == .bundled || Date().timeIntervalSince(snapshot.fetchedAt) > Self.staleInterval {
            await refresh()
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: Self.endpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let payload = try JSONDecoder().decode(OpenExchangePayload.self, from: data)
            guard payload.result == "success", !payload.rates.isEmpty else { throw URLError(.cannotParseResponse) }

            var rates = payload.rates
            rates["USD"] = 1
            snapshot = RatesSnapshot(
                base: "USD",
                rates: rates,
                updatedAt: Date(timeIntervalSince1970: payload.timeLastUpdateUnix),
                fetchedAt: .now
            )
            source = .live
            lastError = nil
            Self.saveCache(snapshot)
        } catch {
            lastError = "Couldn't update exchange rates. Showing rates from \(snapshot.updatedAt.formatted(date: .abbreviated, time: .omitted))."
        }
    }

    // MARK: - Persistence

    private static var cacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "exchange-rates.json")
    }

    private static func loadCache() -> RatesSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? decoder.decode(RatesSnapshot.self, from: data)
    }

    private static func saveCache(_ snapshot: RatesSnapshot) {
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            try encoder.encode(snapshot).write(to: cacheURL, options: .atomic)
        } catch {
            // A failed cache write only means we download again next launch.
        }
    }

    private static func loadBundled() -> RatesSnapshot {
        if let url = Bundle.main.url(forResource: "fallback-rates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let snapshot = try? decoder.decode(RatesSnapshot.self, from: data) {
            return snapshot
        }
        return RatesSnapshot(base: "USD", rates: ["USD": 1], updatedAt: .distantPast, fetchedAt: .distantPast)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

/// Response format of https://open.er-api.com (ExchangeRate-API open access endpoint).
private struct OpenExchangePayload: Decodable {
    let result: String
    let timeLastUpdateUnix: TimeInterval
    let rates: [String: Double]

    enum CodingKeys: String, CodingKey {
        case result
        case timeLastUpdateUnix = "time_last_update_unix"
        case rates
    }
}
