import Foundation

// MARK: - ObjC-compatible enums

@objc(PilotObjCLogLevel)
public enum PilotObjCLogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    case exception = 5

    var swift: PilotLogLevel {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        case .exception: return .exception
        }
    }

    static func from(_ swift: PilotLogLevel) -> PilotObjCLogLevel {
        switch swift {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        case .exception: return .exception
        }
    }
}

@objc(PilotObjCSessionStatus)
public enum PilotObjCSessionStatus: Int {
    case disconnected = 0
    case connecting = 1
    case waitingApproval = 2
    case active = 3
    case authFailed = 4
    case rejected = 5
    case closed = 6
    case error = 7
}

// MARK: - ObjC-compatible protocols

@objc(PilotObjCSessionDelegate)
public protocol PilotObjCSessionDelegate {
    @objc func onPilotSessionConnecting()
    @objc func onPilotSessionWaitingApproval(_ requestId: String)
    @objc func onPilotSessionStarted(_ sessionToken: String)
    @objc func onPilotSessionClosed()
    @objc func onPilotSessionRejected()
    @objc func onPilotSessionAuthFailed()
    @objc func onPilotSessionError(_ message: String)
}

@objc(PilotObjCActionDelegate)
public protocol PilotObjCActionDelegate {
    @objc func onPilotActionReceived(_ actionId: String, widgetId: Int, actionType: String)
}

@objc(PilotObjCLoggerDelegate)
public protocol PilotObjCLoggerDelegate {
    @objc func onPilotLoggerMessage(_ level: PilotObjCLogLevel, tag: String, message: String)
}

// MARK: - Internal adapters

private class SessionDelegateAdapter: PilotSessionListener {
    weak var delegate: PilotObjCSessionDelegate?

    init(_ delegate: PilotObjCSessionDelegate) {
        self.delegate = delegate
    }

    func onPilotSessionConnecting() {
        delegate?.onPilotSessionConnecting()
    }

    func onPilotSessionWaitingApproval(_ requestId: String) {
        delegate?.onPilotSessionWaitingApproval(requestId)
    }

    func onPilotSessionStarted(_ sessionToken: String) {
        delegate?.onPilotSessionStarted(sessionToken)
    }

    func onPilotSessionClosed() {
        delegate?.onPilotSessionClosed()
    }

    func onPilotSessionRejected() {
        delegate?.onPilotSessionRejected()
    }

    func onPilotSessionAuthFailed() {
        delegate?.onPilotSessionAuthFailed()
    }

    func onPilotSessionError(_ error: PilotError) {
        delegate?.onPilotSessionError(error.message)
    }
}

private class ActionDelegateAdapter: PilotActionListener {
    weak var delegate: PilotObjCActionDelegate?

    init(_ delegate: PilotObjCActionDelegate) {
        self.delegate = delegate
    }

    func onPilotActionReceived(_ action: PilotAction) {
        delegate?.onPilotActionReceived(action.id, widgetId: action.widgetId, actionType: action.actionType.rawValue)
    }
}

private class LoggerDelegateAdapter: PilotLoggerListener {
    weak var delegate: PilotObjCLoggerDelegate?

    init(_ delegate: PilotObjCLoggerDelegate) {
        self.delegate = delegate
    }

    func onPilotLoggerMessage(_ level: PilotLogLevel, tag: String, message: String, error: Error?) {
        delegate?.onPilotLoggerMessage(PilotObjCLogLevel.from(level), tag: tag, message: message)
    }
}

// MARK: - ObjC-compatible config builders

@objcMembers
@objc(PilotSessionAttributeBuilder)
public class PilotObjCSessionAttributeBuilder: NSObject {
    fileprivate let attrs = PilotSessionAttributes()

    @discardableResult
    public func put(_ key: String, value: Any) -> PilotObjCSessionAttributeBuilder {
        attrs.put(key, value)
        return self
    }

    @discardableResult
    public func putProvider(_ key: String, provider: @escaping () -> Any?) -> PilotObjCSessionAttributeBuilder {
        attrs.putProvider(key, provider)
        return self
    }
}

@objcMembers
@objc(PilotLogAttributeBuilder)
public class PilotObjCLogAttributeBuilder: NSObject {
    fileprivate let attrs = PilotLogAttributes()

    @discardableResult
    public func put(_ key: String, value: Any) -> PilotObjCLogAttributeBuilder {
        attrs.put(key, value)
        return self
    }

    @discardableResult
    public func putProvider(_ key: String, provider: @escaping () -> Any?) -> PilotObjCLogAttributeBuilder {
        attrs.putProvider(key, provider)
        return self
    }
}

@objcMembers
@objc(PilotLogConfigBuilder)
public class PilotObjCLogConfigBuilder: NSObject {
    fileprivate let config = PilotLogConfig()

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> PilotObjCLogConfigBuilder {
        config.setEnabled(enabled)
        return self
    }

    @discardableResult
    public func setLogLevel(_ level: PilotObjCLogLevel) -> PilotObjCLogConfigBuilder {
        config.setLogLevel(level.swift)
        return self
    }

    @discardableResult
    public func setAttributes(_ attributes: PilotObjCLogAttributeBuilder) -> PilotObjCLogConfigBuilder {
        config.setAttributes(attributes.attrs)
        return self
    }
}

@objcMembers
@objc(PilotMetricConfigBuilder)
public class PilotObjCMetricConfigBuilder: NSObject {
    fileprivate let config = PilotMetricConfig()

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> PilotObjCMetricConfigBuilder {
        config.setEnabled(enabled)
        return self
    }

    @discardableResult
    public func setSampleIntervalMs(_ ms: Int) -> PilotObjCMetricConfigBuilder {
        config.setSampleIntervalMs(Int64(ms))
        return self
    }
}

@objcMembers
@objc(PilotConfigBuilder)
public class PilotObjCConfigBuilder: NSObject {
    fileprivate let builder: PilotConfig.Builder

    public init(apiUrl: String, apiToken: String) {
        self.builder = PilotConfig.Builder(apiUrl, apiToken)
        super.init()
    }

    @discardableResult
    public func setLoggerListener(_ listener: PilotObjCLoggerDelegate) -> PilotObjCConfigBuilder {
        let adapter = LoggerDelegateAdapter(listener)
        PilotBridge.loggerAdapter = adapter
        builder.setLoggerListener(adapter)
        return self
    }

    @discardableResult
    public func setSessionListener(_ listener: PilotObjCSessionDelegate) -> PilotObjCConfigBuilder {
        let adapter = SessionDelegateAdapter(listener)
        PilotBridge.sessionAdapter = adapter
        builder.setSessionListener(adapter)
        return self
    }

    @discardableResult
    public func setActionListener(_ listener: PilotObjCActionDelegate) -> PilotObjCConfigBuilder {
        let adapter = ActionDelegateAdapter(listener)
        PilotBridge.actionAdapter = adapter
        builder.setActionListener(adapter)
        return self
    }

    @discardableResult
    public func setSessionAttributes(_ attributes: PilotObjCSessionAttributeBuilder) -> PilotObjCConfigBuilder {
        builder.setSessionAttributes(attributes.attrs)
        return self
    }

    @discardableResult
    public func setLogConfig(_ logConfig: PilotObjCLogConfigBuilder) -> PilotObjCConfigBuilder {
        builder.setLogConfig(logConfig.config)
        return self
    }

    @discardableResult
    public func setMetricConfig(_ metricConfig: PilotObjCMetricConfigBuilder) -> PilotObjCConfigBuilder {
        builder.setMetricConfig(metricConfig.config)
        return self
    }

    public func build() -> PilotConfig {
        return builder.build()
    }
}

// MARK: - Main Bridge

@objcMembers
@objc(PilotBridge)
public class PilotBridge: NSObject {
    fileprivate static var sessionAdapter: SessionDelegateAdapter?
    fileprivate static var actionAdapter: ActionDelegateAdapter?
    fileprivate static var loggerAdapter: LoggerDelegateAdapter?

    public static let sdkVersion: String = Pilot.version

    public static func initialize(_ config: PilotConfig) {
        Pilot.initialize(config)
    }

    public static func initializeWithBuilder(_ builder: PilotObjCConfigBuilder) {
        Pilot.initialize(builder.build())
    }

    public static func sendLog(_ level: PilotObjCLogLevel, message: String) {
        Pilot.log(level.swift, message)
    }

    public static func sendLogDetailed(_ level: PilotObjCLogLevel, message: String,
                                       category: String?, thread: String?) {
        Pilot.log(level.swift, message, category: category, thread: thread)
    }

    public static func sendEvent(_ message: String, metadata: NSDictionary?) {
        Pilot.event(message, metadata: metadata as? [String: Any])
    }

    public static func sendRevenue(_ message: String, metadata: NSDictionary?) {
        Pilot.revenue(message, metadata: metadata as? [String: Any])
    }

    public static func changeScreen(type: String, name: String) {
        Pilot.changeScreen(screenType: type, screenName: name)
    }

    public static func setInAppProducts(_ products: NSArray) {
        let swiftProducts = products as? [[String: Any]] ?? []
        Pilot.setInAppProducts(swiftProducts)
    }

    public static func setOwnedInAppProducts(_ productIds: [String]) {
        Pilot.setOwnedInAppProducts(productIds)
    }

    public static func purchaseInApp(_ transactionId: String?,
                                     productIds: [String],
                                     metadata: NSDictionary?) {
        Pilot.purchaseInApp(transactionId: transactionId,
                            productIds: productIds,
                            metadata: metadata as? [String: Any])
    }

    public static func acknowledgeAction(_ actionId: String, payload: NSDictionary?) {
        Pilot.acknowledgeAction(actionId, payload as? [String: Any])
    }

    public static func shutdown() {
        Pilot.shutdown()
        sessionAdapter = nil
        actionAdapter = nil
        loggerAdapter = nil
    }

    public static func getStatus() -> PilotObjCSessionStatus {
        let status = Pilot.getStatus()
        switch status {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .waitingApproval: return .waitingApproval
        case .active: return .active
        case .authFailed: return .authFailed
        case .rejected: return .rejected
        case .closed: return .closed
        case .error: return .error
        }
    }
}
