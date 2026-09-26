import ServiceManagement

/// Starting EasyNotch automatically when you log in. macOS keeps track of this itself (it's
/// not an EasyNotch setting), and the switch in Settings → General reads and changes it.
enum LoginItem {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// System Settings → General → Login Items, where macOS may ask you to approve it.
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
