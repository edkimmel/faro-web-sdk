import Foundation

/// Protocol abstracting background task management for upload protection.
/// Two implementations: one for apps (UIKit), one for extensions (ProcessInfo).
internal protocol BackgroundTaskCoordinator: AnyObject {
    func beginBackgroundTask()
    func endBackgroundTask()
}

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Requests additional background execution time via UIApplication.beginBackgroundTask.
/// Gives the OS up to ~30 seconds to complete in-flight uploads before suspension.
internal final class AppBackgroundTaskCoordinator: BackgroundTaskCoordinator {
    private let lock = NSLock()
    private var currentTaskId: UIBackgroundTaskIdentifier = .invalid

    func beginBackgroundTask() {
        lock.lock()
        // End any existing task before starting a new one
        endExistingTaskLocked()

        currentTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Expiration handler — system is about to suspend, clean up
            self?.endBackgroundTask()
        }
        lock.unlock()
    }

    func endBackgroundTask() {
        lock.lock()
        endExistingTaskLocked()
        lock.unlock()
    }

    private func endExistingTaskLocked() {
        guard currentTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(currentTaskId)
        currentTaskId = .invalid
    }
}
#endif

/// For app extensions where UIApplication is unavailable.
/// Uses ProcessInfo.beginActivity to prevent the system from suspending the process.
internal final class ExtensionBackgroundTaskCoordinator: BackgroundTaskCoordinator {
    private let lock = NSLock()
    private var currentActivity: NSObjectProtocol?

    func beginBackgroundTask() {
        lock.lock()
        endExistingActivityLocked()
        currentActivity = ProcessInfo.processInfo.beginActivity(
            options: [.background],
            reason: "Faro SDK background upload"
        )
        lock.unlock()
    }

    func endBackgroundTask() {
        lock.lock()
        endExistingActivityLocked()
        lock.unlock()
    }

    private func endExistingActivityLocked() {
        guard let activity = currentActivity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        currentActivity = nil
    }
}
