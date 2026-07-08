import Foundation
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

func loadMultitouchSupport() -> Bool {
    let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport"
    guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
        print("[-] Error: Failed to load MultitouchSupport framework")
        return false
    }
    
    MTActuatorCreateFromDeviceID = unsafeBitCast(dlsym(handle, "MTActuatorCreateFromDeviceID"), to: MTActuatorCreateFromDeviceIDType.self)
    MTActuatorOpen = unsafeBitCast(dlsym(handle, "MTActuatorOpen"), to: MTActuatorOpenType.self)
    MTActuatorClose = unsafeBitCast(dlsym(handle, "MTActuatorClose"), to: MTActuatorCloseType.self)
    MTActuatorActuate = unsafeBitCast(dlsym(handle, "MTActuatorActuate"), to: MTActuatorActuateType.self)
    MTActuatorIsOpen = unsafeBitCast(dlsym(handle, "MTActuatorIsOpen"), to: MTActuatorIsOpenType.self)
    return true
}

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

func main() {
    print("=== Haptic Test Starting ===")
    guard loadMultitouchSupport() else {
        print("[-] Error: Failed to load MultitouchSupport")
        return
    }
    
    let deviceID = getTrackpadDeviceID()
    print("[+] Device ID: 0x\(String(deviceID, radix: 16))")
    
    // We will test both the dynamically discovered ID and the standard fallback ID
    let idsToTest = [deviceID, 0x200000001000000]
    
    for id in idsToTest {
        print("\n--- Testing Actuator with ID: 0x\(String(id, radix: 16)) ---")
        guard let actuator = MTActuatorCreateFromDeviceID(id) else {
            print("[-] Failed to create actuator for ID 0x\(String(id, radix: 16))")
            continue
        }
        
        let openResult = MTActuatorOpen(actuator)
        if openResult != 0 {
            print("[-] Failed to open actuator (Error: \(openResult))")
            continue
        }
        
        print("[+] Actuator opened. Triggering 5 haptic pulses (1 per second)...")
        // Try different haptic profiles (1 to 5)
        for pulse in 1...5 {
            print("  [Pulse \(pulse)] Actuating profile ID \(pulse)...")
            // Try standard click (2), force click (4), silent click (6), tick (1)
            let actuateID: Int32
            switch pulse {
            case 1: actuateID = 1 // Tick
            case 2: actuateID = 2 // Click
            case 3: actuateID = 6 // Silent click
            case 4: actuateID = 15 // Alternate
            default: actuateID = 2 // Click
            }
            
            let result = MTActuatorActuate(actuator, actuateID, 0, 0.0, 0.0)
            if result != 0 {
                print("    [-] Failed to actuate (Error: \(result))")
            }
            sleep(1)
        }
        
        _ = MTActuatorClose(actuator)
        print("[+] Test completed for this device.")
    }
    
    print("\n=== Haptic Test Finished ===")
}

main()
