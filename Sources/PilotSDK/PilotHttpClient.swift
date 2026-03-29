import Foundation

final class PilotHttpClient {
    private let baseUrl: String
    private let apiToken: String
    private let session: URLSession

    init(baseUrl: String, apiToken: String) {
        self.baseUrl = baseUrl
        self.apiToken = apiToken

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func shutdown() {
        session.invalidateAndCancel()
    }

    // MARK: - Client Endpoints

    func connect(deviceId: String, deviceName: String,
                 sessionAttributes: [String: Any]) throws -> PilotConnectResponse {
        var body: [String: Any] = [
            "device_id": deviceId,
            "device_name": deviceName
        ]

        if !sessionAttributes.isEmpty {
            body["session_attributes"] = sessionAttributes
        }

        let json = try executeSync(
            path: "/api/client/connect",
            method: "POST",
            body: body,
            token: apiToken,
            tokenHeader: "X-Api-Token"
        )

        return PilotConnectResponse.fromJson(json)
    }

    func pollStatus(requestId: String) throws -> PilotConnectResponse {
        let json = try executeSync(
            path: "/api/client/poll-status/\(requestId)",
            method: "GET",
            body: nil,
            token: apiToken,
            tokenHeader: "X-Api-Token"
        )

        return PilotConnectResponse.fromJson(json)
    }

    func closeSession(sessionToken: String) throws -> Bool {
        let json = try executeSync(
            path: "/api/client/session/close",
            method: "POST",
            body: [:],
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )

        return json["ok"] as? Bool ?? false
    }

    func submitPanel(sessionToken: String, layout: [String: Any]) throws -> [String: Any] {
        let body: [String: Any] = ["layout": layout]

        return try executeSync(
            path: "/api/client/session/panel",
            method: "POST",
            body: body,
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )
    }

    func pollActions(sessionToken: String,
                     changedAttributes: [String: Any]?,
                     logs: [PilotLogEntry],
                     metrics: [PilotMetricEntry]) throws -> [String: Any] {
        var body: [String: Any] = [:]

        if let attrs = changedAttributes, !attrs.isEmpty {
            body["session_attributes"] = attrs
        }

        if !logs.isEmpty {
            body["logs"] = logs.map { $0.toJson() }
        }

        if !metrics.isEmpty {
            body["metrics"] = metrics.map { $0.toJson() }
        }

        return try executeSync(
            path: "/api/client/session/actions/poll",
            method: "POST",
            body: body.isEmpty ? nil : body,
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )
    }

    func acknowledgeAction(sessionToken: String, actionId: String,
                           ackPayload: [String: Any]?) throws {
        let body: [String: Any] = [
            "action_id": actionId,
            "ack_payload": ackPayload ?? [:]
        ]

        _ = try executeSync(
            path: "/api/client/session/actions/ack",
            method: "POST",
            body: body,
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )
    }

    func sendLogs(sessionToken: String, logs: [PilotLogEntry]) throws {
        guard !logs.isEmpty else { return }

        let body: [String: Any] = [
            "logs": logs.map { $0.toJson() }
        ]

        _ = try executeSync(
            path: "/api/client/session/logs",
            method: "POST",
            body: body,
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )
    }

    func sendMetrics(sessionToken: String, metrics: [PilotMetricEntry]) throws {
        guard !metrics.isEmpty else { return }

        let body: [String: Any] = [
            "metrics": metrics.map { $0.toJson() }
        ]

        _ = try executeSync(
            path: "/api/client/session/metrics",
            method: "POST",
            body: body,
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )
    }

    func getLivePublisherState(sessionToken: String) throws -> [String: Any] {
        return try executeSync(
            path: "/api/client/session/live/publisher",
            method: "GET",
            body: nil,
            token: sessionToken,
            tokenHeader: "X-Session-Token"
        )
    }

    // MARK: - Internal

    @discardableResult
    private func executeSync(path: String, method: String,
                             body: [String: Any]?,
                             token: String, tokenHeader: String) throws -> [String: Any] {
        guard let url = URL(string: baseUrl + path) else {
            throw PilotError("Invalid URL: \(baseUrl + path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: tokenHeader)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        if let body = body, method != "GET" {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        var responseData: Data?
        var responseHTTP: HTTPURLResponse?
        var responseError: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let task = session.dataTask(with: request) { data, response, error in
            responseData = data
            responseHTTP = response as? HTTPURLResponse
            responseError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = responseError {
            throw PilotError("Network error: \(error.localizedDescription)", cause: error)
        }

        guard let httpResponse = responseHTTP else {
            throw PilotError("No HTTP response")
        }

        let bodyString = responseData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        guard (200...299).contains(httpResponse.statusCode) else {
            var detail = bodyString
            if let data = responseData,
               let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let d = errorJson["detail"] as? String {
                detail = d
            }
            throw PilotError(httpCode: httpResponse.statusCode, "HTTP \(httpResponse.statusCode): \(detail)")
        }

        if bodyString.isEmpty {
            return [:]
        }

        guard let data = responseData,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PilotError("Failed to parse server response")
        }

        return json
    }
}
