import Foundation

public struct PilotConnectResponse {
    public let requestId: String
    public let status: String
    public let sessionToken: String?

    public var isPending: Bool { status == "pending" }
    public var isApproved: Bool { status == "approved" }
    public var isRejected: Bool { status == "rejected" }

    static func fromJson(_ json: [String: Any]) -> PilotConnectResponse {
        return PilotConnectResponse(
            requestId: json["request_id"] as? String ?? "",
            status: json["status"] as? String ?? "",
            sessionToken: json["session_token"] as? String
        )
    }
}
