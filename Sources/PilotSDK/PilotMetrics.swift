import Foundation

public final class PilotMetrics {
    private var collectors: [PilotMetricCollector] = []
    private var buffer: [PilotMetricEntry] = []
    private let lock = NSLock()
    private let collectorsLock = NSLock()

    private(set) var sampleIntervalMs: Int64 = 200
    private var bufferSize: Int = 2000
    private(set) var batchSize: Int = 200

    init() {}

    public func setSampleIntervalMs(_ intervalMs: Int64) {
        sampleIntervalMs = max(100, min(1000, intervalMs))
    }

    public func setBufferSize(_ size: Int) {
        bufferSize = size
    }

    public func setBatchSize(_ size: Int) {
        batchSize = size
    }

    public func addCollector(_ collector: PilotMetricCollector) {
        collectorsLock.lock()
        collectors.append(collector)
        collectorsLock.unlock()
    }

    public func removeCollector(_ collector: PilotMetricCollector) {
        collectorsLock.lock()
        collectors.removeAll { $0 === collector }
        collectorsLock.unlock()
    }

    public func record(_ metricType: PilotMetricType, _ value: Double) {
        bufferEntry(PilotMetricEntry(metricType, value))
    }

    public func record(_ metricType: PilotMetricType, _ value: Double, timestampMs: Int64) {
        bufferEntry(PilotMetricEntry(metricType, value, timestampMs: timestampMs))
    }

    func sample() {
        var collected: [PilotMetricEntry] = []

        collectorsLock.lock()
        let currentCollectors = collectors
        collectorsLock.unlock()

        for collector in currentCollectors {
            collector.collect(&collected)
        }

        for entry in collected {
            bufferEntry(entry)
        }
    }

    func drain() -> [PilotMetricEntry] {
        lock.lock()
        defer { lock.unlock() }

        guard !buffer.isEmpty else { return [] }

        let count = min(buffer.count, batchSize)
        let chunk = Array(buffer.prefix(count))
        buffer.removeFirst(count)
        return chunk
    }

    func requeue(_ entries: [PilotMetricEntry]) {
        lock.lock()
        defer { lock.unlock() }

        buffer.insert(contentsOf: entries, at: 0)
        while buffer.count > bufferSize {
            buffer.removeLast()
        }
    }

    var hasData: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !buffer.isEmpty
    }

    func clear() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()

        collectorsLock.lock()
        collectors.removeAll()
        collectorsLock.unlock()
    }

    private func bufferEntry(_ entry: PilotMetricEntry) {
        lock.lock()
        defer { lock.unlock() }

        if buffer.count >= bufferSize {
            buffer.removeFirst()
        }
        buffer.append(entry)
    }
}
