/// Unit used by trigonometric functions.
public enum AngleMode: String, Sendable, Codable, Hashable, CaseIterable {
    case degrees = "deg"
    case radians = "rad"

    public var toggled: AngleMode { self == .degrees ? .radians : .degrees }

    /// Short label shown on the keypad ("Deg" / "Rad").
    public var shortLabel: String { self == .degrees ? "Deg" : "Rad" }
}
