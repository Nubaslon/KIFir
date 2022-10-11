//
//  File.swift
//  
//
//  Created by ANTROPOV Evgeny on 11.10.2022.
//

import Foundation

public protocol DecodableDefaultSource {
    associatedtype Value: Codable & Equatable & Hashable
    static var defaultValue: Value { get }
}

public enum DecodableDefault {
    @propertyWrapper
    public struct Wrapper<Source: DecodableDefaultSource> {
        public init(wrappedValue: Source.Value = Source.defaultValue) {
            self.wrappedValue = wrappedValue
        }
        
        typealias Value = Source.Value
        public var wrappedValue = Source.defaultValue
    }
    
    public typealias Source = DecodableDefaultSource
    public typealias List = Codable & ExpressibleByArrayLiteral & Equatable & Hashable
    public typealias Map = Codable & ExpressibleByDictionaryLiteral & Equatable & Hashable
    
    public typealias True = Wrapper<Sources.True>
    public typealias False = Wrapper<Sources.False>
    public typealias EmptyString = Wrapper<Sources.EmptyString>
    public typealias EmptyList<T: List> = Wrapper<Sources.EmptyList<T>>
    public typealias EmptyMap<T: Map> = Wrapper<Sources.EmptyMap<T>>
    public typealias Integer = Wrapper<Sources.Integer>
    public typealias Double = Wrapper<Sources.Double>
    public typealias UUID = Wrapper<Sources.UUID>
    
    public enum Sources {
        public enum True: Source {
            static public  var defaultValue: Bool { true }
        }
        
        public enum False: Source {
            static public  var defaultValue: Bool { false }
        }
        
        public enum EmptyString: Source {
            static public  var defaultValue: String { "" }
        }
        
        public enum EmptyList<T: List>: Source {
            static public  var defaultValue: T { [] }
        }
        
        public enum EmptyMap<T: Map>: Source {
            static public  var defaultValue: T { [:] }
        }
        
        public enum Integer: Source {
            static public  var defaultValue: Int { 0 }
        }
        
        public enum Double: Source {
            static public  var defaultValue: Swift.Double { Swift.Double(0) }
        }
        
        public enum UUID: Source {
            static public  var defaultValue: Foundation.UUID { Foundation.UUID() }
        }
    }
}

extension DecodableDefault.Wrapper: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension DecodableDefault.Wrapper: Equatable {
    public static func == (lhs: DecodableDefault.Wrapper<Source>, rhs: DecodableDefault.Wrapper<Source>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}
extension DecodableDefault.Wrapper: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = try container.decode(Value.self)
    }
}

extension DecodableDefault.Wrapper: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode<T>(_ type: DecodableDefault.Wrapper<T>.Type,
                   forKey key: Key) throws -> DecodableDefault.Wrapper<T> {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}
