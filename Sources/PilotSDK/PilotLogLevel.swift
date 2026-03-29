import Foundation

public enum PilotLogLevel: String, Sendable, Comparable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    case exception = "exception"

    private var order: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        case .exception: return 5
        }
    }

    public static func < (lhs: PilotLogLevel, rhs: PilotLogLevel) -> Bool {
        return lhs.order < rhs.order
    }
}
