import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Checks system conditions before attempting network uploads.
/// Modeled after Datadog's approach: battery, low-power mode, network reachability.
internal struct UploadConditions {

    enum Blocker: String {
        case lowBattery = "Battery level below threshold"
        case lowPowerMode = "Low power mode enabled"
    }

    /// Minimum battery level (fraction 0–1) above which uploads are allowed.
    static let minimumBatteryLevel: Float = 0.1

    /// Returns blockers preventing upload. Empty array means upload is allowed.
    static func currentBlockers() -> [Blocker] {
        var blockers: [Blocker] = []

        #if canImport(UIKit) && !os(watchOS)
        checkBattery(&blockers)
        checkLowPowerMode(&blockers)
        #endif

        return blockers
    }

    #if canImport(UIKit) && !os(watchOS)
    private static func checkBattery(_ blockers: inout [Blocker]) {
        let device = UIDevice.current
        let wasMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer {
            if !wasMonitoring { device.isBatteryMonitoringEnabled = false }
        }

        let state = device.batteryState
        let level = device.batteryLevel

        // If charging, full, or unknown (e.g. simulator), allow uploads
        if state == .charging || state == .full || state == .unknown {
            return
        }

        // On battery power — check level
        if level >= 0 && level < minimumBatteryLevel {
            blockers.append(.lowBattery)
        }
    }

    private static func checkLowPowerMode(_ blockers: inout [Blocker]) {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            blockers.append(.lowPowerMode)
        }
    }
    #endif
}
