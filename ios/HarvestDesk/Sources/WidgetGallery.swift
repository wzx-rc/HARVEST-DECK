import SwiftUI
import WidgetKit

/// The widget's faces drawn inside the app, for the CI screenshots (-tab gallery).
struct WidgetGallery: View {
    @EnvironmentObject var store: Store

    private var entry: FarmEntry {
        let groups = store.groups(at: .now).filter { store.follow.contains($0.key) }.sorted { $0.sortKey < $1.sortKey }
        return FarmEntry(date: .now, groups: groups, readAt: store.fetchedAt, empty: groups.isEmpty)
    }

    private func face(_ family: WidgetFamily, _ w: CGFloat, _ h: CGFloat) -> some View {
        HarvestWidgetView(entry: entry)
            .environment(\.widgetFamily, family)
            .padding(16)
            .frame(width: w, height: h)
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    face(.systemSmall, 170, 170)
                    VStack(alignment: .leading, spacing: 8) {
                        HarvestWidgetView(entry: entry).environment(\.widgetFamily, .accessoryRectangular)
                            .frame(width: 160, height: 72).foregroundStyle(.white)
                        HarvestWidgetView(entry: entry).environment(\.widgetFamily, .accessoryInline).foregroundStyle(.white)
                    }
                }
                face(.systemMedium, 364, 170)
                face(.systemLarge, 364, 382)
            }
            .padding()
        }
        .background(LinearGradient(colors: [Color(hex: 0x3B5A6B), Color(hex: 0x22262C), Color(hex: 0x6B4A3A)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
    }
}
