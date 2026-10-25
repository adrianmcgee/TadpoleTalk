import Foundation

/// Loads the bundled, read-only reference content (sounds, signs, starter targets) once
/// and hands it out. This is shipped knowledge, not user data, so it lives outside
/// SwiftData and never changes at runtime.
struct ContentStore {
    let phonemes: [Phoneme]
    let signs: [SignEntry]
    let starterTargets: [StarterTarget]

    static let shared = ContentStore()

    init() {
        self.phonemes = Self.load("phonemes", as: [Phoneme].self) ?? []
        self.signs = Self.load("signs", as: [SignEntry].self) ?? []
        self.starterTargets = Self.load("starter_targets", as: [StarterTarget].self) ?? []
    }

    func phoneme(id: String) -> Phoneme? { phonemes.first { $0.id == id } }

    /// Signs grouped by category, preserving first-seen category order.
    var signsByCategory: [(category: String, signs: [SignEntry])] {
        var order: [String] = []
        var map: [String: [SignEntry]] = [:]
        for sign in signs {
            if map[sign.category] == nil { order.append(sign.category) }
            map[sign.category, default: []].append(sign)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    /// Starter targets grouped by syllable shape, easiest first.
    var starterTargetsByShape: [(shape: SyllableShape, targets: [StarterTarget])] {
        let grouped = Dictionary(grouping: starterTargets, by: \.shape)
        return SyllableShape.allCases
            .compactMap { shape in
                guard let targets = grouped[shape], !targets.isEmpty else { return nil }
                return (shape, targets)
            }
    }

    /// Starter words that practise a front/back movement, grouped by shape (easiest first)
    /// then movement — the ready-made sets offered on the Targets tab.
    var movementSets: [MovementSet] {
        var sets: [MovementSet] = []
        for shape in SyllableShape.allCases {
            for movement in MovementPattern.allCases {
                let targets = starterTargets.filter { $0.shape == shape && $0.movement == movement }
                if !targets.isEmpty { sets.append(MovementSet(shape: shape, movement: movement, targets: targets)) }
            }
        }
        return sets
    }

    private static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            log("missing bundled resource \(name).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log("failed to decode \(name).json: \(error)")
            return nil
        }
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("[ContentStore] \(message)")
        #endif
    }
}

/// Starter words of one shape that share a front/back movement.
struct MovementSet: Identifiable {
    var id: String { "\(shape.rawValue)-\(movement.rawValue)" }
    let shape: SyllableShape
    let movement: MovementPattern
    let targets: [StarterTarget]
}
