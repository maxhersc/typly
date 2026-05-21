import Foundation
import FoundationModels

Task {
    do {
        let model = SystemLanguageModel.default
        let session = LanguageModelSession()
        let response = try await session.respond(to: "Hello")
        print(response.content)
    } catch {
        print(error)
    }
    exit(0)
}
RunLoop.main.run()
