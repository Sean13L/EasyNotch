import Foundation
import Observation

/// Describes one numeric setting: where it's saved, its default, and its allowed range.
nonisolated struct NumericSetting: Sendable {
    let key: String
    let defaultValue: Double
    let range: ClosedRange<Double>
}

extension NumericSetting {
    static let hoverDelay = NumericSetting(key: "notch.hoverDelay", defaultValue: 0.15, range: 0...1)
    static let closeDelay = NumericSetting(key: "notch.closeDelay", defaultValue: 0.15, range: 0...1.5)
    static let hotZoneMargin = NumericSetting(key: "notch.hotZoneMargin", defaultValue: 8, range: 0...30)
    static let expandedWidth = NumericSetting(key: "notch.expandedWidth", defaultValue: 640, range: 400...900)
    static let expandedHeight = NumericSetting(key: "notch.expandedHeight", defaultValue: 200, range: 120...400)
}

/// Every user-adjustable option. Each value loads from UserDefaults (falling back to its
/// default) and saves the moment it changes; views reading it update live.
@Observable
final class AppSettings {
    // MARK: Behavior

    /// Seconds the pointer must rest on the notch before it opens.
    var hoverDelay: Double { didSet { save(hoverDelay, .hoverDelay) } }
    /// Seconds the pointer can be away from the open notch before it closes.
    var closeDelay: Double { didSet { save(closeDelay, .closeDelay) } }
    /// Extra points around the notch that still count as hovering it.
    var hotZoneMargin: Double { didSet { save(hotZoneMargin, .hotZoneMargin) } }
    /// A light trackpad tap when the notch opens (Force Touch trackpads only).
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Self.hapticsKey) } }

    // MARK: Size

    var expandedWidth: Double { didSet { save(expandedWidth, .expandedWidth) } }
    var expandedHeight: Double { didSet { save(expandedHeight, .expandedHeight) } }

    // MARK: Storage

    @ObservationIgnored private let defaults: UserDefaults
    private static let hapticsKey = "notch.hapticsEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hoverDelay = Self.load(.hoverDelay, from: defaults)
        closeDelay = Self.load(.closeDelay, from: defaults)
        hotZoneMargin = Self.load(.hotZoneMargin, from: defaults)
        hapticsEnabled = defaults.object(forKey: Self.hapticsKey) as? Bool ?? true
        expandedWidth = Self.load(.expandedWidth, from: defaults)
        expandedHeight = Self.load(.expandedHeight, from: defaults)
    }

    func resetToDefaults() {
        hoverDelay = NumericSetting.hoverDelay.defaultValue
        closeDelay = NumericSetting.closeDelay.defaultValue
        hotZoneMargin = NumericSetting.hotZoneMargin.defaultValue
        hapticsEnabled = true
        expandedWidth = NumericSetting.expandedWidth.defaultValue
        expandedHeight = NumericSetting.expandedHeight.defaultValue
    }

    private func save(_ value: Double, _ setting: NumericSetting) {
        defaults.set(value, forKey: setting.key)
    }

    /// Reads a saved value, clamped into range in case an older version saved something
    /// that's no longer allowed.
    private static func load(_ setting: NumericSetting, from defaults: UserDefaults) -> Double {
        guard let saved = defaults.object(forKey: setting.key) as? Double else {
            return setting.defaultValue
        }
        return min(max(saved, setting.range.lowerBound), setting.range.upperBound)
    }
}
