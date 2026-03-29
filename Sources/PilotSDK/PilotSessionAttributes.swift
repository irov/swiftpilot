import Foundation

public final class PilotSessionAttributes {
    private(set) var staticAttributes: [String: Any] = [:]
    private(set) var dynamicAttributes: [String: PilotValueProvider] = [:]

    public init() {}

    @discardableResult
    public func put(_ key: String, _ value: Any) -> PilotSessionAttributes {
        staticAttributes[key] = value
        return self
    }

    @discardableResult
    public func putProvider(_ key: String, _ provider: @escaping PilotValueProvider) -> PilotSessionAttributes {
        dynamicAttributes[key] = provider
        return self
    }
}
