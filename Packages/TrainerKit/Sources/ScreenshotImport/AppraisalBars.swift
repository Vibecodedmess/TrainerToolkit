import Foundation

/// Reads how full an appraisal bar is from one row of pixels.
///
/// A bar is a run of coloured (filled) pixels followed by light grey (empty) pixels on a white card.
/// The white dividers between the bar's three segments are only a few pixels wide; a longer white
/// gap ends the bar, so whatever is drawn to the right of the card is ignored.
public enum AppraisalBars {
    public struct Pixel: Hashable, Sendable {
        public var r: UInt8
        public var g: UInt8
        public var b: UInt8
        public init(r: UInt8, g: UInt8, b: UInt8) {
            self.r = r
            self.g = g
            self.b = b
        }
    }

    enum Kind { case filled, empty, background }

    static func kind(_ p: Pixel) -> Kind {
        let mx = Double(max(p.r, p.g, p.b)), mn = Double(min(p.r, p.g, p.b))
        let saturation = mx == 0 ? 0 : (mx - mn) / mx
        if saturation > 0.35 { return .filled }
        if mx < 245 && saturation < 0.12 { return .empty }
        return .background
    }

    public struct Measurement: Hashable, Sendable {
        /// Pixel index where the bar starts and ends (inclusive) in the row.
        public let start: Int
        public let end: Int
        /// Share of the bar that is filled, 0…1.
        public let fraction: Double
        public var length: Int { end - start + 1 }
    }

    /// Measures the first bar in the row. `maxGap` = longest white run still counted as a divider.
    /// `maxStart`: a bar must start within this many pixels of the row's start (rows between the bars
    /// would otherwise "find" whatever is drawn right of the card).
    public static func measure(_ row: [Pixel], maxGap: Int = 12, maxStart: Int? = nil) -> Measurement? {
        guard let start = row.firstIndex(where: { kind($0) != .background }) else { return nil }
        if let maxStart, start > maxStart { return nil }
        var end = start
        var lastFilled = -1
        var gap = 0
        for i in start..<row.count {
            switch kind(row[i]) {
            case .background:
                gap += 1
                if gap > maxGap { return finish(start: start, end: end, lastFilled: lastFilled) }
            case .filled:
                gap = 0
                end = i
                lastFilled = i
            case .empty:
                gap = 0
                end = i
            }
        }
        return finish(start: start, end: end, lastFilled: lastFilled)
    }

    private static func finish(start: Int, end: Int, lastFilled: Int) -> Measurement {
        let length = Double(end - start + 1)
        let filled = lastFilled < start ? 0 : Double(lastFilled - start + 1)
        return Measurement(start: start, end: end, fraction: min(max(filled / length, 0), 1))
    }

    /// Several rows across the bar's height: the longest bars are the real bar (not its anti-aliased
    /// edges); their median fill is the answer.
    public static func fraction(rows: [[Pixel]], minLength: Int, maxStart: Int? = nil) -> Double? {
        let measured = rows.compactMap { measure($0, maxStart: maxStart) }.filter { $0.length >= minLength }
        guard let longest = measured.map(\.length).max() else { return nil }
        let good = measured.filter { Double($0.length) >= Double(longest) * 0.9 }.map(\.fraction).sorted()
        guard !good.isEmpty else { return nil }
        return good[good.count / 2]
    }

    /// IV from a bar's fill: each bar is 15 points long.
    public static func iv(fromFraction fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 15).rounded())
    }
}
