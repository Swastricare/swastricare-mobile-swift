//
//  DeviceModelHelper.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 06/01/26.
//

import Foundation

struct DeviceModelHelper {
    static func deviceModelName() -> String {
        let identifier = deviceIdentifier()
        if identifier == "i386" || identifier == "x86_64" || identifier == "arm64" {
            if let simIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
               let simModel = modelMap[simIdentifier] {
                return "\(simModel) (Simulator)"
            }
            return "iOS Simulator"
        }
        if let model = modelMap[identifier] {
            return model
        }
        if identifier.hasPrefix("iPhone") {
            return "iPhone (\(identifier))"
        }
        if identifier.hasPrefix("iPad") {
            return "iPad (\(identifier))"
        }
        if identifier.hasPrefix("iPod") {
            return "iPod touch (\(identifier))"
        }
        return "iOS Device"
    }
    
    private static func deviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
    
    // Full iOS device map (iPhone, iPad, iPod). Add new models here as released.
    private static let modelMap: [String: String] = [
        // iPhone
        "iPhone1,1": "iPhone",
        "iPhone1,2": "iPhone 3G",
        "iPhone2,1": "iPhone 3GS",
        "iPhone3,1": "iPhone 4",
        "iPhone3,2": "iPhone 4",
        "iPhone3,3": "iPhone 4",
        "iPhone4,1": "iPhone 4S",
        "iPhone5,1": "iPhone 5",
        "iPhone5,2": "iPhone 5",
        "iPhone5,3": "iPhone 5c",
        "iPhone5,4": "iPhone 5c",
        "iPhone6,1": "iPhone 5s",
        "iPhone6,2": "iPhone 5s",
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone7,2": "iPhone 6",
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1st gen)",
        "iPhone9,1": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,3": "iPhone 7",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,4": "iPhone 8",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        
        // iPod touch
        "iPod1,1": "iPod touch",
        "iPod2,1": "iPod touch (2nd gen)",
        "iPod3,1": "iPod touch (3rd gen)",
        "iPod4,1": "iPod touch (4th gen)",
        "iPod5,1": "iPod touch (5th gen)",
        "iPod7,1": "iPod touch (6th gen)",
        "iPod9,1": "iPod touch (7th gen)",
        
        // iPad
        "iPad1,1": "iPad",
        "iPad2,1": "iPad 2",
        "iPad2,2": "iPad 2",
        "iPad2,3": "iPad 2",
        "iPad2,4": "iPad 2",
        "iPad3,1": "iPad (3rd gen)",
        "iPad3,2": "iPad (3rd gen)",
        "iPad3,3": "iPad (3rd gen)",
        "iPad3,4": "iPad (4th gen)",
        "iPad3,5": "iPad (4th gen)",
        "iPad3,6": "iPad (4th gen)",
        "iPad6,11": "iPad (5th gen)",
        "iPad6,12": "iPad (5th gen)",
        "iPad7,5": "iPad (6th gen)",
        "iPad7,6": "iPad (6th gen)",
        "iPad7,11": "iPad (7th gen)",
        "iPad7,12": "iPad (7th gen)",
        "iPad11,6": "iPad (8th gen)",
        "iPad11,7": "iPad (8th gen)",
        "iPad12,1": "iPad (9th gen)",
        "iPad12,2": "iPad (9th gen)",
        "iPad13,18": "iPad (10th gen)",
        "iPad13,19": "iPad (10th gen)",
        
        // iPad mini
        "iPad2,5": "iPad mini",
        "iPad2,6": "iPad mini",
        "iPad2,7": "iPad mini",
        "iPad4,4": "iPad mini 2",
        "iPad4,5": "iPad mini 2",
        "iPad4,6": "iPad mini 2",
        "iPad4,7": "iPad mini 3",
        "iPad4,8": "iPad mini 3",
        "iPad4,9": "iPad mini 3",
        "iPad5,1": "iPad mini 4",
        "iPad5,2": "iPad mini 4",
        "iPad11,1": "iPad mini (5th gen)",
        "iPad11,2": "iPad mini (5th gen)",
        "iPad14,1": "iPad mini (6th gen)",
        "iPad14,2": "iPad mini (6th gen)",
        
        // iPad Air
        "iPad4,1": "iPad Air",
        "iPad4,2": "iPad Air",
        "iPad4,3": "iPad Air",
        "iPad5,3": "iPad Air 2",
        "iPad5,4": "iPad Air 2",
        "iPad11,3": "iPad Air (3rd gen)",
        "iPad11,4": "iPad Air (3rd gen)",
        "iPad13,1": "iPad Air (4th gen)",
        "iPad13,2": "iPad Air (4th gen)",
        "iPad13,16": "iPad Air (5th gen)",
        "iPad13,17": "iPad Air (5th gen)",
        "iPad14,8": "iPad Air 11-inch (M2)",
        "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)",
        "iPad14,11": "iPad Air 13-inch (M2)",
        
        // iPad Pro
        "iPad6,3": "iPad Pro (9.7-inch)",
        "iPad6,4": "iPad Pro (9.7-inch)",
        "iPad6,7": "iPad Pro (12.9-inch) (1st gen)",
        "iPad6,8": "iPad Pro (12.9-inch) (1st gen)",
        "iPad7,1": "iPad Pro (12.9-inch) (2nd gen)",
        "iPad7,2": "iPad Pro (12.9-inch) (2nd gen)",
        "iPad7,3": "iPad Pro (10.5-inch)",
        "iPad7,4": "iPad Pro (10.5-inch)",
        "iPad8,1": "iPad Pro (11-inch) (1st gen)",
        "iPad8,2": "iPad Pro (11-inch) (1st gen)",
        "iPad8,3": "iPad Pro (11-inch) (1st gen)",
        "iPad8,4": "iPad Pro (11-inch) (1st gen)",
        "iPad8,5": "iPad Pro (12.9-inch) (3rd gen)",
        "iPad8,6": "iPad Pro (12.9-inch) (3rd gen)",
        "iPad8,7": "iPad Pro (12.9-inch) (3rd gen)",
        "iPad8,8": "iPad Pro (12.9-inch) (3rd gen)",
        "iPad8,9": "iPad Pro (11-inch) (2nd gen)",
        "iPad8,10": "iPad Pro (11-inch) (2nd gen)",
        "iPad8,11": "iPad Pro (12.9-inch) (4th gen)",
        "iPad8,12": "iPad Pro (12.9-inch) (4th gen)",
        "iPad13,4": "iPad Pro (11-inch) (3rd gen)",
        "iPad13,5": "iPad Pro (11-inch) (3rd gen)",
        "iPad13,6": "iPad Pro (11-inch) (3rd gen)",
        "iPad13,7": "iPad Pro (11-inch) (3rd gen)",
        "iPad13,8": "iPad Pro (12.9-inch) (5th gen)",
        "iPad13,9": "iPad Pro (12.9-inch) (5th gen)",
        "iPad13,10": "iPad Pro (12.9-inch) (5th gen)",
        "iPad13,11": "iPad Pro (12.9-inch) (5th gen)",
        "iPad14,3": "iPad Pro (11-inch) (4th gen)",
        "iPad14,4": "iPad Pro (11-inch) (4th gen)",
        "iPad14,5": "iPad Pro (12.9-inch) (6th gen)",
        "iPad14,6": "iPad Pro (12.9-inch) (6th gen)",
        "iPad16,3": "iPad Pro (11-inch) (M4)",
        "iPad16,4": "iPad Pro (11-inch) (M4)",
        "iPad16,5": "iPad Pro (13-inch) (M4)",
        "iPad16,6": "iPad Pro (13-inch) (M4)"
    ]
}

