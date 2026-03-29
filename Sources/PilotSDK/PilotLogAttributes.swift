import Foundation

public final class PilotLogAttributes {
    private(set) var staticAttributes: [String: Any] = [:]
    private(set) var dynamicAttributes: [String: PilotValueProvider] = [:]

    public init() {}

    @discardableResult
    public func put(_ key: String, _ value: Any) -> PilotLogAttributes {
        staticAttributes[key] = value
        return self
    }

    @discardableResult
    public func putProvider(_ key: String, _ provider: @escaping PilotValueProvider) -> PilotLogAttributes {
        dynamicAttributes[key] = provider
        return self
    }
}
