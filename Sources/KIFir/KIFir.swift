//
//  KIFir.swift
//  
//
//  Created by Евгений Антропов on 21.09.2022.
//

import Foundation
import KIFirServer
import ArgumentParser
import KIFirFormat

@main
struct KIFir: ParsableCommand {
    static var _commandName: String = "KIFir"
    
    @Argument(help: "Request file")
    var filePath: String?
    
    @Option(name: .shortAndLong, help: "Port")
    var port: UInt16?
    
    mutating func run() throws {
        
        let server = KIFirServer(config: .init(optionalReturning: .returnAll, port: self.port ?? 8080))
        print("Server started on port \(server.config.port)")
        if let filePath = filePath {
            let url = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let requests = try decoder.decode(RequestSequence.self, from: data)
            server.updateRoutes(sequence: requests)
        } else {
            print("You can configure requests with launch argument or send kfr file it to PUT http://127.0.0.1:\(server.config.port)/_update")
        }

        RunLoop.current.run()
    }
}
