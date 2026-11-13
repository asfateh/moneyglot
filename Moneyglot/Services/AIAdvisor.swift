import Foundation
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIPlan: Equatable {
    enum Source: Equatable {
        case appleIntelligence
        /// Apple's on-device model declined the request, so the plan was assembled from the rule-based insights.
        case smartInsights
    }

    var overview: String
    var suggestions: [AISuggestion]
    var currency: String
    var generatedAt: Date
    var source: Source = .appleIntelligence
}

struct AISuggestion: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var detail: String
    var monthlySavings: Double
}

/// Premium AI coach. Runs Apple's on-device foundation model, so financial data never leaves the phone.
@MainActor
@Observable
final class AIAdvisor {
    enum Status: Equatable {
        case available
        case unavailable(String)
    }

    private(set) var plan: AIPlan?
    private(set) var isGenerating = false
    private(set) var errorMessage: String?

    static let instructions = """
        You are Moneyglot's friendly personal-finance coach. You receive one person's monthly income and \
        spending, already converted into a single currency. Give practical, specific suggestions that help them \
        control expenses and save more, based only on the numbers provided. Mention their real categories and \
        amounts. Be encouraging, never judgmental. Do not recommend specific investments, stocks, crypto, loans \
        or financial products, and do not give legal or tax advice.
        """

    var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable("This iPhone doesn't support Apple Intelligence, so the AI plan isn't available. Your smart insights below still update automatically.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Turn on Apple Intelligence in the Settings app to get your personal AI plan.")
            case .unavailable(.modelNotReady):
                return .unavailable("Apple Intelligence is still getting ready on this iPhone. Try again in a few minutes.")
            case .unavailable:
                return .unavailable("Apple Intelligence isn't available right now.")
            }
        }
        #endif
        return .unavailable("The AI plan needs iOS 26 or later with Apple Intelligence.")
    }

    func generatePlan(from snapshot: FinancialSnapshot, insights: [Insight]) async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let prompt = snapshot.promptText(insights: insights)
            + "\n\nCreate a savings plan with 3 to 5 suggestions, most impactful first."

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // The on-device model's safety filter sometimes declines finance topics, and not always the same way
            // twice, so retry once before falling back to the app's own insights.
            for _ in 1...Self.modelAttempts {
                if let generated = try? await Self.runModel(prompt: prompt, currency: snapshot.currency) {
                    plan = generated
                    return
                }
            }
        }
        #endif

        if let fallback = Self.fallbackPlan(from: insights, currency: snapshot.currency) {
            plan = fallback
        } else {
            errorMessage = "Couldn't create your plan right now. Add a few more entries and try again."
        }
    }

    static let modelAttempts = 2

    /// A plan built from the rule-based insights: the improvements with the biggest monthly impact first.
    static func fallbackPlan(from insights: [Insight], currency: String, now: Date = .now) -> AIPlan? {
        let actionable = insights
            .filter { $0.tone != .positive }
            .sorted { ($0.monthlySavings ?? 0) > ($1.monthlySavings ?? 0) }
            .prefix(5)
        guard !actionable.isEmpty else { return nil }
        return AIPlan(
            overview: "Here are the changes with the biggest impact on your budget right now.",
            suggestions: actionable.map {
                AISuggestion(title: $0.title, detail: $0.message, monthlySavings: ($0.monthlySavings ?? 0).doubleValue)
            },
            currency: currency,
            generatedAt: now,
            source: .smartInsights
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func runModel(prompt: String, currency: String) async throws -> AIPlan {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: GeneratedPlan.self)
        let content = response.content
        return AIPlan(
            overview: content.overview,
            suggestions: content.suggestions.prefix(5).map {
                AISuggestion(title: $0.title, detail: $0.detail, monthlySavings: max(0, $0.estimatedMonthlySavings))
            },
            currency: currency,
            generatedAt: .now
        )
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedPlan {
    @Guide(description: "A warm one or two sentence overview of the person's spending and savings, mentioning their savings rate if known.")
    var overview: String

    @Guide(description: "Three to five specific, actionable suggestions, most impactful first.")
    var suggestions: [GeneratedSuggestion]
}

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedSuggestion {
    @Guide(description: "Short imperative title of at most 7 words.")
    var title: String

    @Guide(description: "Two or three sentences explaining exactly what to do, referring to the person's real categories and amounts.")
    var detail: String

    @Guide(description: "Realistic estimated monthly savings as a plain number in the person's currency. Use 0 when not applicable.")
    var estimatedMonthlySavings: Double
}
#endif
