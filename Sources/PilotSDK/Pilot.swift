import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class Pilot {
    public static let version = "1.0.35"

    private static var instance: Pilot?
    private static let instanceLock = NSLock()

    private let config: PilotConfig
    private let httpClient: PilotHttpClient
    private let liveManager: PilotLiveManager

    private var sessionToken: String?
    private var requestId: String?
    private var status: PilotSessionStatus = .disconnected
    private var running = false
    private var actionPollInFlight = false
    private var logOverflowWarned = false
    private var currentActionPollIntervalMs: Int64

    private var logBuffer: [PilotLogEntry] = []
    private var sessionAttributeCache: [String: Any] = [:]

    private var actionListeners: [PilotActionListener] = []
    private var sessionListeners: [PilotSessionListener] = []

    private let ui = PilotUI()
    private let metrics = PilotMetrics()

    private let lock = NSLock()
    private let logLock = NSLock()
    private let listenerLock = NSLock()

    private var workQueue: DispatchQueue?
    private var actionPollTimer: DispatchSourceTimer?
    private var metricSampleTimer: DispatchSourceTimer?

    // MARK: - Init

    private init(config: PilotConfig) {
        self.config = config
        let client = PilotHttpClient(baseUrl: config.baseUrl, apiToken: config.apiToken)
        self.httpClient = client
        self.currentActionPollIntervalMs = config.actionPollIntervalMs
        self.liveManager = PilotLiveManager(httpClient: client)

        PilotLog.setLevel(config.logConfig.logLevel)
        PilotLog.setLoggerListener(config.loggerListener)

        let mc = config.metricConfig
        if mc.enabled {
            metrics.setSampleIntervalMs(mc.sampleIntervalMs)
            metrics.setBufferSize(mc.bufferSize)
            metrics.setBatchSize(mc.batchSize)
        }
    }

    // MARK: - Static API

    public static func initialize(_ config: PilotConfig) {
        instanceLock.lock()
        defer { instanceLock.unlock() }

        guard instance == nil else {
            PilotLog.w("Pilot.initialize() called more than once, ignoring")
            return
        }

        let p = Pilot(config: config)
        instance = p
        PilotLog.i("Pilot SDK initialized (server: %@)", config.baseUrl)

        if let sl = config.sessionListener {
            p.sessionListeners.append(sl)
        }
        if let al = config.actionListener {
            p.actionListeners.append(al)
        }

        let mc = config.metricConfig
        if mc.enabled {
            p.metrics.addCollector(PilotDefaultMetricCollector())
            for collector in mc.collectors {
                p.metrics.addCollector(collector)
            }
            PilotLog.i("Built-in metrics enabled (sample interval: %lldms)", mc.sampleIntervalMs)
        }

        if config.autoConnect {
            p.startConnection()
        }
    }

    public static var isInitialized: Bool {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        return instance != nil
    }

    public static func getStatus() -> PilotSessionStatus {
        guard let p = instance else { return .disconnected }
        p.lock.lock()
        defer { p.lock.unlock() }
        return p.status
    }

    public static func addActionListener(_ listener: PilotActionListener) {
        let p = requireInstance()
        p.listenerLock.lock()
        p.actionListeners.append(listener)
        p.listenerLock.unlock()
    }

    public static func removeActionListener(_ listener: PilotActionListener) {
        guard let p = instance else { return }
        p.listenerLock.lock()
        p.actionListeners.removeAll { $0 === listener }
        p.listenerLock.unlock()
    }

    public static func addSessionListener(_ listener: PilotSessionListener) {
        let p = requireInstance()
        p.listenerLock.lock()
        p.sessionListeners.append(listener)
        p.listenerLock.unlock()
    }

    public static func removeSessionListener(_ listener: PilotSessionListener) {
        guard let p = instance else { return }
        p.listenerLock.lock()
        p.sessionListeners.removeAll { $0 === listener }
        p.listenerLock.unlock()
    }

    public static func getUI() -> PilotUI {
        return requireInstance().ui
    }

    public static func getMetrics() -> PilotMetrics {
        return requireInstance().metrics
    }

    public static func connect() {
        requireInstance().startConnection()
    }

    public static func disconnect() {
        instance?.stopConnection()
    }

    // MARK: - Logging

    public static func log(_ level: PilotLogLevel, _ message: String) {
        guard let p = instance, p.config.logConfig.enabled else { return }
        p.bufferLog(PilotLogEntry(level: level, message: message,
                                   category: nil, thread: nil,
                                   metadata: nil, attributes: p.resolveLogAttributes()))
    }

    public static func log(_ level: PilotLogLevel, _ message: String,
                           category: String?, thread: String?) {
        guard let p = instance, p.config.logConfig.enabled else { return }
        p.bufferLog(PilotLogEntry(level: level, message: message,
                                   category: category, thread: thread,
                                   metadata: nil, attributes: p.resolveLogAttributes()))
    }

    public static func log(_ level: PilotLogLevel, _ message: String,
                           metadata: [String: Any]?) {
        guard let p = instance, p.config.logConfig.enabled else { return }
        p.bufferLog(PilotLogEntry(level: level, message: message,
                                   category: nil, thread: nil,
                                   metadata: metadata, attributes: p.resolveLogAttributes()))
    }

    public static func log(_ level: PilotLogLevel, _ message: String,
                           category: String?, thread: String?,
                           metadata: [String: Any]?) {
        guard let p = instance, p.config.logConfig.enabled else { return }
        p.bufferLog(PilotLogEntry(level: level, message: message,
                                   category: category, thread: thread,
                                   metadata: metadata, attributes: p.resolveLogAttributes()))
    }

    public static func log(_ entry: PilotLogEntry) {
        guard let p = instance, p.config.logConfig.enabled else { return }
        p.bufferLog(entry)
    }

    // MARK: - Events

    public static func event(_ message: String) {
        event(message, category: nil, metadata: nil)
    }

    public static func event(_ message: String, metadata: [String: Any]?) {
        event(message, category: nil, metadata: metadata)
    }

    public static func event(_ message: String, category: String?,
                             metadata: [String: Any]?) {
        bufferStructuredLog(kind: "event", message: message,
                            category: category, metadata: metadata,
                            clientTimestamp: Date())
    }

    public static func event(_ message: String, category: String?,
                             metadata: [String: Any]?, clientTimestamp: Date) {
        bufferStructuredLog(kind: "event", message: message,
                            category: category, metadata: metadata,
                            clientTimestamp: clientTimestamp)
    }

    // MARK: - Revenue

    public static func revenue(_ message: String) {
        revenue(message, category: nil, metadata: nil)
    }

    public static func revenue(_ message: String, metadata: [String: Any]?) {
        revenue(message, category: nil, metadata: metadata)
    }

    public static func revenue(_ message: String, category: String?,
                               metadata: [String: Any]?) {
        bufferStructuredLog(kind: "revenue", message: message,
                            category: category, metadata: metadata,
                            clientTimestamp: Date())
    }

    // MARK: - Screen Tracking

    public static func changeScreen(screenType: String, screenName: String) {
        let metadata: [String: Any] = [
            "pilot_command": "change_screen",
            "pilot_slice_type": "screen",
            "pilot_slice_name": screenName,
            "screen_type": screenType,
            "screen_name": screenName
        ]

        event("change_screen", category: "change_screen", metadata: metadata)
    }

    // MARK: - In-App Products

    public static func setInAppProducts(_ products: [[String: Any]]) {
        let metadata: [String: Any] = [
            "pilot_command": "set_in_app_products",
            "pilot_purchase_entry_type": "catalog",
            "in_app_products": products,
            "in_app_product_count": products.count
        ]

        bufferStructuredLog(kind: "purchase", message: "set_in_app_products",
                            category: "catalog", metadata: metadata,
                            clientTimestamp: Date())
    }

    public static func setOwnedInAppProducts(_ productIds: [String]) {
        let metadata: [String: Any] = [
            "pilot_command": "set_owned_in_app_products",
            "pilot_purchase_entry_type": "owned",
            "owned_in_app_products": productIds,
            "owned_in_app_product_count": productIds.count
        ]

        bufferStructuredLog(kind: "purchase", message: "set_owned_in_app_products",
                            category: "owned", metadata: metadata,
                            clientTimestamp: Date())
    }

    public static func purchaseInApp(transactionId: String?,
                                     productIds: [String],
                                     metadata: [String: Any]? = nil) {
        var purchaseMetadata: [String: Any] = metadata ?? [:]
        purchaseMetadata["pilot_command"] = "purchase_in_app"
        purchaseMetadata["pilot_purchase_entry_type"] = "purchase"
        purchaseMetadata["in_app_products"] = productIds
        purchaseMetadata["in_app_product_count"] = productIds.count

        if let transactionId = transactionId, !transactionId.isEmpty {
            purchaseMetadata["transaction_id"] = transactionId
        }

        let message = productIds.isEmpty ? "purchase_in_app" : productIds[0]

        bufferStructuredLog(kind: "purchase", message: message,
                            category: "purchase", metadata: purchaseMetadata,
                            clientTimestamp: Date())
    }

    // MARK: - Acknowledge

    public static func acknowledgeAction(_ actionId: String, _ ackPayload: [String: Any]? = nil) {
        guard let p = instance else { return }
        let token: String?
        p.lock.lock()
        token = p.sessionToken
        p.lock.unlock()

        guard let sessionToken = token else { return }

        p.workQueue?.async {
            do {
                try p.httpClient.acknowledgeAction(
                    sessionToken: sessionToken,
                    actionId: actionId,
                    ackPayload: ackPayload
                )
            } catch {
                PilotLog.e("Failed to acknowledge action", error)
            }
        }
    }

    // MARK: - Shutdown

    public static func shutdown() {
        instanceLock.lock()
        let p = instance
        instance = nil
        instanceLock.unlock()

        p?.doShutdown()
    }

    // MARK: - Internal

    private static func requireInstance() -> Pilot {
        guard let p = instance else {
            fatalError("Pilot.initialize() must be called first")
        }
        return p
    }

    private static func bufferStructuredLog(kind: String, message: String,
                                            category: String?, metadata: [String: Any]?,
                                            clientTimestamp: Date) {
        guard let p = instance, p.config.logConfig.enabled else { return }

        let resolvedCategory = resolveStructuredCategory(kind: kind, category: category)
        var merged = metadata ?? [:]
        merged["pilot_kind"] = kind

        p.bufferLog(PilotLogEntry(
            level: .info, message: message,
            category: resolvedCategory, thread: nil,
            metadata: merged, attributes: p.resolveLogAttributes(),
            clientTimestamp: clientTimestamp
        ))
    }

    private static func resolveStructuredCategory(kind: String, category: String?) -> String {
        guard let category = category, !category.isEmpty else { return kind }
        if category == kind || category.hasPrefix(kind + "_") { return category }
        return kind + "_" + category
    }

    private func startConnection() {
        lock.lock()
        guard !running else {
            lock.unlock()
            PilotLog.w("Already connecting/connected")
            return
        }
        running = true
        lock.unlock()

        let queue = DispatchQueue(label: "org.pilot.sdk", qos: .utility, attributes: .concurrent)
        workQueue = queue
        queue.async { [weak self] in
            self?.connectAndWaitApproval()
        }
    }

    private func stopConnection() {
        lock.lock()
        guard running else {
            lock.unlock()
            return
        }
        running = false
        let token = sessionToken
        sessionToken = nil
        lock.unlock()

        liveManager.onSessionClosed()
        cancelScheduledTasks()

        if let token = token {
            workQueue?.async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.flushLogs(sessionToken: token)
                    try self.flushMetrics(sessionToken: token)
                    _ = try self.httpClient.closeSession(sessionToken: token)
                } catch {}

                self.setStatus(.closed)
                self.notifySessionClosed()
            }
        } else {
            setStatus(.disconnected)
        }
    }

    private func doShutdown() {
        PilotLog.i("Shutting down Pilot SDK")
        stopConnection()
        liveManager.shutdown()
        httpClient.shutdown()

        listenerLock.lock()
        actionListeners.removeAll()
        sessionListeners.removeAll()
        listenerLock.unlock()

        logLock.lock()
        logBuffer.removeAll()
        logLock.unlock()

        metrics.clear()
    }

    private func connectAndWaitApproval() {
        var retryCount = 0
        var retryDelayMs: Int64 = 2000
        let maxRetryDelayMs: Int64 = 30000

        while isRunning {
            do {
                try doConnectAndWaitApproval()
                return
            } catch let error as PilotError {
                if error.isUnauthorized {
                    PilotLog.e("Authentication failed", error)
                    setStatus(.authFailed)
                    lock.lock()
                    running = false
                    lock.unlock()
                    notifyAuthFailed()
                    return
                }

                retryCount += 1
                PilotLog.w("Connection attempt %d failed: %@, retrying in %lldms",
                           retryCount, error.message, retryDelayMs)
                setStatus(.connecting)

                Thread.sleep(forTimeInterval: TimeInterval(retryDelayMs) / 1000.0)
                retryDelayMs = min(retryDelayMs * 2, maxRetryDelayMs)
            } catch {
                retryCount += 1
                PilotLog.w("Connection attempt %d failed: %@", retryCount, error.localizedDescription)
                setStatus(.connecting)

                Thread.sleep(forTimeInterval: TimeInterval(retryDelayMs) / 1000.0)
                retryDelayMs = min(retryDelayMs * 2, maxRetryDelayMs)
            }
        }
    }

    private func doConnectAndWaitApproval() throws {
        setStatus(.connecting)
        notifyConnecting()

        var deviceId = config.deviceId ?? ""
        var deviceName = config.deviceName ?? ""

        #if canImport(UIKit) && !os(watchOS)
        if deviceId.isEmpty {
            deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UIDevice.current.model
        }
        if deviceName.isEmpty {
            deviceName = "\(UIDevice.current.model) (iOS \(UIDevice.current.systemVersion))"
        }
        #else
        if deviceId.isEmpty {
            deviceId = Host.current().localizedName ?? "macOS"
        }
        if deviceName.isEmpty {
            let info = ProcessInfo.processInfo
            deviceName = "\(Host.current().localizedName ?? "Mac") (macOS \(info.operatingSystemVersionString))"
        }
        #endif

        let resp = try httpClient.connect(deviceId: deviceId, deviceName: deviceName,
                                          sessionAttributes: resolveAllSessionAttributes())

        lock.lock()
        requestId = resp.requestId
        lock.unlock()

        PilotLog.i("Connect request sent, request_id=%@, status=%@", resp.requestId, resp.status)

        if resp.isApproved, let token = resp.sessionToken {
            onApproved(token)
            return
        }

        if resp.isRejected {
            onRejected()
            return
        }

        setStatus(.waitingApproval)
        notifyWaitingApproval(resp.requestId)

        while isRunning {
            Thread.sleep(forTimeInterval: TimeInterval(config.pollIntervalMs) / 1000.0)

            let pollResp = try httpClient.pollStatus(requestId: resp.requestId)

            if pollResp.isApproved, let token = pollResp.sessionToken {
                onApproved(token)
                return
            }

            if pollResp.isRejected {
                onRejected()
                return
            }
        }
    }

    private func onApproved(_ token: String) {
        lock.lock()
        sessionToken = token
        lock.unlock()

        setStatus(.active)
        PilotLog.i("Session approved and active")
        notifySessionStarted(token)

        if ui.hasTabs {
            let snapshot = ui.toJson()
            do {
                _ = try httpClient.submitPanel(sessionToken: token, layout: snapshot)
                ui.markSent()
                PilotLog.d("Initial UI submitted (revision=%d)", ui.getRevision())
            } catch {
                PilotLog.e("Failed to submit initial UI", error)
                notifyError(PilotError("Failed to submit initial UI", cause: error))
            }
        }

        scheduleActionPolling(sessionToken: token, intervalMs: config.actionPollIntervalMs)

        if config.metricConfig.enabled {
            let sampleMs = metrics.sampleIntervalMs
            let timer = DispatchSource.makeTimerSource(queue: workQueue)
            timer.schedule(deadline: .now() + .milliseconds(Int(sampleMs)),
                          repeating: .milliseconds(Int(sampleMs)))
            timer.setEventHandler { [weak self] in
                self?.metrics.sample()
            }
            timer.resume()

            lock.lock()
            metricSampleTimer = timer
            lock.unlock()
        }
    }

    private func onRejected() {
        PilotLog.w("Connection request rejected")
        setStatus(.rejected)
        lock.lock()
        running = false
        lock.unlock()
        notifyRejected()
    }

    private func doPollActions(_ token: String) {
        lock.lock()
        guard running, !actionPollInFlight else {
            lock.unlock()
            return
        }
        actionPollInFlight = true
        lock.unlock()

        defer {
            lock.lock()
            actionPollInFlight = false
            lock.unlock()
        }

        let changedAttrs = resolveChangedSessionAttributes()
        let logChunk = drainLogChunk()
        let metricChunk = metrics.drain()

        // Poll value providers
        ui.pollValues()
        var uiSnapshot: [String: Any]? = nil
        if ui.hasUnsent {
            uiSnapshot = ui.toJson()
        }

        if let snapshot = uiSnapshot {
            do {
                _ = try httpClient.submitPanel(sessionToken: token, layout: snapshot)
                ui.markSent()
                PilotLog.d("UI submitted (revision=%d)", ui.getRevision())
            } catch {
                PilotLog.e("Failed to submit UI", error)
                notifyError(PilotError("Failed to submit UI", cause: error))
            }
        }

        do {
            let json = try httpClient.pollActions(
                sessionToken: token,
                changedAttributes: changedAttrs,
                logs: logChunk,
                metrics: metricChunk
            )

            if let actionsArr = json["actions"] as? [[String: Any]] {
                for actionJson in actionsArr {
                    let action = PilotAction.fromJson(actionJson)
                    dispatchAction(action)
                }
            }

            if !logChunk.isEmpty {
                lock.lock()
                logOverflowWarned = false
                lock.unlock()
            }
        } catch let error as PilotError {
            requeueLogs(logChunk)
            metrics.requeue(metricChunk)

            if error.isSessionGone {
                handleSessionGone()
            } else {
                PilotLog.e("Action poll failed", error)
            }
        } catch {
            requeueLogs(logChunk)
            metrics.requeue(metricChunk)
            PilotLog.e("Action poll failed", error)
        }
    }

    private func dispatchAction(_ action: PilotAction) {
        let dispatchBlock = { [weak self] in
            guard let self = self else { return }

            var handled = false

            handled = self.handleInternalAction(action)
            if !handled {
                _ = self.ui.dispatchAction(action)
            }

            if !handled {
                self.listenerLock.lock()
                let listeners = self.actionListeners
                self.listenerLock.unlock()

                for listener in listeners {
                    listener.onPilotActionReceived(action)
                }
            }
        }

        if Thread.isMainThread {
            dispatchBlock()
        } else {
            DispatchQueue.main.async(execute: dispatchBlock)
        }
    }

    private func scheduleActionPolling(sessionToken: String, intervalMs: Int64) {
        lock.lock()
        guard running else {
            lock.unlock()
            return
        }

        actionPollTimer?.cancel()
        actionPollTimer = nil

        currentActionPollIntervalMs = intervalMs

        let timer = DispatchSource.makeTimerSource(queue: workQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(Int(intervalMs)))
        timer.setEventHandler { [weak self] in
            self?.doPollActions(sessionToken)
        }
        timer.resume()
        actionPollTimer = timer
        lock.unlock()
    }

    private func handleInternalAction(_ action: PilotAction) -> Bool {
        switch action.actionType {
        case .liveStart:
            lock.lock()
            let token = sessionToken
            lock.unlock()

            guard let token = token else {
                let ack = buildInternalAck(ok: false, status: "No active session available for streaming")
                Pilot.acknowledgeAction(action.id, ack)
                return true
            }

            let actionId = action.id
            let payload = action.payload
            workQueue?.async { [weak self] in
                guard let self = self else { return }
                let result = self.liveManager.start(sessionToken: token, payload: payload)
                Pilot.acknowledgeAction(actionId, result)
            }
            return true

        case .liveStop:
            Pilot.acknowledgeAction(action.id, liveManager.stop())
            return true

        case .liveTap:
            Pilot.acknowledgeAction(action.id, liveManager.tap(action.payload))
            return true

        case .liveLongPress:
            Pilot.acknowledgeAction(action.id, liveManager.longPress(action.payload))
            return true

        default:
            return false
        }
    }

    private func buildInternalAck(ok: Bool, status: String) -> [String: Any] {
        return ["ok": ok, "status": status]
    }

    // MARK: - Log Buffer

    private func bufferLog(_ entry: PilotLogEntry) {
        logLock.lock()
        defer { logLock.unlock() }

        if logBuffer.count >= config.logConfig.bufferSize {
            logBuffer.removeFirst()

            if !logOverflowWarned {
                logOverflowWarned = true
                PilotLog.w("Log buffer overflow (%d), dropping oldest entries", config.logConfig.bufferSize)
            }
        }

        logBuffer.append(entry)
    }

    private func drainLogChunk() -> [PilotLogEntry] {
        logLock.lock()
        defer { logLock.unlock() }

        guard !logBuffer.isEmpty else { return [] }

        let count = min(logBuffer.count, config.logConfig.batchSize)
        let chunk = Array(logBuffer.prefix(count))
        logBuffer.removeFirst(count)
        return chunk
    }

    private func requeueLogs(_ chunk: [PilotLogEntry]) {
        guard !chunk.isEmpty else { return }

        logLock.lock()
        defer { logLock.unlock() }

        logBuffer.insert(contentsOf: chunk, at: 0)
        while logBuffer.count > config.logConfig.bufferSize {
            logBuffer.removeLast()
        }
    }

    private func flushLogs(sessionToken: String) throws {
        let chunk = drainLogChunk()
        guard !chunk.isEmpty else { return }

        do {
            try httpClient.sendLogs(sessionToken: sessionToken, logs: chunk)
        } catch {
            requeueLogs(chunk)
            throw error
        }
    }

    private func flushMetrics(sessionToken: String) throws {
        let chunk = metrics.drain()
        guard !chunk.isEmpty else { return }

        do {
            try httpClient.sendMetrics(sessionToken: sessionToken, metrics: chunk)
        } catch {
            metrics.requeue(chunk)
            throw error
        }
    }

    // MARK: - Attributes

    private func resolveLogAttributes() -> [String: Any]? {
        let builder = config.logConfig.attributes
        let staticAttrs = builder.staticAttributes
        let dynamicAttrs = builder.dynamicAttributes

        guard !staticAttrs.isEmpty || !dynamicAttrs.isEmpty else { return nil }

        var attributes: [String: Any] = staticAttrs

        for (key, provider) in dynamicAttrs {
            attributes[key] = provider() ?? NSNull()
        }

        return attributes.isEmpty ? nil : attributes
    }

    private func resolveAllSessionAttributes() -> [String: Any] {
        let builder = config.sessionAttributes
        var merged = builder.staticAttributes

        for (key, provider) in builder.dynamicAttributes {
            let value = provider() ?? NSNull()
            merged[key] = value
            sessionAttributeCache[key] = value
        }

        return merged
    }

    private func resolveChangedSessionAttributes() -> [String: Any]? {
        let dynamicAttrs = config.sessionAttributes.dynamicAttributes
        guard !dynamicAttrs.isEmpty else { return nil }

        var changed: [String: Any]?

        for (key, provider) in dynamicAttrs {
            let value = provider() ?? NSNull()
            let resolved = "\(value)"
            let cached = sessionAttributeCache[key].map { "\($0)" }

            if resolved != cached {
                sessionAttributeCache[key] = value
                if changed == nil { changed = [:] }
                changed?[key] = value
            }
        }

        return changed
    }

    // MARK: - Session management

    private func handleSessionGone() {
        PilotLog.w("Session is gone (410), stopping")
        lock.lock()
        running = false
        sessionToken = nil
        lock.unlock()

        liveManager.onSessionClosed()
        cancelScheduledTasks()
        setStatus(.closed)
        notifySessionClosed()
    }

    private func setStatus(_ newStatus: PilotSessionStatus) {
        lock.lock()
        status = newStatus
        lock.unlock()
    }

    private var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    private func cancelScheduledTasks() {
        lock.lock()
        actionPollTimer?.cancel()
        actionPollTimer = nil
        metricSampleTimer?.cancel()
        metricSampleTimer = nil
        lock.unlock()
    }

    // MARK: - Listener Notifications

    private func notifyConnecting() {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionConnecting() }
    }

    private func notifyWaitingApproval(_ requestId: String) {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionWaitingApproval(requestId) }
    }

    private func notifySessionStarted(_ sessionToken: String) {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionStarted(sessionToken) }
    }

    private func notifySessionClosed() {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionClosed() }
    }

    private func notifyRejected() {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionRejected() }
    }

    private func notifyAuthFailed() {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionAuthFailed() }
    }

    private func notifyError(_ error: PilotError) {
        listenerLock.lock()
        let listeners = sessionListeners
        listenerLock.unlock()
        for l in listeners { l.onPilotSessionError(error) }
    }
}
