//
//  File.swift
//  
//
//  Created by Евгений Антропов on 21.09.2022.
//

import Foundation

public struct RequestSequence: Codable, Hashable, Equatable {
    public struct Request: Codable, Hashable, Equatable, Identifiable {
        public enum RequestType: String, Codable {
            case HEAD,GET,POST,PUT,PATCH,DELETE
            public var withRequestBody: Bool {
                switch(self) {
                case .POST,.PUT,.PATCH: return true
                default: return false
                }
            }
        }
        public var id: UUID = UUID()
        public var description: String
        public var path: String
        public var method: RequestType
        public var requered: Bool
        public var code: Int
        public var requestSchema: JSONSchemaTyped?
        public var responseSchema: JSONSchemaTyped
    }
    public var description: String
    public var requests: [Request]
}

public typealias JSONName = String
public struct JSONNamedObject: Codable, Hashable, Equatable, Identifiable {
    public init(name: JSONName, type: JSONSchemaTyped) {
        self.name = name
        self.type = type
    }
    
    public var id = UUID()
    public var name: JSONName
    public var type: JSONSchemaTyped
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CustomCodingKeys.self)
        try container.encode(self.type, forKey: .init(stringValue: name)!)
    }
    
    struct CustomCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CustomCodingKeys.self)
        if let key = container.allKeys.first {
            let value = try container.decode(JSONSchemaTyped.self, forKey: CustomCodingKeys(stringValue: key.stringValue)!)
            self = JSONNamedObject(name: key.stringValue, type: value)
            return
        }
        throw DecodingError.keyNotFound(CustomCodingKeys(stringValue: "name")!, .init(codingPath: [CustomCodingKeys(stringValue: "name")!], debugDescription: "Unknown type"))
    }
}
public enum JSONSchemaTyped: Codable, Hashable, Equatable {
    case object(JSONSchemaObject)
    case string(JSONSchemaString)
    case integer(JSONSchemaInteger)
    case number(JSONSchemaNumber)
    case array(JSONSchemaArray)
    case bool(JSONSchemaBool)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .object(let a0):
            try container.encode("object", forKey: JSONSchemaTyped.CodingKeys.type)
            var propertyContainer = container.nestedContainer(keyedBy: CustomCodingKeys.self, forKey: .properties)
            for property in a0.properties {
                try propertyContainer.encode(property.type, forKey: .init(stringValue: property.name)!)
            }
            try container.encode(a0.required, forKey: JSONSchemaTyped.CodingKeys.required)
        case .string(let a0):
            try container.encode("string", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: JSONSchemaTyped.CodingKeys.defaultValue)
        case .number(let a0):
            try container.encode("number", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: JSONSchemaTyped.CodingKeys.defaultValue)
        case .integer(let a0):
            try container.encode("integer", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: JSONSchemaTyped.CodingKeys.defaultValue)
        case .array(let a0):
            try container.encode("array", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.items, forKey: JSONSchemaTyped.CodingKeys.items)
            try container.encode(a0.numberOfItems, forKey: JSONSchemaTyped.CodingKeys.numberOfItems)
        case .bool(let a0):
            try container.encode("bool", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: JSONSchemaTyped.CodingKeys.defaultValue)
        }
    }
    
    struct CustomCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
    
    enum CodingKeys: CodingKey {
        case type
        case properties
        case required
        case defaultValue
        case items
        case numberOfItems
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch(type) {
        case "object":
            self = .object(try decoder.singleValueContainer().decode(JSONSchemaObject.self))
        case "string":
            self = .string(try decoder.singleValueContainer().decode(JSONSchemaString.self))
        case "integer":
            self = .integer(try decoder.singleValueContainer().decode(JSONSchemaInteger.self))
        case "number":
            self = .number(try decoder.singleValueContainer().decode(JSONSchemaNumber.self))
        case "array":
            self = .array(try decoder.singleValueContainer().decode(JSONSchemaArray.self))
        case "bool":
            self = .bool(try decoder.singleValueContainer().decode(JSONSchemaBool.self))
        default:
            throw DecodingError.keyNotFound(CodingKeys.type, .init(codingPath: [CodingKeys.type], debugDescription: "Unknown type"))
        }
    }
}

public struct JSONSchemaObject: Codable, Hashable, Equatable {
    internal init(properties: [JSONNamedObject], required: [JSONName]) {
        self.properties = properties
        self.required = required
    }
    
    public var properties: [JSONNamedObject]
    public var required: [JSONName]
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RootCodingKeys.self)
        var propertyContainer = container.nestedContainer(keyedBy: CustomCodingKeys.self, forKey: .properties)
        for property in properties {
            try propertyContainer.encode(property.type, forKey: .init(stringValue: property.name)!)
        }
        try container.encode(self.required, forKey: .required)
    }
    
    public struct CustomCodingKeys: CodingKey {
        public var stringValue: String
        public init?(stringValue: String) {
            self.stringValue = stringValue
        }
        public var intValue: Int?
        public init?(intValue: Int) {
            return nil
        }
    }
    
    public enum RootCodingKeys: CodingKey {
        case properties
        case required
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootCodingKeys.self)
        let propertyContainer = try container.nestedContainer(keyedBy: CustomCodingKeys.self, forKey: .properties)
        var properties = [JSONNamedObject]()
        for key in propertyContainer.allKeys {
            let object = try propertyContainer.decode(JSONSchemaTyped.self, forKey: key)
            properties.append(.init(name: key.stringValue, type: object))
        }
        self.properties = properties
        self.required = try container.decode([JSONName].self, forKey: .required)
    }
}

public struct JSONSchemaArray: Codable, Hashable, Equatable {
    public init(items: [JSONSchemaTyped], numberOfItems: [UInt]) {
        self.items = items
        self.numberOfItems = numberOfItems
    }
    
    public var items: [JSONSchemaTyped]
    public var numberOfItems: [UInt]
}
public struct JSONSchemaString: Codable, Hashable, Equatable {
    public init(defaultValue: [String]) {
        self.defaultValue = defaultValue
    }
    
    public var defaultValue: [String]
}

public struct JSONSchemaInteger: Codable, Hashable, Equatable {
    public init(defaultValue: [String]) {
        self.defaultValue = defaultValue
    }
    
    public var defaultValue: [String]
}

public struct JSONSchemaNumber: Codable, Hashable, Equatable {
    public init(defaultValue: [String]) {
        self.defaultValue = defaultValue
    }
    
    public var defaultValue: [String]
}

public struct JSONSchemaBool: Codable, Hashable, Equatable {
    public init(defaultValue: [String]) {
        self.defaultValue = defaultValue
    }
    
    public var defaultValue: [String]
}
