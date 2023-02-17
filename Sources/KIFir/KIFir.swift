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
import Swifter

@main
struct KIFir: ParsableCommand {
    static var _commandName: String = "KIFir"
    
    @Argument(help: "Request file")
    var filePath: String?
    
    @Option(name: .shortAndLong, help: "Port")
    var port: UInt16?
    
    @Option(name: .shortAndLong, help: "Port")
    var configPort: UInt16 = 18181
    
    @Flag(name: .long, help: "Enable remote command execution (Dangerous!!!!)")
    var remoteCommandExecution: Bool = false
    
    mutating func run() throws {
        let configServer = HttpServer()
        configServer.listenAddressIPv4 = "localhost"
        var serversList = [UInt16: KIFirServer]()
        
        if let filePath = filePath {
            let server = KIFirServer(config: .init(optionalReturning: .returnAll, port: self.port ?? 8080))
            serversList[server.config.port] = server
            print("Server started on port \(server.config.port)")
            let url = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let requests = try decoder.decode(RequestSequence.self, from: data)
            server.updateRoutes(sequence: requests)
        } else {
            do {
                try configServer.start(configPort, forceIPv4: true)
                configServer.PUT["/:port"] = { request in
                    guard let port = UInt16(request.params[":port"] ?? "") else { return.badRequest(.none)}
                    if let server = serversList[port] {
                        server.stopServer()
                        serversList[port] = nil
                    }
                    print("Server started on \(port)")
                    let server = KIFirServer(config: .init(optionalReturning: .returnAll, port: port))
                    serversList[port] = server
                    return .accepted
                }
                configServer.POST["/:port"] = { request in
                    guard let port = UInt16(request.params[":port"] ?? "") else { return.badRequest(.text("Unknown port"))}
                    guard let server = serversList[port] else { return.badRequest(.text("Server not started"))}
                    guard !request.body.isEmpty else { return .badRequest(.text("Request body is empty"))}
                    print("Server updated on \(port)")
                    let data = Data(request.body)
                    let decoder = JSONDecoder()
                    do {
                        let object = try decoder.decode(RequestSequence.self, from: data)
                        print("Did updated routes from HTTP")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            server.updateRoutes(sequence: object)
                        }
                        return .created
                    } catch {
                        return .badRequest(.text(error.localizedDescription))
                    }
                }
                configServer.DELETE["/:port"] = { request in
                    guard let port = UInt16(request.params[":port"] ?? "") else { return.badRequest(.text("Unknown port"))}
                    guard let server = serversList[port] else { return.badRequest(.text("Server not started"))}
                    server.stopServer()
                    serversList.removeValue(forKey: port)
                    print("Server stoped on \(port)")
                    return .accepted
                }
                if remoteCommandExecution {
                    configServer.PATCH["/run"] = { request in
                        guard let command = String(data: Data(request.body), encoding: .utf8) else { return.badRequest(.text("Unknown command"))}
                        print("REMOTE EXECUTION: \(command)")
                        let homeDirURL = URL(fileURLWithPath: NSHomeDirectory())
                        let task = Process()
                        let pipe = Pipe()
                        task.standardOutput = pipe
                        task.standardError = pipe
                        task.standardInput = FileHandle.standardInput
                        task.arguments = ["--login", "-c", "export HOME=\(homeDirURL.path) && export LANG=en_US.UTF-8 && " + command]
                        task.launchPath = "/bin/zsh"
                        task.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                        var result = ""
                        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: pipe.fileHandleForReading , queue: nil) { notification in
                            let output = pipe.fileHandleForReading.availableData
                            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
                            Swift.print(outputString, terminator: "")
                            result += outputString
                            pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
                        }
                        
                        pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
                        task.launch()
                        task.waitUntilExit()
                        return .ok(.text(result))
                    }
                }

                print("""
You can configure requests with launch argument
or config server via http requests from http://localhost:\(configPort)
POST /:port - Run mock server on port
PUT /:port - Update mock requests via rqst file on selected port
DELETE /:port - Stop mock server on port
""")
                if remoteCommandExecution {
                    print("""
PATCH /run - Remotly execute shell script
""")
                }
            }
            catch Swifter.SocketError.bindFailed(let string) {
                fatalError(string)
            }
            catch {
                fatalError(error.localizedDescription)
            }
        }

        RunLoop.current.run()
    }
}
