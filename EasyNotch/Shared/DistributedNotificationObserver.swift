import Foundation

/// Listens for a system-wide ("distributed") notification posted by another app.
///
/// Delivery is set to immediate. Otherwise macOS holds these notifications until the app
/// becomes active, which an agent app like EasyNotch almost never is.
final class DistributedNotificationObserver: NSObject {
    private let handler: (Notification) -> Void

    init(name: String, handler: @escaping (Notification) -> Void) {
        self.handler = handler
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receive(_:)),
            name: NSNotification.Name(name),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    func invalidate() {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func receive(_ notification: Notification) {
        handler(notification)
    }
}
