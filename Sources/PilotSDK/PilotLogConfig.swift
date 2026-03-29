import Foundation

public final class PilotLogConfig {
    private(set) var enabled: Bool = true
    private(set) var logLevel: PilotLogLevel = .info
    private(set) var batchSize: Int = 100
    private(set) var bufferSize: Int = 1000
    private(set) var attributes: PilotLogAttributes = PilotLogAttributes()

    public init() {}

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> PilotLogConfig {
        self.enabled = enabled
        return self
    }

    @discardableResult
    public func setLogLevel(_ level: PilotLogLevel) -> PilotLogConfig {
        self.logLevel = level
        return self
    }

    @discardableResult
    public func setBatchSize(_ size: Int) -> PilotLogConfig {
        self.batchSize = size
        return self
    }

    @discardableResult
    public func setBufferSize(_ size: Int) -> PilotLogConfig {
        self.bufferSize = size
        return self
    }

    @discardableResult
    public func setAttributes(_ attributes: PilotLogAttributes) -> PilotLogConfig {
        self.attributes = attributes
        return self
    }
}
