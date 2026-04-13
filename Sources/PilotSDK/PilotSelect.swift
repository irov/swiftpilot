import Foundation

public final class PilotSelect: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "select")
        put("label", label)
    }

    @discardableResult
    public func options(_ options: [[String]]) -> PilotSelect {
        let arr = options.map { opt -> [String: String] in
            return ["value": opt[0], "label": opt[1]]
        }
        put("options", arr)
        return self
    }

    @discardableResult
    public func defaultValue(_ value: String) -> PilotSelect {
        put("defaultValue", value)
        return self
    }

    @discardableResult
    public func onChange(_ callback: PilotWidgetCallback?) -> PilotSelect {
        ui.registerCallback(internalId, callback)
        return self
    }

    @discardableResult
    public func onChange(_ callback: @escaping (PilotSelectAction) -> Void) -> PilotSelect {
        ui.registerCallback(internalId) { action in callback(PilotSelectAction(action)) }
        return self
    }
}
