import Foundation

extension Bundle {
    /// The version shown to users, e.g. "0.1.0" (from MARKETING_VERSION in project.yml).
    nonisolated var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
