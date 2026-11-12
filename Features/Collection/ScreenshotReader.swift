import UIKit
import Vision
import ScreenshotImport

/// Everything read from one screenshot.
struct ScreenshotScan: Sendable {
    let reading: ScreenReading
    /// Appraisal bar fill (0…1) per stat, when the appraisal box is on this screenshot.
    let barFractions: [AppraisalStat: Double]
}

enum ScreenshotReaderError: LocalizedError {
    case unreadableImage
    var errorDescription: String? { "That image couldn't be opened." }
}

/// On-device text recognition (Apple Vision) plus pixel measurement of the appraisal bars.
/// Nothing leaves the phone.
enum ScreenshotReader {
    /// Blocking; call it off the main thread.
    static func scan(_ data: Data) throws -> ScreenshotScan {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw ScreenshotReaderError.unreadableImage }
        let lines = try recognizeText(cgImage)
        let reading = ScreenshotParser.parse(lines)
        let bars = measureBars(cgImage, labels: reading.appraisalLabels)
        return ScreenshotScan(reading: reading, barFractions: bars)
    }

    static func recognizeText(_ image: CGImage) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Names and numbers aren't dictionary words; correction would "fix" them.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            // Vision boxes are normalised with the origin at the bottom left; the parser uses top left.
            let b = observation.boundingBox
            return RecognizedLine(text, TextBox(x: Double(b.minX), y: Double(1 - b.maxY),
                                                width: Double(b.width), height: Double(b.height)))
        }
    }

    /// Each bar sits just under its label ("Attack", "Defense", "HP"): in real screenshots its bottom
    /// is about one label-height below the label. Rows from the label's bottom to 1.6 label-heights
    /// below are measured (not further, so the card's bottom edge stays out); `AppraisalBars.fraction`
    /// keeps the full-length ones.
    static func measureBars(_ image: CGImage, labels: [AppraisalStat: TextBox]) -> [AppraisalStat: Double] {
        guard !labels.isEmpty, let pixels = RGBAImage(image) else { return [:] }
        var result: [AppraisalStat: Double] = [:]
        for (stat, box) in labels {
            let labelHeight = max(4, Int(box.height * Double(pixels.height)))
            let x0 = max(0, Int(box.minX * Double(pixels.width)) - labelHeight)
            let yStart = min(pixels.height - 1, Int(box.maxY * Double(pixels.height)))
            let yEnd = min(pixels.height - 1, yStart + labelHeight * 8 / 5)
            guard yStart < yEnd else { continue }
            let rows = (yStart...yEnd).map { pixels.row($0, from: x0) }
            // The bar starts under the label's left edge, which is one label-height right of x0.
            if let fraction = AppraisalBars.fraction(rows: rows, minLength: labelHeight * 4, maxStart: labelHeight * 2) {
                result[stat] = fraction
            }
        }
        return result
    }
}

/// An image redrawn as 8-bit RGBA, top row first.
private struct RGBAImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init?(_ image: CGImage) {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        width = w
        height = h
        bytes = buffer
    }

    func row(_ y: Int, from x0: Int) -> [AppraisalBars.Pixel] {
        guard y >= 0, y < height, x0 < width else { return [] }
        var pixels: [AppraisalBars.Pixel] = []
        pixels.reserveCapacity(width - x0)
        var i = (y * width + x0) * 4
        for _ in x0..<width {
            pixels.append(AppraisalBars.Pixel(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2]))
            i += 4
        }
        return pixels
    }
}
