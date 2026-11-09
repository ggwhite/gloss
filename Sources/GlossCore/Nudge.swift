import Foundation

/// A daily window without notifications, e.g. 22:00–09:00. It may wrap past midnight.
public struct QuietHours: Codable, Equatable, Sendable {
    /// Minutes after midnight.
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    public init(startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0) {
        self.init(start: startHour * 60 + startMinute, end: endHour * 60 + endMinute)
    }

    public static let `default` = QuietHours(startHour: 22, endHour: 9)

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if start == end { return false }
        if start < end { return m >= start && m < end }
        return m >= start || m < end
    }

    public static func format(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

public enum NudgePolicy {
    /// True when a reminder should go out now.
    public static func shouldNudge(now: Date, lastNudge: Date?, intervalMinutes: Int, dueCount: Int,
                                   quiet: QuietHours, calendar: Calendar) -> Bool {
        guard dueCount > 0, intervalMinutes > 0 else { return false }
        guard !quiet.contains(now, calendar: calendar) else { return false }
        guard let last = lastNudge else { return true }
        return now.timeIntervalSince(last) >= TimeInterval(intervalMinutes * 60)
    }
}
