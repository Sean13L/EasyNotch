import Foundation

/// Quotes a string so `/bin/sh` reads it back as one literal word.
nonisolated enum ShellQuote {
    /// Wraps the string in single quotes; each `'` inside becomes `'\''`.
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
