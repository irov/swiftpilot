import Foundation

public final class PilotTab {
    private let ui: PilotUI
    private let internalId: Int
    public private(set) var id: String
    public let title: String
    private var layout: PilotLayout?

    init(ui: PilotUI, title: String) {
        self.ui = ui
        self.internalId = ui.nextId()
        self.id = "tab-\(internalId)"
        self.title = title
    }

    @discardableResult
    public func setId(_ id: String) -> PilotTab {
        self.id = id
        return self
    }

    public func getLayout() -> PilotLayout? {
        return layout
    }

    @discardableResult
    public func vertical() -> PilotLayout {
        let l = PilotLayout(ui: ui, direction: .vertical)
        layout = l
        return l
    }

    @discardableResult
    public func horizontal() -> PilotLayout {
        let l = PilotLayout(ui: ui, direction: .horizontal)
        layout = l
        return l
    }

    func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "id": internalId,
            "title": title
        ]
        if let layout = layout {
            json["layout"] = layout.toJson()
        }
        return json
    }
}
