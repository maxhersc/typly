import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum TransformResult {
    case success(String)
    /// A message that is safe to show the user, but must never be written into
    /// their document in place of their text.
    case failure(String)
}

/// Delivered on the main thread from every path, so callers do not have to guess.
private func deliver(_ result: TransformResult, to completion: @escaping (TransformResult) -> Void) {
    DispatchQueue.main.async { completion(result) }
}

private func prompt(for action: TyplyAction) -> String {
    switch action {
    case .fixSpelling(let text):
        return "Fix the spelling and grammar of the following text. Only output the corrected text and nothing else. No conversational filler:\n\n\(text)"
    case .rewrite(let text):
        return "Rewrite the following text to be clear, concise, and professional. Only output the rewritten text and nothing else. No conversational filler:\n\n\(text)"
    case .summarize(let text):
        return "Summarize the following text in one short paragraph. Keep it concise:\n\n\(text)"
    case .define(let word):
        return "Provide a short, concise definition for the word: \(word)"
    }
}

final class TextTransformerEngine {

    static let shared = TextTransformerEngine()

    func transform(action: TyplyAction, completion: @escaping (TransformResult) -> Void) {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            deliver(.failure("Apple Intelligence (FoundationModels) requires macOS 26 or newer."),
                    to: completion)
            return
        }

        // Asking for a session before checking availability fails at request time with
        // a generic error; checking first lets us say what is actually wrong.
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            deliver(.failure("Apple Intelligence is unavailable (\(availability)). Check System Settings › Apple Intelligence & Siri."),
                    to: completion)
            return
        }

        respond(to: prompt(for: action), completion: completion)
        #else
        deliver(.failure("This build was compiled without FoundationModels. Rebuild with the macOS 26 SDK."),
                to: completion)
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func respond(to request: String, completion: @escaping (TransformResult) -> Void) {
        Task {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: request)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                if text.isEmpty {
                    deliver(.failure("The model returned an empty response."), to: completion)
                } else {
                    deliver(.success(text), to: completion)
                }
            } catch {
                deliver(.failure("Typly couldn't transform that text: \(error.localizedDescription)"),
                        to: completion)
            }
        }
    }
    #endif
}
