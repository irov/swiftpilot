import Foundation

public class PilotError: Error {
    public let httpCode: Int
    public let message: String
    public let underlyingError: Error?

    public init(_ message: String) {
        self.httpCode = 0
        self.message = message
        self.underlyingError = nil
    }

    public init(_ message: String, cause: Error) {
        self.httpCode = 0
        self.message = message
        self.underlyingError = cause
    }

    public init(httpCode: Int, _ message: String) {
        self.httpCode = httpCode
        self.message = message
        self.underlyingError = nil
    }

    public var isNetworkError: Bool {
        return httpCode == 0 && underlyingError != nil
    }

    public var isSessionGone: Bool {
        return httpCode == 410
    }

    public var isUnauthorized: Bool {
        return httpCode == 401
    }

    public var localizedDescription: String {
        return message
    }
}
