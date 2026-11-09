import Foundation

/// A calendar day as `yyyy-MM-dd`. Strings of this shape sort in date order.
public struct Day: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let iso: String

    public init?(iso: String) {
        let parts = iso.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return nil }
        self.iso = iso
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        iso = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func adding(days: Int, calendar: Calendar) -> Day {
        Day(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar))!, calendar: calendar)
    }

    public func date(calendar: Calendar) -> Date {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))!
    }

    public static func < (a: Day, b: Day) -> Bool { a.iso < b.iso }
    public var description: String { iso }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = Day(iso: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad day \(s)"))
        }
        self = d
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }
}
