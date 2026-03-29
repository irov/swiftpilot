import Foundation

public protocol PilotLoggerListener: AnyObject {
    func onPilotLoggerMessage(_ level: PilotLogLevel, tag: String, message: String, error: Error?)
}
