import Foundation
#if os(iOS)
import UIKit
import ObjectiveC.runtime
import Darwin

private typealias PilotIOHIDEventRef = OpaquePointer
private typealias PilotCFAllocatorRef = UnsafeRawPointer?
private typealias PilotIOOptionBits = UInt32
private typealias PilotIOHIDDigitizerTransducerType = UInt32
private typealias PilotIOHIDEventField = UInt32
private typealias PilotBoolean = UInt8
private typealias PilotAbsoluteTime = UInt64

#if arch(arm64) || arch(x86_64)
private typealias PilotIOHIDFloat = Double
#else
private typealias PilotIOHIDFloat = Float
#endif

private typealias PilotIOHIDEventCreateDigitizerEventProc = @convention(c) (
    PilotCFAllocatorRef,
    PilotAbsoluteTime,
    PilotIOHIDDigitizerTransducerType,
    UInt32,
    UInt32,
    UInt32,
    UInt32,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotBoolean,
    PilotBoolean,
    PilotIOOptionBits
) -> PilotIOHIDEventRef?

private typealias PilotIOHIDEventCreateDigitizerFingerEventWithQualityProc = @convention(c) (
    PilotCFAllocatorRef,
    PilotAbsoluteTime,
    UInt32,
    UInt32,
    UInt32,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotIOHIDFloat,
    PilotBoolean,
    PilotBoolean,
    PilotIOOptionBits
) -> PilotIOHIDEventRef?

private typealias PilotIOHIDEventAppendEventProc = @convention(c) (PilotIOHIDEventRef?, PilotIOHIDEventRef?) -> Void
private typealias PilotIOHIDEventSetIntegerValueProc = @convention(c) (PilotIOHIDEventRef?, PilotIOHIDEventField, Int32) -> Void

private enum PilotSyntheticTouchDispatcher {
    struct Target {
        let window: UIWindow
        let hitView: UIView
        let point: CGPoint
    }

    static func resolveTarget(normalizedX: Double, normalizedY: Double) -> Target? {
        let clampedX = min(max(normalizedX, 0), 1)
        let clampedY = min(max(normalizedY, 0), 1)

        let sortedWindows = applicationWindows().sorted { lhs, rhs in
            if lhs.windowLevel != rhs.windowLevel {
                return lhs.windowLevel < rhs.windowLevel
            }

            if lhs.isKeyWindow != rhs.isKeyWindow {
                return lhs.isKeyWindow == false
            }

            return false
        }

        var fallback: Target?

        for window in sortedWindows.reversed() {
            guard window.isHidden == false,
                  window.alpha > 0.01,
                  window.bounds.width > 0,
                  window.bounds.height > 0 else {
                continue
            }

            let point = CGPoint(
                x: CGFloat(clampedX) * window.bounds.width,
                y: CGFloat(clampedY) * window.bounds.height
            )

            fallback = fallback ?? Target(window: window, hitView: window, point: point)

            if let hitView = window.hitTest(point, with: nil) {
                return Target(window: window, hitView: hitView, point: point)
            }
        }

        return fallback
    }

    static func sendTap(to target: Target) -> Bool {
        guard let touch = SyntheticTouch(target: target) else {
            return false
        }

        guard sendEvent(with: [touch]) else {
            return false
        }

        touch.setPhase(.ended)
        return sendEvent(with: [touch])
    }

    static func sendLongPress(to target: Target,
                              durationMs: Int,
                              onRelease: (() -> Void)? = nil) -> Bool {
        guard let touch = SyntheticTouch(target: target) else {
            return false
        }

        guard sendEvent(with: [touch]) else {
            return false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(durationMs)) {
            touch.setPhase(.ended)
            onRelease?()
            _ = sendEvent(with: [touch])
        }

        return true
    }

    private static func applicationWindows() -> [UIWindow] {
        let application = UIApplication.shared

        if #available(iOS 13.0, *) {
            return application.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter {
                    $0.activationState == .foregroundActive ||
                    $0.activationState == .foregroundInactive
                }
                .flatMap { $0.windows }
        }

        return application.windows
    }

    private static func sendEvent(with touches: [SyntheticTouch]) -> Bool {
        guard let event = event(with: touches) else {
            return false
        }

        UIApplication.shared.sendEvent(event)
        return true
    }

    private static func event(with touches: [SyntheticTouch]) -> UIEvent? {
        let application = UIApplication.shared
        let touchesEventSelector = NSSelectorFromString("_touchesEvent")

        guard application.responds(to: touchesEventSelector),
              let event = PilotRuntime.objectReturn(target: application, selector: touchesEventSelector) as? UIEvent else {
            return nil
        }

        let clearSelector = NSSelectorFromString("_clearTouches")
        let addTouchSelector = NSSelectorFromString("_addTouch:forDelayedDelivery:")
        let setHidEventSelector = NSSelectorFromString("_setHIDEvent:")

        guard event.responds(to: clearSelector),
              event.responds(to: addTouchSelector),
              event.responds(to: setHidEventSelector) else {
            return nil
        }

        PilotRuntime.voidReturn(target: event, selector: clearSelector)

        if let hidEvent = createHidEvent(for: touches) {
            PilotRuntime.voidReturn(target: event, selector: setHidEventSelector, pointer: hidEvent)
            release(hidEvent)
        }

        for touch in touches {
            PilotRuntime.voidReturn(target: event,
                                    selector: addTouchSelector,
                                    object: touch.touch,
                                    bool: false)
        }

        return event
    }

    private static func createHidEvent(for touches: [SyntheticTouch]) -> PilotIOHIDEventRef? {
        guard let createDigitizerEvent = PilotHIDFunctions.shared.createDigitizerEvent,
              let createFingerEvent = PilotHIDFunctions.shared.createFingerEvent,
              let appendEvent = PilotHIDFunctions.shared.appendEvent else {
            return nil
        }

        let timeStamp = absoluteTimeNow()
        let handEvent = createDigitizerEvent(
            nil,
            timeStamp,
            3,
            0,
            0,
            0x00000002,
            0,
            0,
            0,
            0,
            0,
            0,
            1,
            1,
            0
        )

        guard let handEvent else {
            return nil
        }

        if let setIntegerValue = PilotHIDFunctions.shared.setIntegerValue {
            setIntegerValue(handEvent, 0x000B0018, 1)
        }

        for (index, touch) in touches.enumerated() {
            let isTouching = touch.phase == .ended || touch.phase == .cancelled ? 0 : 1
            let eventMask: UInt32 = touch.phase == .moved ? 0x00000004 : (0x00000001 | 0x00000002)

            let fingerEvent = createFingerEvent(
                nil,
                timeStamp,
                UInt32(index + 1),
                2,
                eventMask,
                PilotIOHIDFloat(touch.point.x),
                PilotIOHIDFloat(touch.point.y),
                0,
                0,
                0,
                5.0,
                5.0,
                1.0,
                1.0,
                1.0,
                PilotBoolean(isTouching),
                PilotBoolean(isTouching),
                0
            )

            guard let fingerEvent else {
                continue
            }

            if let setIntegerValue = PilotHIDFunctions.shared.setIntegerValue {
                setIntegerValue(fingerEvent, 0x000B0018, 1)
            }

            appendEvent(handEvent, fingerEvent)
            release(fingerEvent)
        }

        return handEvent
    }

    private static func absoluteTimeNow() -> PilotAbsoluteTime {
        return mach_absolute_time()
    }

    private static func release(_ event: PilotIOHIDEventRef) {
        let pointer = UnsafeMutableRawPointer(event)
        Unmanaged<AnyObject>.fromOpaque(pointer).release()
    }

    private final class SyntheticTouch {
        let touch: UITouch
        let window: UIWindow
        let hitView: UIView
        var point: CGPoint
        var phase: UITouch.Phase

        init?(target: Target) {
            guard let touchClass = NSClassFromString("UITouch") as? NSObject.Type,
                  let touch = touchClass.init() as? UITouch else {
                return nil
            }

            self.touch = touch
            self.window = target.window
            self.hitView = target.hitView
            self.point = target.point
            self.phase = .began

            guard configureInitialState() else {
                return nil
            }
        }

        func setPhase(_ newPhase: UITouch.Phase) {
            self.phase = newPhase

            let timestampSelector = NSSelectorFromString("setTimestamp:")
            let phaseSelector = NSSelectorFromString("setPhase:")
            let hidEventSelector = NSSelectorFromString("_setHidEvent:")

            if touch.responds(to: timestampSelector) {
                PilotRuntime.voidReturn(target: touch,
                                        selector: timestampSelector,
                                        timeInterval: ProcessInfo.processInfo.systemUptime)
            }

            if touch.responds(to: phaseSelector) {
                PilotRuntime.voidReturn(target: touch, selector: phaseSelector, integer: newPhase.rawValue)
            }

            if touch.responds(to: hidEventSelector),
               let hidEvent = createHidEvent(for: [self]) {
                PilotRuntime.voidReturn(target: touch, selector: hidEventSelector, pointer: hidEvent)
                release(hidEvent)
            }
        }

        private func configureInitialState() -> Bool {
            let setWindowSelector = NSSelectorFromString("setWindow:")
            let setViewSelector = NSSelectorFromString("setView:")
            let setTapCountSelector = NSSelectorFromString("setTapCount:")
            let setIsTapSelector = NSSelectorFromString("setIsTap:")
            let setTimestampSelector = NSSelectorFromString("setTimestamp:")
            let setPhaseSelector = NSSelectorFromString("setPhase:")
            let setGestureViewSelector = NSSelectorFromString("setGestureView:")
            let setFirstTouchSelector = NSSelectorFromString("_setIsFirstTouchForView:")
            let setTapToClickSelector = NSSelectorFromString("_setIsTapToClick:")
            let setLocationSelector = NSSelectorFromString("_setLocationInWindow:resetPrevious:")
            let setHidEventSelector = NSSelectorFromString("_setHidEvent:")

            guard touch.responds(to: setWindowSelector),
                  touch.responds(to: setViewSelector),
                  touch.responds(to: setTapCountSelector),
                  touch.responds(to: setTimestampSelector),
                  touch.responds(to: setPhaseSelector),
                  touch.responds(to: setLocationSelector) else {
                return false
            }

            PilotRuntime.voidReturn(target: touch, selector: setWindowSelector, object: window)
            PilotRuntime.voidReturn(target: touch, selector: setTapCountSelector, unsignedInteger: 1)
            PilotRuntime.voidReturn(target: touch, selector: setLocationSelector, point: point, bool: true)
            PilotRuntime.voidReturn(target: touch, selector: setViewSelector, object: hitView)
            PilotRuntime.voidReturn(target: touch,
                                    selector: setTimestampSelector,
                                    timeInterval: ProcessInfo.processInfo.systemUptime)
            PilotRuntime.voidReturn(target: touch, selector: setPhaseSelector, integer: phase.rawValue)

            if touch.responds(to: setIsTapSelector) {
                PilotRuntime.voidReturn(target: touch, selector: setIsTapSelector, bool: true)
            }

            if touch.responds(to: setGestureViewSelector) {
                PilotRuntime.voidReturn(target: touch, selector: setGestureViewSelector, object: hitView)
            }

            if touch.responds(to: setFirstTouchSelector) {
                PilotRuntime.voidReturn(target: touch, selector: setFirstTouchSelector, bool: true)
            } else if touch.responds(to: setTapToClickSelector) {
                PilotRuntime.voidReturn(target: touch, selector: setTapToClickSelector, bool: true)
                setFirstTouchFlag()
            }

            if touch.responds(to: setHidEventSelector),
               let hidEvent = createHidEvent(for: [self]) {
                PilotRuntime.voidReturn(target: touch, selector: setHidEventSelector, pointer: hidEvent)
                release(hidEvent)
            }

            return true
        }

        private func setFirstTouchFlag() {
            guard let touchClass = object_getClass(touch),
                  let flagsIvar = class_getInstanceVariable(touchClass, "_touchFlags") else {
                return
            }

            let objectPointer = Unmanaged.passUnretained(touch).toOpaque()
            let flagsPointer = objectPointer
                .advanced(by: ivar_getOffset(flagsIvar))
                .assumingMemoryBound(to: UInt8.self)
            flagsPointer.pointee |= 0x01
        }
    }
}

private enum PilotRuntime {
    static func objectReturn(target: NSObject, selector: Selector) -> AnyObject? {
        typealias Function = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        return function(target, selector)?.takeUnretainedValue()
    }

    static func voidReturn(target: NSObject, selector: Selector) {
        typealias Function = @convention(c) (AnyObject, Selector) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector)
    }

    static func voidReturn(target: NSObject, selector: Selector, object: AnyObject?) {
        typealias Function = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, object)
    }

    static func voidReturn(target: NSObject, selector: Selector, bool: Bool) {
        typealias Function = @convention(c) (AnyObject, Selector, Bool) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, bool)
    }

    static func voidReturn(target: NSObject, selector: Selector, unsignedInteger: UInt) {
        typealias Function = @convention(c) (AnyObject, Selector, UInt) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, unsignedInteger)
    }

    static func voidReturn(target: NSObject, selector: Selector, integer: Int) {
        typealias Function = @convention(c) (AnyObject, Selector, Int) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, integer)
    }

    static func voidReturn(target: NSObject, selector: Selector, timeInterval: TimeInterval) {
        typealias Function = @convention(c) (AnyObject, Selector, TimeInterval) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, timeInterval)
    }

    static func voidReturn(target: NSObject, selector: Selector, point: CGPoint, bool: Bool) {
        typealias Function = @convention(c) (AnyObject, Selector, CGPoint, Bool) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, point, bool)
    }

    static func voidReturn(target: NSObject, selector: Selector, pointer: PilotIOHIDEventRef) {
        typealias Function = @convention(c) (AnyObject, Selector, PilotIOHIDEventRef) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, pointer)
    }

    static func voidReturn(target: NSObject,
                           selector: Selector,
                           object: AnyObject?,
                           bool: Bool) {
        typealias Function = @convention(c) (AnyObject, Selector, AnyObject?, Bool) -> Void
        let implementation = target.method(for: selector)
        let function = unsafeBitCast(implementation, to: Function.self)
        function(target, selector, object, bool)
    }
}

private final class PilotHIDFunctions {
    static let shared = PilotHIDFunctions()

    let createDigitizerEvent: PilotIOHIDEventCreateDigitizerEventProc?
    let createFingerEvent: PilotIOHIDEventCreateDigitizerFingerEventWithQualityProc?
    let appendEvent: PilotIOHIDEventAppendEventProc?
    let setIntegerValue: PilotIOHIDEventSetIntegerValueProc?

    private init() {
        let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)

        self.createDigitizerEvent = PilotHIDFunctions.resolveCreateDigitizerEvent(handle)
        self.createFingerEvent = PilotHIDFunctions.resolveCreateFingerEvent(handle)
        self.appendEvent = PilotHIDFunctions.resolveAppendEvent(handle)
        self.setIntegerValue = PilotHIDFunctions.resolveSetIntegerValue(handle)
    }

    private static func resolveCreateDigitizerEvent(_ handle: UnsafeMutableRawPointer?) -> PilotIOHIDEventCreateDigitizerEventProc? {
        guard let handle,
              let address = dlsym(handle, "IOHIDEventCreateDigitizerEvent") else {
            return nil
        }

        return unsafeBitCast(address, to: PilotIOHIDEventCreateDigitizerEventProc.self)
    }

    private static func resolveCreateFingerEvent(_ handle: UnsafeMutableRawPointer?) -> PilotIOHIDEventCreateDigitizerFingerEventWithQualityProc? {
        guard let handle,
              let address = dlsym(handle, "IOHIDEventCreateDigitizerFingerEventWithQuality") else {
            return nil
        }

        return unsafeBitCast(address, to: PilotIOHIDEventCreateDigitizerFingerEventWithQualityProc.self)
    }

    private static func resolveAppendEvent(_ handle: UnsafeMutableRawPointer?) -> PilotIOHIDEventAppendEventProc? {
        guard let handle,
              let address = dlsym(handle, "IOHIDEventAppendEvent") else {
            return nil
        }

        return unsafeBitCast(address, to: PilotIOHIDEventAppendEventProc.self)
    }

    private static func resolveSetIntegerValue(_ handle: UnsafeMutableRawPointer?) -> PilotIOHIDEventSetIntegerValueProc? {
        guard let handle,
              let address = dlsym(handle, "IOHIDEventSetIntegerValue") else {
            return nil
        }

        return unsafeBitCast(address, to: PilotIOHIDEventSetIntegerValueProc.self)
    }
}
#endif