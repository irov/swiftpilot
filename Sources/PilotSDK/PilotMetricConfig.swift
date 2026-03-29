import Foundation

public final class PilotMetricConfig {
    private(set) var enabled: Bool = true
    private(set) var sampleIntervalMs: Int64 = 200
    private(set) var bufferSize: Int = 2000
    private(set) var batchSize: Int = 200
    private(set) var collectors: [PilotMetricCollector] = []

    public init() {}

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> PilotMetricConfig {
        self.enabled = enabled
        return self
    }

    @discardableResult
    public func setSampleIntervalMs(_ ms: Int64) -> PilotMetricConfig {
        self.sampleIntervalMs = max(100, min(1000, ms))
        return self
    }

    @discardableResult
    public func setBufferSize(_ size: Int) -> PilotMetricConfig {
        self.bufferSize = size
        return self
    }

    @discardableResult
    public func setBatchSize(_ size: Int) -> PilotMetricConfig {
        self.batchSize = size
        return self
    }

    @discardableResult
    public func addCollector(_ collector: PilotMetricCollector) -> PilotMetricConfig {
        self.collectors.append(collector)
        return self
    }
}
