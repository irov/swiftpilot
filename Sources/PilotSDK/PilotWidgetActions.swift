import Foundation

/// Typed action for ``PilotSwitch`` change events.
/// Provides a strongly-typed ``value`` instead of raw payload access.
public final class PilotSwitchAction {
    public let action: PilotAction
    public let value: Bool

    init(_ action: PilotAction) {
        self.action = action
        self.value = action.payload?["value"] as? Bool ?? false
    }
}

/// Typed action for ``PilotInput`` submit events.
public final class PilotInputAction {
    public let action: PilotAction
    public let value: String

    init(_ action: PilotAction) {
        self.action = action
        self.value = action.payload?["value"] as? String ?? ""
    }
}

/// Typed action for ``PilotSelect`` change events.
public final class PilotSelectAction {
    public let action: PilotAction
    public let value: String

    init(_ action: PilotAction) {
        self.action = action
        self.value = action.payload?["value"] as? String ?? ""
    }
}

/// Typed action for ``PilotTextarea`` submit events.
public final class PilotTextareaAction {
    public let action: PilotAction
    public let value: String

    init(_ action: PilotAction) {
        self.action = action
        self.value = action.payload?["value"] as? String ?? ""
    }
}
