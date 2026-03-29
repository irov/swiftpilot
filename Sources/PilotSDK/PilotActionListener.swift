import Foundation

public protocol PilotActionListener: AnyObject {
    func onPilotActionReceived(_ action: PilotAction)
}
