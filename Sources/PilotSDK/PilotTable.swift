import Foundation

public final class PilotTable: PilotWidget {
    init(ui: PilotUI, label: String) {
        super.init(ui: ui, type: "table")
        put("label", label)
    }

    @discardableResult
    public func columns(_ columns: [[String]]) -> PilotTable {
        let arr = columns.map { col -> [String: String] in
            return ["key": col[0], "label": col[1]]
        }
        put("columns", arr)
        return self
    }

    @discardableResult
    public func rows(_ rows: [[String: Any]]) -> PilotTable {
        put("rows", rows)
        return self
    }
}
