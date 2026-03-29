import Foundation

public final class PilotStat: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "stat")
        put("label", label)
    }

    @discardableResult
    public func value(_ value: String) -> PilotStat {
        put("value", value)
        return self
    }

    @discardableResult
    public func unit(_ unit: String) -> PilotStat {
        put("unit", unit)
        return self
    }

    @discardableResult
    public func valueProvider(_ provider: PilotValueProvider?) -> PilotStat {
        setProvider("value", provider)
        return self
    }
}
