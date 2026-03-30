import Foundation

public final class PilotConfig {
    public let baseUrl: String
    public let apiToken: String
    public let deviceId: String?
    public let deviceName: String?
    public let pollIntervalMs: Int64
    public let actionPollIntervalMs: Int64
    public let autoConnect: Bool
    public weak var loggerListener: PilotLoggerListener?
    public weak var sessionListener: PilotSessionListener?
    public weak var actionListener: PilotActionListener?
    public let sessionAttributes: PilotSessionAttributes
    public let logConfig: PilotLogConfig
    public let metricConfig: PilotMetricConfig

    private init(_ builder: Builder) {
        self.baseUrl = builder.baseUrl
        self.apiToken = builder.apiToken
        self.deviceId = builder.deviceId
        self.deviceName = builder.deviceName
        self.pollIntervalMs = builder.pollIntervalMs
        self.actionPollIntervalMs = builder.actionPollIntervalMs
        self.autoConnect = builder.autoConnect
        self.loggerListener = builder.loggerListener
        self.sessionListener = builder.sessionListener
        self.actionListener = builder.actionListener
        self.sessionAttributes = builder.sessionAttributes
        self.logConfig = builder.logConfig
        self.metricConfig = builder.metricConfig
    }

    public final class Builder {
        fileprivate var baseUrl: String
        fileprivate var apiToken: String
        fileprivate var deviceId: String?
        fileprivate var deviceName: String?
        fileprivate var pollIntervalMs: Int64 = 10000
        fileprivate var actionPollIntervalMs: Int64 = 2000
        fileprivate var autoConnect: Bool = true
        fileprivate weak var loggerListener: PilotLoggerListener?
        fileprivate weak var sessionListener: PilotSessionListener?
        fileprivate weak var actionListener: PilotActionListener?
        fileprivate var sessionAttributes = PilotSessionAttributes()
        fileprivate var logConfig = PilotLogConfig()
        fileprivate var metricConfig = PilotMetricConfig()

        public init(_ baseUrl: String, _ apiToken: String) {
            self.baseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
            self.apiToken = apiToken
        }

        @discardableResult
        public func setDeviceId(_ deviceId: String) -> Builder {
            self.deviceId = deviceId
            return self
        }

        @discardableResult
        public func setDeviceName(_ deviceName: String) -> Builder {
            self.deviceName = deviceName
            return self
        }

        @discardableResult
        public func setPollIntervalMs(_ ms: Int64) -> Builder {
            self.pollIntervalMs = ms
            return self
        }

        @discardableResult
        public func setActionPollIntervalMs(_ ms: Int64) -> Builder {
            self.actionPollIntervalMs = ms
            return self
        }

        @discardableResult
        public func setAutoConnect(_ autoConnect: Bool) -> Builder {
            self.autoConnect = autoConnect
            return self
        }

        @discardableResult
        public func setLoggerListener(_ listener: PilotLoggerListener?) -> Builder {
            self.loggerListener = listener
            return self
        }

        @discardableResult
        public func setSessionListener(_ listener: PilotSessionListener?) -> Builder {
            self.sessionListener = listener
            return self
        }

        @discardableResult
        public func setActionListener(_ listener: PilotActionListener?) -> Builder {
            self.actionListener = listener
            return self
        }

        @discardableResult
        public func setSessionAttributes(_ attributes: PilotSessionAttributes) -> Builder {
            self.sessionAttributes = attributes
            return self
        }

        @discardableResult
        public func setLogConfig(_ config: PilotLogConfig) -> Builder {
            self.logConfig = config
            return self
        }

        @discardableResult
        public func setMetricConfig(_ config: PilotMetricConfig) -> Builder {
            self.metricConfig = config
            return self
        }

        public func build() -> PilotConfig {
            precondition(!baseUrl.isEmpty, "baseUrl is required")
            precondition(!apiToken.isEmpty, "apiToken is required")
            return PilotConfig(self)
        }
    }
}
