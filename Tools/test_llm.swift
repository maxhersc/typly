// Scratch script for checking that Apple Intelligence is reachable on this machine.
// Not part of the Typly target.
//
//   swiftc -o /tmp/test_llm Tools/test_llm.swift && /tmp/test_llm

import Foundation
import FoundationModels

Task {
    if #available(macOS 26.0, *) {
        let availability = SystemLanguageModel.default.availability
        print("availability: \(availability)")

        if case .available = availability {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: "Hello")
                print(response.content)
            } catch {
                print("request failed: \(error)")
            }
        }
    } else {
        print("FoundationModels requires macOS 26 or newer.")
    }
    exit(0)
}
RunLoop.main.run()
