//
//  KIFirServer.swift
//  
//
//  Created by Евгений Антропов on 21.09.2022.
//

import Foundation
import Fakery
import Swifter
import KIFirFormat
import JSONSchema

public class KIFirServer {
    struct CustomError: Error {
        var localizedDescription: String
    }
    
    public struct ServerConfig {
        public init(optionalReturning: KIFirServer.ServerConfig.OptionalParams, port: UInt16 = 8080, locale: String = "ru") {
            self.optionalReturning = optionalReturning
            self.port = port
            self.locale = locale
        }
        
        public enum OptionalParams {
            case returnAll
            case returnNone
            case returnRandom
        }
        public var optionalReturning: OptionalParams
        public var port: UInt16 = 8080
        public var locale = "ru"
    }
    
    public var config: ServerConfig
    var swifter = HttpServer()
    var faker = Faker(locale: "en-US")
    var customParams = [String: () -> String]()
    
    public init(config: ServerConfig) {
        self.config = config
        try? swifter.start(config.port)
        generateFakerySymlink()
        enableDefaultRoutes()
    }
    
    public func updateConfig(config: ServerConfig) {
        self.config = config
        restartServer()
    }
    
    public func restartServer() {
        swifter.stop()
        swifter = HttpServer()
        try? swifter.start(config.port)
        enableDefaultRoutes()
    }
    
    func enableDefaultRoutes() {
        swifter.notFoundHandler = { request in
            print("NotFound request: \(request)")
            return .notFound
        }
        swifter.PUT["/_update"] = { request in
            guard !request.body.isEmpty else { return .badRequest(.text("Request body is empty"))}
            let data = Data(request.body)
            let decoder = JSONDecoder()
            do {
                let object = try decoder.decode(RequestSequence.self, from: data)
                print("Did updated routes from HTTP")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.updateRoutes(sequence: object)
                }
                return .created
            } catch {
                return .badRequest(.text(error.localizedDescription))
            }
        }
    }
    
    public func updateRoutes(sequence: RequestSequence) {
        // I found only this way to reset all routes
        restartServer()
        
        struct RequestKey: Hashable, Equatable {
            var path: String
            var method: RequestSequence.Request.RequestType
        }
        let pathList = sequence.requests.reduce(into: [RequestKey: [RequestSequence.Request]]()) { partialResult, request in
            if partialResult[RequestKey(path: request.path, method: request.method)] == nil {
                partialResult[RequestKey(path: request.path, method: request.method)] = [request]
            } else {
                partialResult[RequestKey(path: request.path, method: request.method)]?.append(request)
            }
        }
        for (path, requests) in pathList {
            switch(path.method) {
            case .HEAD:
                swifter.HEAD[path.path] = handleRequest(requests: requests)
            case .GET:
                swifter.GET[path.path] = handleRequest(requests: requests)
            case .POST:
                swifter.POST[path.path] = handleRequest(requests: requests)
            case .PUT:
                swifter.PUT[path.path] = handleRequest(requests: requests)
            case .PATCH:
                swifter.PATCH[path.path] = handleRequest(requests: requests)
            case .DELETE:
                swifter.DELETE[path.path] = handleRequest(requests: requests)
            }
        }
    }
    
    func handleRequest(requests: [RequestSequence.Request]) -> ((HttpRequest) -> HttpResponse) {
        return { request in
            var lastError: Error?
            for requestObject in requests {
                do {
                    if RequestSequence.Request.RequestType(rawValue: request.method)?.withRequestBody == true,
                       let requestSchema = requestObject.requestSchema {
                        try self.checkRequest(schema: requestSchema, data: Data(request.body))
                    }
                    let object = self.generateResponce(
                        schema: requestObject.responseSchema,
                        params: request.params.merging(request.queryParams, uniquingKeysWith: { _, new in new })
                    )
                    if object is [String: Any] || object is [Any],
                        let data = try? JSONSerialization.data(withJSONObject: object) {
                        print("Success request: \(request)")
                        return .raw(requestObject.code, "OK", ["Content-Type": "application/json"]) { writer in
                            try? writer.write(data)
                        }
                    } else {
                        print("Success request: \(request)")
                        return .raw(requestObject.code, "OK", [:]) { writer in
                            let data = String("\(object)").data(using: .utf8) ?? Data()
                            try? writer.write(data)
                        }
                    }
                } catch {
                    if let decodingError = error as? DecodingError {
                        if case let .dataCorrupted(context) = decodingError {
                            let newDecodingErrorDescription = context.debugDescription
                            if let prevError = lastError as? CustomError,
                               prevError.localizedDescription.count > newDecodingErrorDescription.count {
                                lastError = CustomError(localizedDescription: newDecodingErrorDescription)
                            } else if !(lastError is CustomError) {
                                lastError = CustomError(localizedDescription: newDecodingErrorDescription)
                            }
                        }
                    } else {
                        if lastError == nil {
                            lastError = error
                        }
                    }
                }
            }
            if let lastError = lastError {
                if let lastError = lastError as? CustomError {
                    print("Error request: \(request)\n\(lastError.localizedDescription)")
                    return .badRequest(.text(lastError.localizedDescription))
                } else {
                    print("Error request: \(request)\n\(lastError.localizedDescription)")
                    return .badRequest(.text(lastError.localizedDescription))
                }
            } else {
                print("NotFound request: \(request)")
                return .notFound
            }
        }
    }
    
    func checkRequest(schema: JSONSchemaTyped, data: Data) throws {
        let json = try JSONSerialization.jsonObject(with: data)
        let encoder = JSONEncoder()
        let jsonSchemaData = try encoder.encode(schema)
        let jsonSchema = try JSONSerialization.jsonObject(with: jsonSchemaData)
        guard let jsonSchema = jsonSchema as? [String: Any] else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad schma"))}
        let result = try JSONSchema.validate(json, schema: jsonSchema)
        switch(result) {
        case .valid:
            return
        case .invalid(let errors):
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: errors.map { $0.instanceLocation.path + " : " + $0.description }.joined(separator: "\n")
                )
            )
        }
    }
    
    func generateResponce(schema: JSONSchemaTyped, params: [String: String]) -> Any {
        switch(schema) {
        case .object(let object):
            var dictionary = [String: Any]()
            for property in object.properties {
                switch(config.optionalReturning) {
                case .returnAll:
                    dictionary[property.name] = generateResponce(schema: property.type, params: params)
                case .returnRandom where Bool.random():
                    dictionary[property.name] = generateResponce(schema: property.type, params: params)
                default:
                    ()
                }
            }
            return dictionary
        case .string(let string):
            return replace(string: string.defaultValue.first ?? "", params: params)
        case .integer(let integer):
            return Int(replace(string: integer.defaultValue.first ?? "", params: params)) ?? 0
        case .number(let number):
            return Double(replace(string: number.defaultValue.first ?? "", params: params)) ?? 0
        case .bool(let bool):
            let boolString = replace(string: bool.defaultValue.first ?? "", params: params)
            return boolString.uppercased() == "TRUE" || boolString.uppercased() == "YES" || boolString.uppercased() == "1"
        case .array(let object):
            var array = [Any]()
            guard let items = object.numberOfItems.first, items > 0 else { return array }
            for _ in 0...(Int(items) - 1) {
                array.append(generateResponce(schema: object.items.randomElement() ?? .string(.init(defaultValue: [])), params: params))
            }
            return array
        }
    }
    
    func replace(string: String, params: [String: String]) -> String {
        var newString = string
        let stringKeys = try! Regex.matches(string, pattern: "\\{(.+?)\\}")
        for key in stringKeys {
            if let value = params[":" + key] {
                newString = newString.replacingOccurrences(of: "{\(key)}", with: value)
            }
            if let value = params[key] {
                newString = newString.replacingOccurrences(of: "{\(key)}", with: value)
            }
            if let value = customParams[key]?() {
                newString = newString.replacingOccurrences(of: "{\(key)}", with: value)
            }
        }
        return newString
    }
    
    func generateFakerySymlink() {
        customParams["uuid"] = { UUID().uuidString }
        customParams["fakery.address.city"] = { self.faker.address.city() }
        customParams["fakery.address.streetName"] = { self.faker.address.streetName() }
        customParams["fakery.address.secondaryAddress"] = { self.faker.address.secondaryAddress() }
        customParams["fakery.address.streetAddress"] = { self.faker.address.streetAddress() }
        customParams["fakery.address.buildingNumber"] = { self.faker.address.buildingNumber() }
        customParams["fakery.address.postcode"] = { self.faker.address.postcode() }
        customParams["fakery.address.timeZone"] = { self.faker.address.timeZone() }
        customParams["fakery.address.streetSuffix"] = { self.faker.address.streetSuffix() }
        customParams["fakery.address.citySuffix"] = { self.faker.address.citySuffix() }
        customParams["fakery.address.cityPrefix"] = { self.faker.address.cityPrefix() }
        customParams["fakery.address.stateAbbreviation"] = { self.faker.address.stateAbbreviation() }
        customParams["fakery.address.state"] = { self.faker.address.state() }
        customParams["fakery.address.county"] = { self.faker.address.county() }
        customParams["fakery.address.country"] = { self.faker.address.country() }
        customParams["fakery.address.countryCode"] = { self.faker.address.countryCode() }
        customParams["fakery.address.latitude"] = { "\(self.faker.address.latitude())" }
        customParams["fakery.address.longitude"] = { "\(self.faker.address.longitude())" }
        customParams["fakery.app.name"] = { self.faker.app.name() }
        customParams["fakery.app.version"] = { self.faker.app.version() }
        customParams["fakery.app.author"] = { self.faker.app.author() }
        customParams["fakery.business.creditCardNumber"] = { self.faker.business.creditCardNumber() }
        customParams["fakery.business.creditCardType"] = { self.faker.business.creditCardType() }
        customParams["fakery.cat.name"] = { self.faker.cat.name() }
        customParams["fakery.cat.breed"] = { self.faker.cat.breed() }
        customParams["fakery.cat.registry"] = { self.faker.cat.registry() }
        customParams["fakery.company.name"] = { self.faker.company.name() }
        customParams["fakery.company.suffix"] = { self.faker.company.suffix() }
        customParams["fakery.company.catchPhrase"] = { self.faker.company.catchPhrase() }
        customParams["fakery.company.bs"] = { self.faker.company.bs() }
        customParams["fakery.company.logo"] = { self.faker.company.logo() }
        customParams["fakery.commerce.color"] = { self.faker.commerce.color() }
        customParams["fakery.commerce.department"] = { self.faker.commerce.department() }
        customParams["fakery.commerce.productName"] = { self.faker.commerce.productName() }
        customParams["fakery.commerce.price"] = { "\(self.faker.commerce.price())" }
        customParams["fakery.gender.type"] = { self.faker.gender.type() }
        customParams["fakery.gender.binaryType"] = { self.faker.gender.binaryType() }
        customParams["fakery.lorem.word"] = { self.faker.lorem.word() }
        customParams["fakery.lorem.words"] = { self.faker.lorem.words() }
        customParams["fakery.lorem.character"] = { self.faker.lorem.character() }
        customParams["fakery.lorem.characters"] = { self.faker.lorem.characters() }
        customParams["fakery.lorem.sentence"] = { self.faker.lorem.sentence() }
        customParams["fakery.lorem.sentences"] = { self.faker.lorem.sentences() }
        customParams["fakery.lorem.paragraph"] = { self.faker.lorem.paragraph() }
        customParams["fakery.lorem.paragraphs"] = { self.faker.lorem.paragraphs() }
        customParams["fakery.name.name"] = { self.faker.name.name() }
        customParams["fakery.name.firstName"] = { self.faker.name.firstName() }
        customParams["fakery.name.lastName"] = { self.faker.name.lastName() }
        customParams["fakery.name.prefix"] = { self.faker.name.prefix() }
        customParams["fakery.name.suffix"] = { self.faker.name.suffix() }
        customParams["fakery.name.title"] = { self.faker.name.title() }
        customParams["fakery.phoneNumber.phoneNumber"] = { self.faker.phoneNumber.phoneNumber() }
        customParams["fakery.phoneNumber.cellPhone"] = { self.faker.phoneNumber.cellPhone() }
        customParams["fakery.phoneNumber.areaCode"] = { self.faker.phoneNumber.areaCode() }
        customParams["fakery.phoneNumber.exchangeCode"] = { self.faker.phoneNumber.exchangeCode() }
        customParams["fakery.phoneNumber.subscriberNumber"] = { self.faker.phoneNumber.subscriberNumber() }
        customParams["fakery.phoneNumber.numberExtension"] = { self.faker.phoneNumber.numberExtension(3) }
        customParams["fakery.internet.username"] = { self.faker.internet.username() }
        customParams["fakery.internet.domainName"] = { self.faker.internet.domainName() }
        customParams["fakery.internet.domainWord"] = { self.faker.internet.domainWord() }
        customParams["fakery.internet.domainSuffix"] = { self.faker.internet.domainSuffix() }
        customParams["fakery.internet.email"] = { self.faker.internet.email() }
        customParams["fakery.internet.freeEmail"] = { self.faker.internet.freeEmail() }
        customParams["fakery.internet.safeEmail"] = { self.faker.internet.safeEmail() }
        customParams["fakery.internet.password"] = { self.faker.internet.password() }
        customParams["fakery.internet.ipV4Address"] = { self.faker.internet.ipV4Address() }
        customParams["fakery.internet.ipV6Address"] = { self.faker.internet.ipV6Address() }
        customParams["fakery.internet.url"] = { self.faker.internet.url() }
        customParams["fakery.internet.image"] = { self.faker.internet.image() }
        customParams["fakery.internet.templateImage"] = { self.faker.internet.templateImage() }
        customParams["fakery.internet.hashtag"] = { self.faker.internet.hashtag() }
    }
}

extension Swifter.HttpRequest: CustomStringConvertible {
    public var description: String {
        return "\(method)\(path)?\(queryParams.map({"\($0.0)=\($0.1)"}).joined(separator: "&"))"
    }
}
