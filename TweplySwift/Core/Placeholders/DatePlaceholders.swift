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
