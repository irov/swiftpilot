import Foundation

public protocol PilotMetricCollector: AnyObject {
    func collect(_ out: inout [PilotMetricEntry])
}
