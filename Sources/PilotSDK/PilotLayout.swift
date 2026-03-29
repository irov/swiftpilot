import Foundation

public final class PilotLayout {
    public enum Direction: String {
        case vertical = "vertical"
        case horizontal = "horizontal"
    }

    private let ui: PilotUI
    public let direction: Direction
    private var children: [Any] = []

    init(ui: PilotUI, direction: Direction) {
        self.ui = ui
        self.direction = direction
    }

    // MARK: - Sub-layouts

    @discardableResult
    public func addVertical() -> PilotLayout {
        let sub = PilotLayout(ui: ui, direction: .vertical)
        children.append(sub)
        ui.incrementRevision()
        return sub
    }

    @discardableResult
    public func addHorizontal() -> PilotLayout {
        let sub = PilotLayout(ui: ui, direction: .horizontal)
        children.append(sub)
        ui.incrementRevision()
        return sub
    }

    @discardableResult
    public func addCollapsible(_ title: String) -> PilotLayout {
        let collapsible = CollapsibleElement(ui: ui, title: title)
        children.append(collapsible)
        ui.incrementRevision()
        return collapsible.content
    }

    // MARK: - Padding

    @discardableResult
    public func addPadding(_ weight: Double) -> PilotLayout {
        children.append(PaddingElement(weight: weight))
        ui.incrementRevision()
        return self
    }

    // MARK: - Widgets

    @discardableResult
    public func addButton(_ label: String) -> PilotButton {
        let w = PilotButton(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addLabel(_ text: String) -> PilotLabel {
        let w = PilotLabel(ui: ui, text: text)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addStat(_ label: String) -> PilotStat {
        let w = PilotStat(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addSwitch(_ label: String) -> PilotSwitch {
        let w = PilotSwitch(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addInput(_ label: String) -> PilotInput {
        let w = PilotInput(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addSelect(_ label: String) -> PilotSelect {
        let w = PilotSelect(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addTextarea(_ label: String) -> PilotTextarea {
        let w = PilotTextarea(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addTable(_ label: String) -> PilotTable {
        let w = PilotTable(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    @discardableResult
    public func addLogs(_ label: String) -> PilotLogs {
        let w = PilotLogs(ui: ui, label: label)
        children.append(w)
        ui.incrementRevision()
        return w
    }

    // MARK: - Serialization

    func toJson() -> [String: Any] {
        var childrenArr: [[String: Any]] = []

        for child in children {
            if let layout = child as? PilotLayout {
                childrenArr.append(layout.toJson())
            } else if let widget = child as? PilotWidget {
                childrenArr.append(widget.toJson())
            } else if let padding = child as? PaddingElement {
                childrenArr.append(padding.toJson())
            } else if let collapsible = child as? CollapsibleElement {
                childrenArr.append(collapsible.toJson())
            }
        }

        return [
            "type": "layout",
            "direction": direction.rawValue,
            "children": childrenArr
        ]
    }
}

// MARK: - Helper Elements

private final class PaddingElement {
    let weight: Double

    init(weight: Double) {
        self.weight = weight
    }

    func toJson() -> [String: Any] {
        return [
            "type": "padding",
            "weight": weight
        ]
    }
}

private final class CollapsibleElement {
    let title: String
    let content: PilotLayout

    init(ui: PilotUI, title: String) {
        self.title = title
        self.content = PilotLayout(ui: ui, direction: .vertical)
    }

    func toJson() -> [String: Any] {
        let contentJson = content.toJson()
        return [
            "type": "collapsible",
            "title": title,
            "children": contentJson["children"] ?? []
        ]
    }
}
