import SwiftUI

/// The desktop app's warm wood palette and fonts.
enum Theme {
    static let ground = Color(hex: 0x1B1416)
    static let surface = Color(hex: 0x251B1E)
    static let raise = Color(hex: 0x30242A)
    static let line = Color(hex: 0x3D2F35)
    static let text = Color(hex: 0xF3E6D2)
    static let dim = Color(hex: 0xB59C88)
    static let faint = Color(hex: 0x9A826F)
    static let gold = Color(hex: 0xF2BF45)
    static let onGold = Color(hex: 0x2A1D10)
    static let wheat = Color(hex: 0xE0A85C)
    static let sheep = Color(hex: 0x86B86A)
    static let glass = Color(hex: 0x55A99D)
    static let ore = Color(hex: 0x8D9FB8)
    static let wood = Color(hex: 0xB07A4F)
    static let fruit = Color(hex: 0xD9645A)
    static let honey = Color(hex: 0xE8B93C)
    static let loss = Color(hex: 0xE2685A)
    static let sky = Color(hex: 0x5B93D3)
    static let ready = Color(hex: 0xCFE8BF)

    static func display(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "BricolageGrotesque-Bold" : "BricolageGrotesque-SemiBold", size: size, relativeTo: .title)
    }
    static func body(_ size: CGFloat = 15, semibold: Bool = false) -> Font {
        .custom(semibold ? "InstrumentSans-SemiBold" : "InstrumentSans-Regular", size: size, relativeTo: .body)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Colour and SF Symbol of each timer group (same colours as the desktop widget).
enum GroupLook {
    static func color(_ key: String) -> Color {
        switch key {
        case "crops", "machine": return Theme.wheat
        case "greenhouse": return Theme.glass
        case "fruits", "flowers": return Theme.fruit
        case "trees", "compost": return Theme.wood
        case "stone", "iron": return Theme.ore
        case "gold", "sunstone", "cooking", "power": return Theme.gold
        case "crimstone": return Theme.loss
        case "oil", "crabs": return Theme.sky
        case "chickens", "cows", "sheep", "pigs": return Theme.sheep
        case "honey": return Theme.honey
        default: return Theme.dim
        }
    }

    static func symbol(_ key: String) -> String {
        switch key {
        case "crops": return "leaf.fill"
        case "greenhouse": return "drop.fill"
        case "machine": return "gearshape.2.fill"
        case "fruits": return "applelogo"
        case "flowers": return "camera.macro"
        case "trees": return "tree.fill"
        case "stone": return "mountain.2.fill"
        case "iron", "gold", "crimstone", "sunstone": return "diamond.fill"
        case "oil": return "fuelpump.fill"
        case "chickens": return "bird.fill"
        case "cows", "sheep", "pigs": return "pawprint.fill"
        case "honey": return "hexagon.fill"
        case "compost": return "arrow.3.trianglepath"
        case "cooking": return "frying.pan.fill"
        case "aging": return "hourglass"
        case "crabs": return "water.waves"
        case "power": return "bolt.fill"
        default: return "clock.fill"
        }
    }
}
