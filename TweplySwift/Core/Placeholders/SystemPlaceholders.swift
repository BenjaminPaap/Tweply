import Foundation

func registerSystemPlaceholders() {
    let r = PlaceholderRegistry.shared

    r.register(.username)  { _ in NSUserName() }
    r.register(.hostname)  { _ in ProcessInfo.processInfo.hostName }
    r.register(.platform)  { _ in "mac" }
    r.register(.env) { s in
        guard let key = s.args.first else { return "" }
        return ProcessInfo.processInfo.environment[key] ?? ""
    }
}
