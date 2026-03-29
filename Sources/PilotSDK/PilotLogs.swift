import Foundation

public final class PilotLogs: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "logs")
        put("label", label)
    }

    @discardableResult
    public func maxLines(_ maxLines: Int) -> PilotLogs {
        put("maxLines", maxLines)
        return self
    }
}
