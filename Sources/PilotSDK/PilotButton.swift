import Foundation

public final class PilotButton: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "button")
        put("label", label)
    }

    @discardableResult
    public func variant(_ variant: String) -> PilotButton {
        put("variant", variant)
        return self
    }

    @discardableResult
    public func color(_ color: String) -> PilotButton {
        put("color", color)
        return self
    }

    @discardableResult
    public func disabled(_ disabled: Bool) -> PilotButton {
        put("disabled", disabled)
        return self
    }

    @discardableResult
    public func onClick(_ callback: PilotWidgetCallback?) -> PilotButton {
        ui.registerCallback(internalId, callback)
        return self
    }
}
