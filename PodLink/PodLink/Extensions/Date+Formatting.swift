import Foundation

extension Date {
    var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDisplay: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.dateComponents([.day], from: self, to: Date()).day ?? 0 < 7 {
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: self)
        } else if calendar.component(.year, from: self) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: self)
        }
    }
}
