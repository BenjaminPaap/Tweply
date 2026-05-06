import Foundation

func registerRandomPlaceholders() {
    let r = PlaceholderRegistry.shared

    r.register(.uuid) { _ in UUID().uuidString.lowercased() }

    r.register(.nanoId) { s in
        let len      = Int(s.args.first ?? "") ?? 10
        let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_-"
        return String((0..<len).compactMap { _ in alphabet.randomElement() })
    }

    r.register(.random) { s in
        let max = Int(s.args.first ?? "") ?? 100
        return String(Int.random(in: 0..<max))
    }

    r.register(.randomHex) { s in
        let len = Int(s.args.first ?? "") ?? 8
        return (0..<len).map { _ in String(format: "%x", Int.random(in: 0...15)) }.joined()
    }

    r.register(.lorem) { s in
        let count = max(1, Int(s.args.first ?? "") ?? 5)
        return (0..<count).map { _ in loremWords.randomElement() ?? "lorem" }.joined(separator: " ")
    }

    // Cycles through the provided values in order using a persistent counter.
    r.register(.sequence) { s in
        guard !s.args.isEmpty else { return "" }
        let id  = "seq_" + s.args.joined(separator: ",")
        let idx = Int(DataStore.shared.incrementCounter(id: id, start: 0, step: 1)) ?? 0
        return s.args[idx % s.args.count]
    }
}

private let loremWords = [
    "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
    "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
    "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud",
    "exercitation", "ullamco", "laboris", "nisi", "aliquip", "ex", "ea", "commodo",
    "consequat", "duis", "aute", "irure", "reprehenderit", "voluptate", "velit",
    "esse", "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint", "occaecat",
    "cupidatat", "non", "proident", "sunt", "culpa", "qui", "officia", "deserunt",
    "mollit", "anim", "id", "est", "laborum",
]
