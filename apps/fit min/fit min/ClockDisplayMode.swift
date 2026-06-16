enum ClockDisplayMode: String, CaseIterable, Identifiable {
    case repsOnly
    case intervalTimeOverReps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repsOnly:
            return "Reps"
        case .intervalTimeOverReps:
            return "Interval over reps"
        }
    }
}
