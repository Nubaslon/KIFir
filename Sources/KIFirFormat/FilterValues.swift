//
//  File.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.11.2022.
//

import Foundation

public class FilterValues {
    public static func removeNSNull<T>(from value: T) -> T {
        if let array = value as? [Any] {
            if let filteredValue = array.filter({ !($0 is NSNull) }).map({ removeNSNull(from: $0) }) as? T {
                return filteredValue
            }
        }
        if let dictionary = value as? [String: Any] {
            if let filteredValue = dictionary.filter({!($0.value is NSNull)}).mapValues({ removeNSNull(from: $0) }) as? T {
                return filteredValue
            }
        }
        return value
    }
}
