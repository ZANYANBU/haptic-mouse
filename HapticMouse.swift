import Cocoa
import CoreGraphics
import IOKit

// Define Private API types for MultitouchSupport framework
typealias MTActuatorCreateFromDeviceIDType = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
typealias MTActuatorOpenType = @convention(c) (UnsafeMutableRawPointer) -> Int32
typealias MTActuatorCloseType = @convention(c) (UnsafeMutableRawPointer) -> Int32
typealias MTActuatorActuateType = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float32, Float32) -> Int32
typealias MTActuatorIsOpenType = @convention(c) (UnsafeMutableRawPointer) -> Bool

var MTActuatorCreateFromDeviceID: MTActuatorCreateFromDeviceIDType!
var MTActuatorOpen: MTActuatorOpenType!
var MTActuatorClose: MTActuatorCloseType!
var MTActuatorActuate: MTActuatorActuateType!
var MTActuatorIsOpen: MTActuatorIsOpenType!

// Load MultitouchSupport private framework dynamically
func loadMultitouchSupport() -> Bool {
    let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport"
    guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
        return false
    }
    
    guard let createSym = dlsym(handle, "MTActuatorCreateFromDeviceID"),
          let openSym = dlsym(handle, "MTActuatorOpen"),
          let closeSym = dlsym(handle, "MTActuatorClose"),
          let actuateSym = dlsym(handle, "MTActuatorActuate"),
          let isOpenSym = dlsym(handle, "MTActuatorIsOpen") else {
        return false
    }
    
    MTActuatorCreateFromDeviceID = unsafeBitCast(createSym, to: MTActuatorCreateFromDeviceIDType.self)
    MTActuatorOpen = unsafeBitCast(openSym, to: MTActuatorOpenType.self)
    MTActuatorClose = unsafeBitCast(closeSym, to: MTActuatorCloseType.self)
    MTActuatorActuate = unsafeBitCast(actuateSym, to: MTActuatorActuateType.self)
    MTActuatorIsOpen = unsafeBitCast(isOpenSym, to: MTActuatorIsOpenType.self)
    
    return true
}

// Find the MacBook/Magic Trackpad Multitouch Device ID via IOKit
func getTrackpadDeviceID() -> UInt64 {
    let serviceName = "AppleMultitouchDevice"
    let matchingDict = IOServiceMatching(serviceName)
    
    var iterator: io_iterator_t = 0
    let kr = IOServiceGetMatchingServices(0, matchingDict, &iterator)
    
    if kr == KERN_SUCCESS {
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            
            if let property = IORegistryEntryCreateCFProperty(service, "Multitouch ID" as CFString, kCFAllocatorDefault, 0) {
                let val = property.takeRetainedValue()
                if let num = val as? NSNumber {
                    return num.uint64Value
                }
            }
            service = IOIteratorNext(iterator)
        }
    }
    
    return 0x200000001000000
}

// Custom View containing an NSSlider for the Menu Bar dropdown
class HapticSliderView: NSView {
    var slider: NSSlider!
    var label: NSTextField!
    var updateHandler: ((Float) -> Void)?
    
    init(frame frameRect: NSRect, initialValue: Float) {
        super.init(frame: frameRect)
        
        // 1. Text Label
        label = NSTextField(frame: NSRect(x: 16, y: 30, width: 190, height: 18))
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.stringValue = String(format: "Vibration Strength: %.1f", initialValue)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor.labelColor
        self.addSubview(label)
        
        // 2. Horizontal Slider
        slider = NSSlider(frame: NSRect(x: 14, y: 8, width: 190, height: 20))
        slider.minValue = 0.1
        slider.maxValue = 2.0
        slider.doubleValue = Double(initialValue)
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        self.addSubview(slider)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func sliderChanged(_ sender: NSSlider) {
        let val = Float(sender.doubleValue)
        label.stringValue = String(format: "Vibration Strength: %.1f", val)
        updateHandler?(val)
    }
}

class HapticApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    var isEnabled: Bool = true
    var actuator: UnsafeMutableRawPointer? = nil
    
    var lastScrollTime: Double = 0.0
    var lastKeyTime: Double = 0.0
    var lastClickTime: Double = 0.0
    
    // Feature Toggles
    var isKeyboardEnabled: Bool = true
    var isScrollEnabled: Bool = true
    var isClicksEnabled: Bool = true
    
    // Configurable vibration multiplier (Low: ~0.5, Medium: ~1.2, High: ~2.0)
    var intensityMultiplier: Float = 1.2
    
    // Rate limit to prevent feedback storms when moving the slider
    var lastFeedbackTime: Double = 0.0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Status Bar Item in the Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "📳"
        }
        
        setupMenu()
        setupHaptics()
        setupEventTap()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // 1. Master Toggle
        let enableItem = NSMenuItem(title: "Haptic Feedback Enabled", action: #selector(toggleEnable), keyEquivalent: "e")
        enableItem.target = self
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Feature Toggles
        let kbItem = NSMenuItem(title: "Tactile Keyboard Typing", action: #selector(toggleKeyboard), keyEquivalent: "")
        kbItem.target = self
        kbItem.state = isKeyboardEnabled ? .on : .off
        menu.addItem(kbItem)
        
        let scrollItem = NSMenuItem(title: "Tactile Mouse Scrolling", action: #selector(toggleScroll), keyEquivalent: "")
        scrollItem.target = self
        scrollItem.state = isScrollEnabled ? .on : .off
        menu.addItem(scrollItem)
        
        let clickItem = NSMenuItem(title: "Tactile Mouse Clicks", action: #selector(toggleClicks), keyEquivalent: "")
        clickItem.target = self
        clickItem.state = isClicksEnabled ? .on : .off
        menu.addItem(clickItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Custom Slider Menu Item
        let sliderItem = NSMenuItem()
        let sliderView = HapticSliderView(frame: NSRect(x: 0, y: 0, width: 220, height: 52), initialValue: intensityMultiplier)
        sliderView.updateHandler = { [weak self] value in
            guard let self = self else { return }
            self.intensityMultiplier = value
            
            // Provide tactile feedback during dragging (throttled to 80ms)
            let currentTime = ProcessInfo.processInfo.systemUptime * 1000.0
            if (currentTime - self.lastFeedbackTime) >= 80.0 {
                self.lastFeedbackTime = currentTime
                self.triggerHaptics(actuationID: 1, intensity: value)
            }
        }
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Quit Option
        let quitItem = NSMenuItem(title: "Quit HapticMouse", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func toggleKeyboard() {
        isKeyboardEnabled.toggle()
        if let menu = statusItem.menu, let item = menu.items.first(where: { $0.title == "Tactile Keyboard Typing" }) {
            item.state = isKeyboardEnabled ? .on : .off
        }
    }
    
    @objc func toggleScroll() {
        isScrollEnabled.toggle()
        if let menu = statusItem.menu, let item = menu.items.first(where: { $0.title == "Tactile Mouse Scrolling" }) {
            item.state = isScrollEnabled ? .on : .off
        }
    }
    
    @objc func toggleClicks() {
        isClicksEnabled.toggle()
        if let menu = statusItem.menu, let item = menu.items.first(where: { $0.title == "Tactile Mouse Clicks" }) {
            item.state = isClicksEnabled ? .on : .off
        }
    }
    
    @objc func toggleEnable() {
        isEnabled.toggle()
        if let menu = statusItem.menu, let item = menu.item(at: 0) {
            item.state = isEnabled ? .on : .off
        }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: isEnabled)
        }
    }
    
    @objc func quitApp() {
        if let act = actuator {
            _ = MTActuatorClose(act)
        }
        NSApplication.shared.terminate(nil)
    }
    
    func setupHaptics() {
        guard loadMultitouchSupport() else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Library Load Failed"
                alert.informativeText = "HapticMouse was unable to dynamically load MultitouchSupport.framework."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Quit")
                alert.runModal()
                NSApplication.shared.terminate(nil)
            }
            return
        }
        
        let deviceID = getTrackpadDeviceID()
        actuator = MTActuatorCreateFromDeviceID(deviceID)
        
        guard let act = actuator else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Trackpad Actuator Not Found"
                alert.informativeText = "HapticMouse failed to find a haptic trackpad device.\n\nDevice ID: 0x\(String(deviceID, radix: 16))"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Quit")
                alert.runModal()
                NSApplication.shared.terminate(nil)
            }
            return
        }
        
        let openResult = MTActuatorOpen(act)
        if openResult != 0 {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Failed to Open Actuator"
                alert.informativeText = "HapticMouse was unable to open the haptic trackpad device.\n\nError Code: \(openResult)"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Quit")
                alert.runModal()
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    func setupEventTap() {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.rightMouseDown.rawValue) |
                        (1 << CGEventType.otherMouseDown.rawValue) |
                        (1 << CGEventType.scrollWheel.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            let mySelf = Unmanaged<HapticApp>.fromOpaque(refcon!).takeUnretainedValue()
            if !mySelf.isEnabled {
                return Unmanaged.passRetained(event)
            }
            
            let isContinuous = event.getIntegerValueField(CGEventField(rawValue: 88)!)
            
            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                if !mySelf.isClicksEnabled { break }
                let currentTime = ProcessInfo.processInfo.systemUptime * 1000.0
                if (currentTime - mySelf.lastClickTime) >= 50.0 {
                    mySelf.lastClickTime = currentTime
                    // Scale standard click feedback with custom slider value
                    mySelf.triggerHaptics(actuationID: 2, intensity: 1.0 * mySelf.intensityMultiplier)
                }
                
            case .scrollWheel:
                if !mySelf.isScrollEnabled { break }
                if isContinuous == 0 {
                    let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                    if deltaY != 0 {
                        let currentTime = ProcessInfo.processInfo.systemUptime * 1000.0
                        if (currentTime - mySelf.lastScrollTime) >= 100.0 {
                            mySelf.lastScrollTime = currentTime
                            // Scale scroll ticks with custom slider value
                            mySelf.triggerHaptics(actuationID: 1, intensity: 0.7 * mySelf.intensityMultiplier)
                        }
                    }
                }
                
            case .keyDown:
                if !mySelf.isKeyboardEnabled { break }
                let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                if !isAutorepeat {
                    let currentTime = ProcessInfo.processInfo.systemUptime * 1000.0
                    if (currentTime - mySelf.lastKeyTime) >= 120.0 {
                        mySelf.lastKeyTime = currentTime
                        // Scale typing feedback with custom slider value
                        mySelf.triggerHaptics(actuationID: 1, intensity: 0.9 * mySelf.intensityMultiplier)
                    }
                }
                
            default:
                break
            }
            
            return Unmanaged.passRetained(event)
        }
        
        let selfOpaque = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfOpaque
        )
        
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "HapticMouse requires Accessibility permissions to capture clicks and typing for haptic feedback.\n\nPlease enable HapticMouse in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Quit")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    func triggerHaptics(actuationID: Int32, intensity: Float) {
        guard let act = actuator else { return }
        let result = MTActuatorActuate(act, actuationID, 0, 0.0, intensity)
        if result != 0 && result != -536870212 {
            print("[-] Warning: MTActuatorActuate returned error code \(result)")
        }
    }
}

func main() {
    let app = NSApplication.shared
    let delegate = HapticApp()
    app.delegate = delegate
    app.run()
}

main()
