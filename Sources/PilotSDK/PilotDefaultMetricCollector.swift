import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class PilotDefaultMetricCollector: PilotMetricCollector {
    func collect(_ out: inout [PilotMetricEntry]) {
        // Memory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            out.append(PilotMetricEntry(.memory, Double(info.resident_size)))
        }

        // Thread count
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let threadResult = task_threads(mach_task_self_, &threadList, &threadCount)
        if threadResult == KERN_SUCCESS {
            out.append(PilotMetricEntry(.threadCount, Double(threadCount)))
            if let threadList = threadList {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(Int(threadCount) * MemoryLayout<thread_act_t>.size))
            }
        }

        // Battery
        #if canImport(UIKit) && !os(watchOS)
        DispatchQueue.main.sync {
            let device = UIDevice.current
            let wasMonitoring = device.isBatteryMonitoringEnabled
            device.isBatteryMonitoringEnabled = true

            if device.batteryLevel >= 0 {
                out.append(PilotMetricEntry(.batteryLevel, Double(device.batteryLevel * 100)))
            }

            let isCharging = device.batteryState == .charging || device.batteryState == .full
            out.append(PilotMetricEntry(.batteryCharging, isCharging ? 1.0 : 0.0))

            if !wasMonitoring {
                device.isBatteryMonitoringEnabled = false
            }
        }
        #endif
    }
}
