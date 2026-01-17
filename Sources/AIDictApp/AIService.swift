import Foundation

struct DictionaryEntry: Codable {
    let word: String
    let phonetic: String
    let meanings: [Meaning]
    let aiDeepDive: String
    let etymology: String
    let synonyms: [String]
    
    struct Meaning: Codable {
        let pos: String
        let text: String
        let example: String?
    }
}

class AIService {
    static let shared = AIService()
    
    func getDefinition(for word: String) async -> String {
        // Simulating network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if normalizedWord == "interception" {
            return """
            Interception /ˌɪntəˈsɛpʃ(ə)n/
            [noun] The action of stopping or catching something or someone that is going from one place to another.
            
            AI DEEP DIVE:
            In the context of software architecture, interception is a powerful pattern where a call to a target is diverted through a proxy. This allows for cross-cutting concerns like logging, security, or—in our case—overriding system-default behaviors with AI-enhanced experiences.
            
            ETYMOLOGY:
            From Latin 'interceptio', from 'intercipere' (to seize between).
            """
        }
        
        return """
        \(word.capitalized) /\(word.lowercased())/
        [definition] Primary meaning of "\(word)" as interpreted by the AI engine.
        
        AI DEEP DIVE:
        The term "\(word)" functions as a semiotic anchor in this conversation. From an AI perspective, it triggers a cascade of related conceptual nodes, bridging historical usage with modern digital context.
        
        ETYMOLOGY:
        Etymological origins are currently being indexed for this specific term.
        
        SYNONYMS:
        Sample Synonym A, Sample Synonym B
        """
    }
}
