import Foundation

public enum ParameterNumericInput {
    public enum Error: Swift.Error, Equatable { case empty, invalid, nonFinite
        public var message: String { switch self { case .empty: return "Enter a number."; case .invalid: return "Enter a valid numeric value."; case .nonFinite: return "Number must be finite." } }
    }
    public static func parse(_ text: String) -> Result<Double, Error> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let value = Double(trimmed) else { return .failure(.invalid) }
        guard value.isFinite else { return .failure(.nonFinite) }
        return .success(value)
    }
}
