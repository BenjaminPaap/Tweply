import SwiftUI

// MARK: - Icon catalogue

// All names are verified SF Symbols (macOS 14+). Grouped by theme.
private let iconCatalogue: [(category: String, icons: [String])] = [
    ("Arrows", [
        "arrow.right", "arrow.left", "arrow.up", "arrow.down",
        "arrow.right.circle.fill", "arrow.left.circle.fill",
        "arrow.up.circle.fill", "arrow.down.circle.fill",
        "arrow.clockwise", "arrow.counterclockwise",
        "arrow.clockwise.circle", "arrow.counterclockwise.circle",
        "arrow.uturn.right", "arrow.uturn.left",
        "arrow.up.and.down", "arrow.left.and.right",
        "arrow.2.squarepath", "arrow.triangle.2.circlepath",
        "chevron.right", "chevron.left", "chevron.up", "chevron.down",
        "chevron.right.circle.fill", "chevron.left.circle.fill",
        "chevron.up.chevron.down",
        "return", "arrow.turn.down.right", "arrow.turn.up.right",
        "arrowshape.right.fill", "arrowshape.left.fill",
        "arrowshape.up.fill", "arrowshape.down.fill",
    ]),
    ("Communication", [
        "envelope", "envelope.fill", "envelope.open", "envelope.open.fill",
        "envelope.badge", "envelope.badge.fill",
        "message", "message.fill", "message.circle.fill",
        "phone", "phone.fill", "phone.circle.fill",
        "phone.badge.plus",
        "video", "video.fill", "video.circle.fill",
        "mic", "mic.fill", "mic.circle.fill", "mic.slash.fill",
        "bubble.left", "bubble.left.fill",
        "bubble.right", "bubble.right.fill",
        "bubble.left.and.bubble.right.fill",
        "at", "at.circle.fill",
        "paperplane", "paperplane.fill",
        "tray", "tray.fill",
        "tray.and.arrow.up.fill", "tray.and.arrow.down.fill",
        "tray.2.fill",
    ]),
    ("Files & Docs", [
        "doc", "doc.fill", "doc.text", "doc.text.fill",
        "doc.richtext", "doc.richtext.fill",
        "doc.badge.plus", "doc.badge.arrow.up.fill",
        "doc.on.doc", "doc.on.doc.fill",
        "doc.on.clipboard", "doc.on.clipboard.fill",
        "clipboard", "clipboard.fill",
        "folder", "folder.fill", "folder.circle.fill",
        "folder.badge.plus", "folder.badge.minus",
        "folder.badge.gearshape",
        "archivebox", "archivebox.fill",
        "paperclip", "paperclip.circle.fill",
        "link", "link.circle", "link.circle.fill",
        "list.bullet", "list.bullet.circle.fill",
        "list.number", "list.dash",
        "square.and.pencil", "square.and.arrow.up.fill",
        "square.and.arrow.down.fill",
    ]),
    ("Time & Calendar", [
        "clock", "clock.fill", "clock.circle.fill",
        "clock.badge.checkmark", "clock.badge.exclamationmark",
        "alarm", "alarm.fill",
        "timer", "timer.circle.fill",
        "stopwatch", "stopwatch.fill",
        "calendar", "calendar.circle.fill",
        "calendar.badge.plus", "calendar.badge.minus",
        "calendar.badge.clock", "calendar.badge.checkmark",
        "calendar.day.timeline.left",
        "hourglass", "hourglass.tophalf.filled", "hourglass.bottomhalf.filled",
    ]),
    ("People", [
        "person", "person.fill",
        "person.circle", "person.circle.fill",
        "person.crop.circle", "person.crop.circle.fill",
        "person.crop.square", "person.crop.square.fill",
        "person.2", "person.2.fill",
        "person.2.circle", "person.2.circle.fill",
        "person.3.fill",
        "person.badge.plus", "person.badge.minus",
        "person.badge.clock",
        "figure.walk", "figure.stand",
        "figure.run",
    ]),
    ("Objects & Tags", [
        "star", "star.fill", "star.circle.fill", "star.square.fill",
        "heart", "heart.fill", "heart.circle.fill",
        "flag", "flag.fill", "flag.circle.fill",
        "bookmark", "bookmark.fill", "bookmark.circle.fill",
        "tag", "tag.fill", "tag.circle.fill",
        "bell", "bell.fill", "bell.circle.fill", "bell.slash.fill",
        "rosette",
        "trophy", "trophy.fill",
        "gift", "gift.fill",
        "ticket", "ticket.fill",
        "crown", "crown.fill",
        "medal", "medal.fill",
        "seal.fill", "checkmark.seal.fill", "xmark.seal.fill",
        "exclamationmark.shield.fill",
    ]),
    ("Tools", [
        "gear", "gearshape", "gearshape.fill", "gearshape.2",
        "gearshape.2.fill",
        "wrench", "wrench.fill",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        "hammer", "hammer.fill", "hammer.circle",
        "paintbrush", "paintbrush.fill",
        "paintbrush.pointed", "paintbrush.pointed.fill",
        "scissors", "scissors.circle",
        "pencil", "pencil.circle.fill", "pencil.tip",
        "pencil.and.outline", "pencil.line",
        "ruler", "ruler.fill",
        "screwdriver", "screwdriver.fill",
        "wrench.adjustable", "wrench.adjustable.fill",
        "cube.fill", "shippingbox.fill",
    ]),
    ("Security", [
        "lock", "lock.fill", "lock.circle.fill",
        "lock.open", "lock.open.fill",
        "lock.shield", "lock.shield.fill",
        "key", "key.fill",
        "key.horizontal", "key.horizontal.fill",
        "shield", "shield.fill",
        "shield.lefthalf.filled", "shield.checkered",
        "checkmark.shield.fill", "xmark.shield.fill",
        "eye", "eye.fill", "eye.circle.fill",
        "eye.slash", "eye.slash.fill",
        "hand.raised", "hand.raised.fill",
        "hand.raised.circle.fill",
        "exclamationmark.lock.fill",
    ]),
    ("Media", [
        "play", "play.fill", "play.circle.fill",
        "pause", "pause.fill", "pause.circle.fill",
        "stop.fill", "stop.circle.fill",
        "backward.fill", "forward.fill",
        "backward.end.fill", "forward.end.fill",
        "shuffle", "repeat", "repeat.1",
        "speaker.fill", "speaker.wave.2.fill",
        "speaker.slash.fill",
        "music.note", "music.note.list", "music.quarternote.3",
        "headphones", "headphones.circle.fill",
        "photo", "photo.fill", "photo.circle.fill",
        "photo.on.rectangle.fill",
        "camera", "camera.fill", "camera.circle.fill",
        "film", "film.fill",
        "tv", "tv.fill", "tv.circle.fill",
        "radio", "radio.fill",
    ]),
    ("Tech", [
        "desktopcomputer", "laptopcomputer",
        "keyboard", "keyboard.fill",
        "printer", "printer.fill",
        "scanner",
        "display", "display.2",
        "iphone", "iphone.circle",
        "ipad", "applewatch",
        "airpods", "airpods.gen3",
        "wifi", "wifi.slash", "wifi.circle.fill",
        "antenna.radiowaves.left.and.right",
        "bluetooth",
        "battery.100", "battery.25", "battery.0",
        "cpu", "memorychip",
        "network", "server.rack",
        "bolt", "bolt.fill", "bolt.circle.fill", "bolt.slash.fill",
        "powerplug", "powerplug.fill",
    ]),
    ("Location & Travel", [
        "location", "location.fill", "location.circle.fill",
        "location.slash.fill",
        "location.north.fill",
        "map", "map.fill",
        "mappin", "mappin.circle.fill",
        "mappin.and.ellipse",
        "globe", "globe.americas.fill",
        "globe.europe.africa.fill", "globe.asia.australia.fill",
        "car", "car.fill", "car.circle.fill",
        "car.2.fill",
        "airplane", "airplane.circle.fill",
        "bicycle", "bicycle.circle",
        "bus", "bus.fill",
        "tram", "tram.fill",
        "ferry", "ferry.fill",
        "fuelpump", "fuelpump.fill",
    ]),
    ("Weather & Nature", [
        "sun.max", "sun.max.fill", "sun.min.fill",
        "moon", "moon.fill", "moon.circle.fill",
        "cloud", "cloud.fill",
        "cloud.rain", "cloud.rain.fill",
        "cloud.bolt", "cloud.bolt.fill",
        "cloud.snow", "cloud.snow.fill",
        "wind", "tornado", "snowflake",
        "flame", "flame.fill", "flame.circle.fill",
        "drop", "drop.fill",
        "leaf", "leaf.fill", "leaf.circle.fill",
        "tree", "tree.fill",
        "mountain.2", "mountain.2.fill",
        "globe.americas",
    ]),
    ("Math & Symbols", [
        "checkmark", "checkmark.circle.fill", "checkmark.square.fill",
        "xmark", "xmark.circle.fill", "xmark.square.fill",
        "plus", "plus.circle.fill",
        "minus", "minus.circle.fill",
        "multiply", "multiply.circle.fill",
        "divide", "divide.circle",
        "equal", "equal.circle.fill",
        "lessthan", "greaterthan", "lessthan.circle", "greaterthan.circle",
        "percent",
        "info.circle.fill",
        "questionmark.circle.fill",
        "exclamationmark.circle.fill",
        "exclamationmark.triangle.fill",
        "ellipsis.circle.fill",
        "square.grid.2x2.fill", "square.grid.3x3.fill",
        "circle.grid.2x2.fill", "circle.grid.3x3.fill",
        "dot.squareshape.fill",
    ]),
    ("Shopping & Finance", [
        "cart", "cart.fill", "cart.circle.fill",
        "cart.badge.plus", "cart.badge.minus",
        "bag", "bag.fill", "bag.circle.fill",
        "creditcard", "creditcard.fill", "creditcard.circle.fill",
        "banknote", "banknote.fill",
        "dollarsign.circle", "dollarsign.circle.fill",
        "eurosign.circle", "eurosign.circle.fill",
        "sterlingsign.circle", "sterlingsign.circle.fill",
        "chart.bar", "chart.bar.fill",
        "chart.pie", "chart.pie.fill",
        "chart.line.uptrend.xyaxis",
        "chart.line.downtrend.xyaxis",
        "arrow.up.right.circle.fill",
        "building.2", "building.2.fill",
        "building.columns", "building.columns.fill",
    ]),
]

// MARK: - IconPickerView

struct IconPickerView: View {
    @Binding var selectedIcon: String?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = Array(repeating: GridItem(.fixed(40), spacing: 2), count: 7)

    private var filteredIcons: [(String, [String])] {
        if searchText.isEmpty { return iconCatalogue }
        let q = searchText.lowercased()
        return iconCatalogue.compactMap { cat, icons in
            let hit = icons.filter { $0.contains(q) }
            return hit.isEmpty ? nil : (cat, hit)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            iconGrid
            Divider()
            footer
        }
        .frame(width: 320, height: 500)
    }

    // MARK: Sub-views

    private var header: some View {
        HStack {
            Text("Choose Icon")
                .font(.headline)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField("Search icons…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var iconGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                ForEach(filteredIcons, id: \.0) { category, icons in
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 2) {
                            ForEach(icons, id: \.self) { icon in
                                iconCell(icon)
                            }
                        }
                    } header: {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }

    private func iconCell(_ icon: String) -> some View {
        Button {
            selectedIcon = icon
            dismiss()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 36, height: 36)
                .background(
                    selectedIcon == icon
                        ? Color.accentColor.opacity(0.18)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(icon)
    }

    private var footer: some View {
        HStack {
            if let current = selectedIcon, !current.isEmpty {
                Button("Remove icon") {
                    selectedIcon = nil
                    dismiss()
                }
                .foregroundStyle(.red)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}
