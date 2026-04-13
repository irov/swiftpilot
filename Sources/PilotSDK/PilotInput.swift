import Foundation

public final class PilotInput: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "input")
        put("label", label)
    }

    @discardableResult
    public func inputType(_ type: String) -> PilotInput {
        put("inputType", type)
        return self
    }

    @discardableResult
    public func defaultValue(_ value: String) -> PilotInput {
        put("defaultValue", value)
        return self
    }

    @discardableResult
    public func placeholder(_ placeholder: String) -> PilotInput {
        put("placeholder", placeholder)
        return self
    }

    @discardableResult
    public func onSubmit(_ callback: PilotWidgetCallback?) -> PilotInput {
        ui.registerCallback(internalId, callback)
        return self
    }

    @discardableResult
    public func onSubmit(_ callback: @escaping (PilotInputAction) -> Void) -> PilotInput {
        ui.registerCallback(internalId) { action in callback(PilotInputAction(action)) }
        return self
    }
}
