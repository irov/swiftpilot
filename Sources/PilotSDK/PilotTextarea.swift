import Foundation

public final class PilotTextarea: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "textarea")
        put("label", label)
    }

    @discardableResult
    public func rows(_ rows: Int) -> PilotTextarea {
        put("rows", rows)
        return self
    }

    @discardableResult
    public func defaultValue(_ value: String) -> PilotTextarea {
        put("defaultValue", value)
        return self
    }

    @discardableResult
    public func onSubmit(_ callback: PilotWidgetCallback?) -> PilotTextarea {
        ui.registerCallback(internalId, callback)
        return self
    }

    @discardableResult
    public func onSubmit(_ callback: @escaping (PilotTextareaAction) -> Void) -> PilotTextarea {
        ui.registerCallback(internalId) { action in callback(PilotTextareaAction(action)) }
        return self
    }
}
