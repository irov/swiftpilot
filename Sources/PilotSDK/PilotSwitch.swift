import Foundation

public final class PilotSwitch: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "switch")
        put("label", label)
    }

    @discardableResult
    public func defaultValue(_ value: Bool) -> PilotSwitch {
        put("defaultValue", value)
        return self
    }

    @discardableResult
    public func onChange(_ callback: PilotWidgetCallback?) -> PilotSwitch {
        ui.registerCallback(internalId, callback)
        return self
    }

    @discardableResult
    public func onChange(_ callback: @escaping (PilotSwitchAction) -> Void) -> PilotSwitch {
        ui.registerCallback(internalId) { action in callback(PilotSwitchAction(action)) }
        return self
    }
}
