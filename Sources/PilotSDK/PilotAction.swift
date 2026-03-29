import Foundation

public final class PilotAction {
    public let id: String
    public let sessionId: String
    public let widgetId: Int
    public let actionType: PilotActionType
    public let status: PilotActionStatus
    public let payload: [String: Any]?

    init(id: String, sessionId: String, widgetId: Int,
         actionType: PilotActionType, status: PilotActionStatus,
         payload: [String: Any]?) {
        self.id = id
        self.sessionId = sessionId
        self.widgetId = widgetId
        self.actionType = actionType
        self.status = status
        self.payload = payload
    }

    static func fromJson(_ json: [String: Any]) -> PilotAction {
        return PilotAction(
            id: json["id"] as? String ?? "",
            sessionId: json["session_id"] as? String ?? "",
            widgetId: json["widget_id"] as? Int ?? 0,
            actionType: PilotActionType.from(json["action_type"] as? String ?? ""),
            status: PilotActionStatus.from(json["status"] as? String ?? ""),
            payload: json["payload"] as? [String: Any]
        )
    }
}
