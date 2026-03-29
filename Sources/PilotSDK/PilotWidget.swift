import Foundation

public class PilotWidget {
    let ui: PilotUI
    let internalId: Int
    public private(set) var id: String
    public let type: String
    var json: [String: Any]

    private var providerKey: String?
    private var provider: PilotValueProvider?
    private var cachedValue: String?

    init(ui: PilotUI, type: String) {
        self.ui = ui
        self.internalId = ui.nextId()
        self.id = "\(type)-\(internalId)"
        self.type = type
        self.json = [
            "type": type,
            "id": internalId
        ]
    }

    func put(_ key: String, _ value: Any?) {
        if let value = value {
            json[key] = value
        } else {
            json.removeValue(forKey: key)
        }
        ui.incrementRevision()
    }

    @discardableResult
    public func setId(_ id: String) -> Self {
        self.id = id
        return self
    }

    func setProvider(_ key: String, _ provider: PilotValueProvider?) {
        self.providerKey = key
        self.provider = provider
        if provider != nil {
            ui.registerProvider(self)
        } else {
            ui.unregisterProvider(self)
        }
    }

    func pollProvider() -> Bool {
        guard let provider = provider, let key = providerKey else { return false }

        let newValue = String(describing: provider() ?? "")
        if newValue != cachedValue {
            cachedValue = newValue
            json[key] = newValue
            return true
        }
        return false
    }

    func toJson() -> [String: Any] {
        return json
    }
}
