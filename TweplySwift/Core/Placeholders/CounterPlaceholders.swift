import Foundation

func registerCounterPlaceholders() {
    PlaceholderRegistry.shared.register(.counter) { s in
        guard let id = s.args.first else { return "0" }
        let start = Int(s.args.count > 1 ? s.args[1] : "") ?? 0
        let step  = Int(s.args.count > 2 ? s.args[2] : "") ?? 1
        return DataStore.shared.incrementCounter(id: id, start: start, step: step)
    }
}
