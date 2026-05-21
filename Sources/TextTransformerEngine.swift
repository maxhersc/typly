import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

class TextTransformerEngine {
    
    static let shared = TextTransformerEngine()
    
    func transform(action: TyplyAction, completion: @escaping (String) -> Void) {
        Task {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                do {
                    let session = LanguageModelSession()
                    let prompt: String
                    
                    switch action {
                    case .fixSpelling(let text):
                        prompt = "Fix the spelling and grammar of the following text. Only output the corrected text and nothing else. No conversational filler:\n\n\(text)"
                    case .rewrite(let text):
                        prompt = "Rewrite the following text to be clear, concise, and professional. Only output the rewritten text and nothing else. No conversational filler:\n\n\(text)"
                    case .summarize(let text):
                        prompt = "Summarize the following text in one short paragraph. Keep it concise:\n\n\(text)"
                    case .define(let word):
                        prompt = "Provide a short, concise definition for the word: \(word)"
                    }
                    
                    let response = try await session.respond(to: prompt)
                    let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    DispatchQueue.main.async {
                        completion(result)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion("Error: \(error.localizedDescription)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion("Apple Intelligence (FoundationModels) requires macOS 26.0 or newer.")
                }
            }
            #else
            DispatchQueue.main.async {
                completion("Apple Intelligence (FoundationModels) not available on this macOS version.")
            }
            #endif
        }
    }
}
