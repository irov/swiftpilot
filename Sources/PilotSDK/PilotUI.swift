import Foundation

public final class PilotUI {
    private var tabs: [PilotTab] = []
    private var callbacks: [Int: PilotWidgetCallback] = [:]
    private var providers: Set<ObjectIdentifier> = []
    private var providerWidgets: [PilotWidget] = []
    private var idCounter: Int = 0
    private let version: Int = 2
    private var revision: Int = 1
    private var sentRevision: Int = 0
    private let lock = NSLock()

    init() {}

    // MARK: - ID Generation

    func nextId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        idCounter += 1
        return idCounter
    }

    // MARK: - Tab Management

    @discardableResult
    public func addTab(_ title: String) -> PilotTab {
        lock.lock()
        tabs.removeAll { $0.title == title }
        let tab = PilotTab(ui: self, title: title)
        tabs.append(tab)
        revision += 1
        lock.unlock()
        return tab
    }

    public func getTab(_ id: String) -> PilotTab? {
        lock.lock()
        defer { lock.unlock() }
        return tabs.first { $0.id == id }
    }

    public func removeTab(_ id: String) {
        lock.lock()
        tabs.removeAll { $0.id == id }
        revision += 1
        lock.unlock()
    }

    // MARK: - Widget Callbacks

    func registerCallback(_ widgetId: Int, _ callback: PilotWidgetCallback?) {
        lock.lock()
        defer { lock.unlock() }
        if let cb = callback {
            callbacks[widgetId] = cb
        } else {
            callbacks.removeValue(forKey: widgetId)
        }
    }

    func dispatchAction(_ action: PilotAction) -> Bool {
        lock.lock()
        let cb = callbacks[action.widgetId]
        lock.unlock()

        if let cb = cb {
            cb(action)
            return true
        }
        return false
    }

    // MARK: - Value Providers

    func registerProvider(_ widget: PilotWidget) {
        lock.lock()
        defer { lock.unlock() }
        let oid = ObjectIdentifier(widget)
        if !providers.contains(oid) {
            providers.insert(oid)
            providerWidgets.append(widget)
        }
    }

    func unregisterProvider(_ widget: PilotWidget) {
        lock.lock()
        defer { lock.unlock() }
        let oid = ObjectIdentifier(widget)
        providers.remove(oid)
        providerWidgets.removeAll { ObjectIdentifier($0) == oid }
    }

    func pollValues() {
        lock.lock()
        let widgets = providerWidgets
        lock.unlock()

        for w in widgets {
            if w.pollProvider() {
                lock.lock()
                revision += 1
                lock.unlock()
            }
        }
    }

    // MARK: - Revision Tracking

    func incrementRevision() {
        lock.lock()
        revision += 1
        lock.unlock()
    }

    var hasUnsent: Bool {
        lock.lock()
        defer { lock.unlock() }
        return revision != sentRevision
    }

    func markSent() {
        lock.lock()
        sentRevision = revision
        lock.unlock()
    }

    var hasTabs: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !tabs.isEmpty
    }

    public func getRevision() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return revision
    }

    // MARK: - Serialization

    func toJson() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        return [
            "version": version,
            "revision": revision,
            "tabs": tabs.map { $0.toJson() }
        ]
    }
}
