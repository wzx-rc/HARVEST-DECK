import SwiftUI
import WidgetKit

// MARK: - Widget

struct HarvestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HarvestTimers", provider: Provider()) { entry in
            HarvestWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.ground }
        }
        .configurationDisplayName("Minuteurs")
        .description("Ce qui est prêt et ce qui arrive bientôt sur ta ferme.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct HarvestWidgets: WidgetBundle {
    var body: some Widget { HarvestWidget() }
}
