import SwiftUI

/// Whole-number text field that updates its value live while typing (digits only).
struct IntField: View {
    let title: String
    @Binding var value: Int?
    var maxDigits = 7

    var body: some View {
        TextField(title, text: Binding(
            get: { value.map { String($0) } ?? "" },
            set: { text in
                let digits = text.filter { $0.isASCII && $0.isNumber }.prefix(maxDigits)
                value = Int(digits)
            }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
    }
}

/// Non-optional convenience: empty field = 0.
struct ZeroIntField: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        IntField(title: title, value: Binding(
            get: { value == 0 ? nil : value },
            set: { value = $0 ?? 0 }
        ))
    }
}

/// Decimal field (e.g. "2.5 candy per day"). Accepts "." or "," as the decimal separator.
struct DecimalField: View {
    let title: String
    @Binding var value: Double
    @State private var text = ""

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .onAppear { text = value == 0 ? "" : Self.format(value) }
            .onChange(of: text) { _, newText in
                let cleaned = newText.replacingOccurrences(of: ",", with: ".")
                    .filter { $0.isASCII && ($0.isNumber || $0 == ".") }
                value = Double(cleaned) ?? 0
            }
    }

    static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
