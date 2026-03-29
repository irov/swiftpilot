import Foundation
import os.log

final class PilotLog {
    static let tag = "PilotSDK"
    private static var level: PilotLogLevel = .info
    private static weak var loggerListener: PilotLoggerListener?

    static func setLevel(_ level: PilotLogLevel) {
        self.level = level
    }

    static func setLoggerListener(_ listener: PilotLoggerListener?) {
        self.loggerListener = listener
    }

    static func d(_ message: String, _ args: CVarArg...) {
        guard level <= .debug else { return }
        let msg = args.isEmpty ? message : String(format: message, arguments: args)
        if let listener = loggerListener {
            listener.onPilotLoggerMessage(.debug, tag: tag, message: msg, error: nil)
        } else {
            os_log(.debug, "%{public}@: %{public}@", tag, msg)
        }
    }

    static func i(_ message: String, _ args: CVarArg...) {
        guard level <= .info else { return }
        let msg = args.isEmpty ? message : String(format: message, arguments: args)
        if let listener = loggerListener {
            listener.onPilotLoggerMessage(.info, tag: tag, message: msg, error: nil)
        } else {
            os_log(.info, "%{public}@: %{public}@", tag, msg)
        }
    }

    static func w(_ message: String, _ args: CVarArg...) {
        guard level <= .warning else { return }
        let msg = args.isEmpty ? message : String(format: message, arguments: args)
        if let listener = loggerListener {
            listener.onPilotLoggerMessage(.warning, tag: tag, message: msg, error: nil)
        } else {
            os_log(.default, "%{public}@: %{public}@", tag, msg)
        }
    }

    static func e(_ message: String, _ args: CVarArg...) {
        guard level <= .error else { return }
        let msg = args.isEmpty ? message : String(format: message, arguments: args)
        if let listener = loggerListener {
            listener.onPilotLoggerMessage(.error, tag: tag, message: msg, error: nil)
        } else {
            os_log(.error, "%{public}@: %{public}@", tag, msg)
        }
    }

    static func e(_ message: String, _ error: Error) {
        if let listener = loggerListener {
            listener.onPilotLoggerMessage(.exception, tag: tag, message: message, error: error)
        } else {
            os_log(.error, "%{public}@: %{public}@ — %{public}@", tag, message, error.localizedDescription)
        }
    }
}
