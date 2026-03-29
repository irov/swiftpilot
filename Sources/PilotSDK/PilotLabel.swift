import Foundation

public final class PilotLabel: PilotWidget {
    init(ui: PilotUI, text: String) {
        super.init(ui: ui, type: "label")
        put("text", text)
    }

    @discardableResult
    public func text(_ text: String) -> PilotLabel {
        put("text", text)
        return self
    }

    @discardableResult
    public func color(_ color: String) -> PilotLabel {
        put("color", color)
        return self
    }

    @discardableResult
    public func textProvider(_ provider: PilotValueProvider?) -> PilotLabel {
        setProvider("text", provider)
        return self
    }
}
