import Foundation
import CryptoKit
import AppKit

func registerSystemPlaceholders() {
    let r = PlaceholderRegistry.shared

    r.register(.username)  { _ in NSUserName() }
    r.register(.hostname)  { _ in ProcessInfo.processInfo.hostName }
    r.register(.platform)  { _ in "mac" }
    r.register(.fullName)  { _ in NSFullUserName() }
    r.register(.localIP)   { _ in localIPAddress() }
    r.register(.appName)   { _ in NSWorkspace.shared.frontmostApplication?.localizedName ?? "" }
    r.register(.gitBranch) { _ in gitBranchName() }

    r.register(.env) { s in
        guard let key = s.args.first else { return "" }
        return ProcessInfo.processInfo.environment[key] ?? ""
    }

    // Clipboard transforms
    r.register(.clipLine) { s in
        let n     = max(1, Int(s.args.first ?? "1") ?? 1)
        let text  = NSPasteboard.general.string(forType: .string) ?? ""
        let lines = text.components(separatedBy: "\n")
        return n <= lines.count ? lines[n - 1] : ""
    }

    r.register(.wordCount) { _ in
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        return String(text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count)
    }

    r.register(.lineCount) { _ in
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        return String(text.components(separatedBy: "\n").count)
    }

    r.register(.trimmed) { _ in
        (NSPasteboard.general.string(forType: .string) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    r.register(.urlEncode) { s in
        let input = s.args.first ?? (NSPasteboard.general.string(forType: .string) ?? "")
        return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    }

    r.register(.base64) { s in
        let input = s.args.first ?? (NSPasteboard.general.string(forType: .string) ?? "")
        return Data(input.utf8).base64EncodedString()
    }

    r.register(.sha256) { s in
        let input  = s.args.first ?? (NSPasteboard.general.string(forType: .string) ?? "")
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Helpers

private func localIPAddress() -> String {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return "" }
    defer { freeifaddrs(ifaddr) }

    var ptr = ifaddr
    while let current = ptr {
        defer { ptr = current.pointee.ifa_next }
        guard let addrPtr = current.pointee.ifa_addr else { continue }
        guard addrPtr.pointee.sa_family == UInt8(AF_INET) else { continue }
        let name = String(cString: current.pointee.ifa_name)
        guard name.hasPrefix("en") else { continue }
        var addr = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
        var buf  = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        if inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
            return String(cString: buf)
        }
    }
    return ""
}

private func gitBranchName() -> String {
    let fm  = FileManager.default
    var url = URL(fileURLWithPath: fm.currentDirectoryPath)
    for _ in 0..<10 {
        let head = url.appendingPathComponent(".git/HEAD")
        if fm.fileExists(atPath: head.path),
           let content = try? String(contentsOf: head, encoding: .utf8) {
            let s = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.hasPrefix("ref: refs/heads/")
                ? String(s.dropFirst("ref: refs/heads/".count))
                : String(s.prefix(7))
        }
        let parent = url.deletingLastPathComponent()
        if parent == url { break }
        url = parent
    }
    return ""
}
