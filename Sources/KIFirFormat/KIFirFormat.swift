//
//  File.swift
//  
//
//  Created by Евгений Антропов on 21.09.2022.
//

import Foundation

public struct RequestSequence: Codable, Hashable, Equatable {
    public init(description: String, requests: [RequestSequence.Request]) {
        self.description = description
        self.requests = requests
    }
    
    public struct Request: Codable, Hashable, Equatable, Identifiable {
        public init(id: UUID = UUID(), description: String, path: String, method: RequestSequence.Request.RequestType, requered: Bool, code: Int, requestSchema: JSONSchemaTyped? = nil, responseSchema: JSONSchemaTyped, responseExamples: [ExampleData], responseTime: Double) {
            self.id = id
            self.description = description
            self.path = path
            self.method = method
            self.requered = requered
            self.code = code
            self.requestSchema = requestSchema
            self.responseSchema = responseSchema
            self.responseExamples = responseExamples
            self.responseTime = responseTime
        }
        
        public enum RequestType: String, Codable {
            case HEAD,GET,POST,PUT,PATCH,DELETE
            public var withRequestBody: Bool {
                switch(self) {
                case .POST,.PUT,.PATCH: return true
                default: return false
                }
            }
        }
        
        public struct ExampleData: Codable, Hashable, Equatable, Identifiable {
            public init(id: UUID = UUID(), name: String, json: String) {
                self.id = id
                self.name = name
                self.json = json
            }
            
            @DecodableDefault.UUID public var id: UUID = UUID()
            @DecodableDefault.EmptyString public var name: String
            @DecodableDefault.EmptyString public var json: String
        }
        
        @DecodableDefault.UUID public var id: UUID = UUID()
        @DecodableDefault.EmptyString public var description: String
        @DecodableDefault.EmptyString public var path: String
        public var method: RequestType
        @DecodableDefault.False public var requered: Bool
        public var code: Int
        public var requestSchema: JSONSchemaTyped?
        public var responseSchema: JSONSchemaTyped
        @DecodableDefault.EmptyList<[ExampleData]> public var responseExamples: [ExampleData]
        @DecodableDefault.Double public var responseTime: Double
    }
    @DecodableDefault.EmptyString public var description: String
    @DecodableDefault.EmptyList<[Request]> public var requests: [Request]
}

public typealias JSONName = String
public struct JSONNamedObject: Codable, Hashable, Equatable, Identifiable {
    public init(name: JSONName, type: JSONSchemaTyped) {
        self.name = name
        self.type = type
    }
    
    @DecodableDefault.UUID public var id = UUID()
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
    case null(JSONSchemaNull)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .object(let a0):
            try container.encode("object", forKey: JSONSchemaTyped.CodingKeys.type)
            var propertyContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .properties)
            for property in a0.properties {
                try propertyContainer.encode(property.type, forKey: .init(stringValue: property.name)!)
            }
            if !a0.required.isEmpty {
                try container.encode(a0.required, forKey: JSONSchemaTyped.CodingKeys.required)
            }
        case .string(let a0):
            try container.encode("string", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: .init(stringValue: "defaultValue")!)
            try container.encode(a0.validValue, forKey: .init(stringValue: "validValue")!)
        case .number(let a0):
            try container.encode("number", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: .init(stringValue: "defaultValue")!)
            try container.encode(a0.validValue, forKey: .init(stringValue: "validValue")!)
        case .integer(let a0):
            try container.encode("integer", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: .init(stringValue: "defaultValue")!)
            try container.encode(a0.validValue, forKey: .init(stringValue: "validValue")!)
        case .array(let a0):
            try container.encode("array", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.items, forKey: JSONSchemaTyped.CodingKeys.items)
            try container.encode(a0.numberOfItems, forKey: .init(stringValue: "numberOfItems")!)
            try container.encode(a0.validNumberOfItems, forKey: .init(stringValue: "validNumberOfItems")!)
        case .bool(let a0):
            try container.encode("boolean", forKey: JSONSchemaTyped.CodingKeys.type)
            try container.encode(a0.defaultValue, forKey: .init(stringValue: "defaultValue")!)
            try container.encode(a0.validValue, forKey: .init(stringValue: "validValue")!)
        case .null(_):
            try container.encode("null", forKey: JSONSchemaTyped.CodingKeys.type)
        }
    }
    
    struct CodingKeys: CodingKey {
        static let type = CodingKeys(stringValue: "type")!
        static let properties = CodingKeys(stringValue: "properties")!
        static let required = CodingKeys(stringValue: "required")!
        static let items = CodingKeys(stringValue: "items")!
        
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
        case "boolean", "bool":
            self = .bool(try decoder.singleValueContainer().decode(JSONSchemaBool.self))
        case "null":
            self = .null(try decoder.singleValueContainer().decode(JSONSchemaNull.self))
        default:
            throw DecodingError.keyNotFound(CodingKeys.type, .init(codingPath: [CodingKeys.type], debugDescription: "Unknown type"))
        }
    }
}

public struct JSONSchemaObject: Codable, Hashable, Equatable {
    public init(properties: [JSONNamedObject], required: [JSONName]) {
        self.properties = properties
        self.required = required
    }
    
    @DecodableDefault.EmptyList<[JSONNamedObject]> public var properties: [JSONNamedObject]
    @DecodableDefault.EmptyList<[JSONName]> public var required: [JSONName]
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RootCodingKeys.self)
        var propertyContainer = container.nestedContainer(keyedBy: CustomCodingKeys.self, forKey: .properties)
        for property in properties {
            try propertyContainer.encode(property.type, forKey: .init(stringValue: property.name)!)
        }
        if !self.required.isEmpty {
            try container.encode(self.required, forKey: .required)
        }
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
        self.required = (try? container.decode([JSONName].self, forKey: .required)) ?? []
    }
}

public enum JSONFillValue: Codable, Hashable, Equatable {
    case random
    case example
    case value(String)
}

public enum JSONFillValidator: Codable, Hashable, Equatable {
    case any
    case constant(String)
}
public struct JSONSchemaArray: Codable, Hashable, Equatable {
    public init(items: [JSONSchemaTyped], numberOfItems: JSONFillValue, validNumberOfItems: JSONFillValidator) {
        self.items = items
        self.numberOfItems = numberOfItems
        self.validNumberOfItems = validNumberOfItems
    }
    
    @DecodableDefault.EmptyList<[JSONSchemaTyped]> public var items: [JSONSchemaTyped]
    public var numberOfItems: JSONFillValue
    public var validNumberOfItems: JSONFillValidator
}

public struct JSONSchemaString: Codable, Hashable, Equatable {
    public init(defaultValue: JSONFillValue, validValue: JSONFillValidator) {
        self.defaultValue = defaultValue
        self.validValue = validValue
    }
    
    public var defaultValue: JSONFillValue
    public var validValue: JSONFillValidator
}

public struct JSONSchemaInteger: Codable, Hashable, Equatable {
    public init(defaultValue: JSONFillValue, validValue: JSONFillValidator) {
        self.defaultValue = defaultValue
        self.validValue = validValue
    }
    
    public var defaultValue: JSONFillValue
    public var validValue: JSONFillValidator
}

public struct JSONSchemaNumber: Codable, Hashable, Equatable {
    public init(defaultValue: JSONFillValue, validValue: JSONFillValidator) {
        self.defaultValue = defaultValue
        self.validValue = validValue
    }
    
    public var defaultValue: JSONFillValue
    public var validValue: JSONFillValidator
}

public struct JSONSchemaBool: Codable, Hashable, Equatable {
    public init(defaultValue: JSONFillValue, validValue: JSONFillValidator) {
        self.defaultValue = defaultValue
        self.validValue = validValue
    }
    
    public var defaultValue: JSONFillValue
    public var validValue: JSONFillValidator
}

public struct JSONSchemaNull: Codable, Hashable, Equatable {
    public init() {}
}
