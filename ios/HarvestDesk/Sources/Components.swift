import SwiftUI

/// A warm card, like the desktop app's.
struct Card<Content: View>: View {
    var title: String?
    var hint: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.display(17)).foregroundStyle(Theme.text)
                    if let hint { Text(hint).font(Theme.body(13)).foregroundStyle(Theme.dim) }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// One key figure: label, big value, small note.
struct Kpi: View {
    var label: String
    var value: String
    var note: String?
    var gold = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Theme.body(13)).foregroundStyle(Theme.dim)
            Text(value).font(Theme.display(30, bold: true)).foregroundStyle(gold ? Theme.gold : Theme.text)
                .minimumScaleFactor(0.6).lineLimit(1)
            if let note { Text(note).font(Theme.body(12.5)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// A thin bar, 0…1.
struct Bar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().fill(color).frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Page frame: dark ground, scroll, readable width on iPad.
struct Page<Content: View>: View {
    var title: String
    @EnvironmentObject var store: Store
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(title)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await store.refresh(force: true) } } label: {
                    if store.status == .loading { ProgressView().tint(Theme.gold) } else { Image(systemName: "arrow.clockwise") }
                }
                .tint(Theme.gold)
                .accessibilityLabel("Mettre à jour")
            }
        }
        .refreshable { await store.refresh(force: true) }
    }
}

/// Banner for setup, errors, missing data.
struct Notice: View {
    var icon: String
    var text: String
    var color: Color = Theme.gold

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(Theme.body(14)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum Fmt {
    static func num(_ v: Double, _ digits: Int = 0) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "fr_FR"); f.numberStyle = .decimal
        f.minimumFractionDigits = digits; f.maximumFractionDigits = digits
        return (f.string(from: NSNumber(value: v)) ?? "\(v)").replacingOccurrences(of: "-", with: "−")
    }
    static func usd(_ v: Double) -> String { (abs(v) >= 100 ? num(v) : num(v, 2)) + " $" }
    static func signedUsd(_ v: Double) -> String { (v < 0 ? "−" : "+") + usd(abs(v)) }
    static func day(_ ms: Double, _ format: String = "d MMM") -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = format
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
}
