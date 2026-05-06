import Foundation

func registerDatePlaceholders() {
    let r = PlaceholderRegistry.shared

    r.register(.currentDate)     { s in fmtTokens(Date(), format: s.args.first ?? "YYYY-MM-DD") }
    r.register(.currentTime)     { s in fmtTokens(Date(), format: s.args.first ?? "HH:mm:ss") }
    r.register(.currentDateTime) { s in fmtTokens(Date(), format: s.args.first ?? "YYYY-MM-DDTHH:mm:ss") }
    r.register(.currentYear)     { _ in fmtTokens(Date(), format: "YYYY") }
    r.register(.currentMonth)    { _ in fmtTokens(Date(), format: "MM") }
    r.register(.currentDay)      { _ in fmtTokens(Date(), format: "DD") }
    r.register(.currentTimestamp){ _ in String(Int(Date().timeIntervalSince1970)) }

    r.register(.currentWeek) { _ in
        String(format: "%02d", Calendar.current.component(.weekOfYear, from: Date()))
    }

    r.register(.currentDayOfWeek) { s in
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = s.args.first == "short" ? "EEE" : "EEEE"
        return df.string(from: Date())
    }

    r.register(.dateAdd) { s in
        guard let spec = s.args.first else { return "" }
        let fmt  = s.args.count > 1 ? s.args[1] : "YYYY-MM-DD"
        return fmtTokens(applyDateOffset(spec: spec), format: fmt)
    }

    r.register(.quarterStart) { s in
        let fmt   = s.args.first ?? "YYYY-MM-DD"
        let cal   = Calendar.current
        let now   = Date()
        let month = cal.component(.month, from: now)
        let year  = cal.component(.year,  from: now)
        let qMonth = ((month - 1) / 3) * 3 + 1
        let date  = cal.date(from: DateComponents(year: year, month: qMonth, day: 1)) ?? now
        return fmtTokens(date, format: fmt)
    }

    r.register(.quarterEnd) { s in
        let fmt      = s.args.first ?? "YYYY-MM-DD"
        let cal      = Calendar.current
        let now      = Date()
        let month    = cal.component(.month, from: now)
        let year     = cal.component(.year,  from: now)
        let qEndMonth = ((month - 1) / 3) * 3 + 3
        let nextMonth = qEndMonth + 1
        let comps = DateComponents(year: nextMonth > 12 ? year + 1 : year,
                                   month: nextMonth > 12 ? 1 : nextMonth, day: 1)
        let first  = cal.date(from: comps) ?? now
        let last   = cal.date(byAdding: .day, value: -1, to: first) ?? now
        return fmtTokens(last, format: fmt)
    }
}

private func applyDateOffset(spec: String) -> Date {
    var s    = spec
    let sign: Int
    if s.hasPrefix("+") { sign = 1; s.removeFirst() }
    else if s.hasPrefix("-") { sign = -1; s.removeFirst() }
    else { sign = 1 }
    guard let unit = s.last else { return Date() }
    let n = (Int(s.dropLast()) ?? 1) * sign
    let cal = Calendar.current
    switch unit {
    case "d": return cal.date(byAdding: .day,        value: n, to: Date()) ?? Date()
    case "w": return cal.date(byAdding: .weekOfYear, value: n, to: Date()) ?? Date()
    case "m": return cal.date(byAdding: .month,      value: n, to: Date()) ?? Date()
    case "y": return cal.date(byAdding: .year,       value: n, to: Date()) ?? Date()
    default:  return Date()
    }
}

private func fmtTokens(_ date: Date, format: String) -> String {
    let cal = Calendar.current
    let df  = DateFormatter()
    df.locale = Locale(identifier: "en_US")

    // Ordered longest-first to prevent prefix matches
    let tokens: [(String, () -> String)] = [
        ("YYYY", { String(format: "%04d", cal.component(.year,   from: date)) }),
        ("MMMM", { df.dateFormat = "MMMM"; return df.string(from: date) }),
        ("DDDD", { df.dateFormat = "EEEE"; return df.string(from: date) }),
        ("MMM",  { df.dateFormat = "MMM";  return df.string(from: date) }),
        ("DDD",  { df.dateFormat = "EEE";  return df.string(from: date) }),
        ("YY",   { String(format: "%02d", cal.component(.year,   from: date) % 100) }),
        ("MM",   { String(format: "%02d", cal.component(.month,  from: date)) }),
        ("DD",   { String(format: "%02d", cal.component(.day,    from: date)) }),
        ("WW",   { String(format: "%02d", cal.component(.weekOfYear, from: date)) }),
        ("HH",   { String(format: "%02d", cal.component(.hour,   from: date)) }),
        ("mm",   { String(format: "%02d", cal.component(.minute, from: date)) }),
        ("ss",   { String(format: "%02d", cal.component(.second, from: date)) }),
        ("A",    { cal.component(.hour, from: date) >= 12 ? "PM" : "AM" }),
        ("a",    { cal.component(.hour, from: date) >= 12 ? "pm" : "am" }),
        ("X",    { String(Int(date.timeIntervalSince1970)) }),
    ]

    var result    = ""
    var remaining = format[...]

    outer: while !remaining.isEmpty {
        for (token, value) in tokens {
            if remaining.hasPrefix(token) {
                result   += value()
                remaining = remaining.dropFirst(token.count)
                continue outer
            }
        }
        result.append(remaining.removeFirst())
    }
    return result
}
