import AppKit
import SwiftUI

public enum BoardTheme: String, CaseIterable, Identifiable {
    case shadowNocturne = "Shadow Nocturne"
    case royalWalnut = "Royal Walnut"
    case alabasterMarble = "Alabaster Marble"
    case cyberDusk = "Cyber Dusk"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .shadowNocturne: return "Obsidian slate & warm gold"
        case .royalWalnut: return "Heirloom walnut & maple"
        case .alabasterMarble: return "Carrara stone & smoky quartz"
        case .cyberDusk: return "Midnight indigo & cyan"
        }
    }

    public var lightSquareTop: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.25, green: 0.28, blue: 0.35, alpha: 1.0)
        case .royalWalnut: return NSColor(srgbRed: 0.90, green: 0.81, blue: 0.67, alpha: 1.0)
        case .alabasterMarble: return NSColor(srgbRed: 0.92, green: 0.93, blue: 0.95, alpha: 1.0)
        case .cyberDusk: return NSColor(srgbRed: 0.19, green: 0.24, blue: 0.37, alpha: 1.0)
        }
    }

    public var lightSquareBottom: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.21, green: 0.24, blue: 0.30, alpha: 1.0)
        case .royalWalnut: return NSColor(srgbRed: 0.84, green: 0.74, blue: 0.59, alpha: 1.0)
        case .alabasterMarble: return NSColor(srgbRed: 0.85, green: 0.87, blue: 0.90, alpha: 1.0)
        case .cyberDusk: return NSColor(srgbRed: 0.16, green: 0.20, blue: 0.32, alpha: 1.0)
        }
    }

    public var darkSquareTop: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.11, green: 0.13, blue: 0.18, alpha: 1.0)
        case .royalWalnut: return NSColor(srgbRed: 0.48, green: 0.31, blue: 0.20, alpha: 1.0)
        case .alabasterMarble: return NSColor(srgbRed: 0.44, green: 0.49, blue: 0.56, alpha: 1.0)
        case .cyberDusk: return NSColor(srgbRed: 0.09, green: 0.11, blue: 0.20, alpha: 1.0)
        }
    }

    public var darkSquareBottom: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        case .royalWalnut: return NSColor(srgbRed: 0.40, green: 0.25, blue: 0.16, alpha: 1.0)
        case .alabasterMarble: return NSColor(srgbRed: 0.38, green: 0.42, blue: 0.49, alpha: 1.0)
        case .cyberDusk: return NSColor(srgbRed: 0.07, green: 0.08, blue: 0.15, alpha: 1.0)
        }
    }

    public var boardFrameColor: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
        case .royalWalnut: return NSColor(srgbRed: 0.23, green: 0.14, blue: 0.09, alpha: 1.0)
        case .alabasterMarble: return NSColor(srgbRed: 0.18, green: 0.21, blue: 0.26, alpha: 1.0)
        case .cyberDusk: return NSColor(srgbRed: 0.05, green: 0.06, blue: 0.12, alpha: 1.0)
        }
    }

    public var accentNSColor: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.91, green: 0.74, blue: 0.36, alpha: 1.0)
        case .royalWalnut: return NSColor(srgbRed: 0.93, green: 0.72, blue: 0.30, alpha: 1.0)
        case .alabasterMarble: return NSColor(srgbRed: 0.34, green: 0.64, blue: 0.92, alpha: 1.0)
        case .cyberDusk: return NSColor(srgbRed: 0.24, green: 0.85, blue: 0.96, alpha: 1.0)
        }
    }

    public var accentColor: Color {
        Color(nsColor: accentNSColor)
    }

    public var lastMoveHighlight: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.92, green: 0.75, blue: 0.32, alpha: 0.28)
        case .royalWalnut: return NSColor(srgbRed: 0.96, green: 0.82, blue: 0.28, alpha: 0.36)
        case .alabasterMarble: return NSColor(srgbRed: 0.28, green: 0.62, blue: 0.95, alpha: 0.32)
        case .cyberDusk: return NSColor(srgbRed: 0.20, green: 0.85, blue: 0.96, alpha: 0.28)
        }
    }

    public var selectedSquareHighlight: NSColor {
        switch self {
        case .shadowNocturne: return NSColor(srgbRed: 0.95, green: 0.78, blue: 0.36, alpha: 0.42)
        case .royalWalnut: return NSColor(srgbRed: 0.98, green: 0.84, blue: 0.32, alpha: 0.46)
        case .alabasterMarble: return NSColor(srgbRed: 0.25, green: 0.64, blue: 0.98, alpha: 0.42)
        case .cyberDusk: return NSColor(srgbRed: 0.24, green: 0.88, blue: 0.98, alpha: 0.40)
        }
    }
}
