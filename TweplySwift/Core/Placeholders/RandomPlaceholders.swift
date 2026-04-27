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
}
