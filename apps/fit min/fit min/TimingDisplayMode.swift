enum TimingDisplayMode: String, CaseIterable, Identifiable {
    case inclusive
    case exclusive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inclusive:
            return "Inclusive"
        case .exclusive:
            return "Exclusive"
        }
    }
}

enum TimerDetailEditButtonPlacement: String, CaseIterable, Identifiable {
    case topRight
    case bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topRight:
            return "Top Right"
        case .bottomRight:
            return "Bottom Right"
        }
    }
}

enum TimerDetailControlsPlacement: String, CaseIterable, Identifiable {
    case belowMetadata
    case lowerCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .belowMetadata:
            return "Below Metadata"
        case .lowerCenter:
            return "Lower Center"
        }
    }
}
