//
//  main.swift
//  EstoServer
//
//  Created by jsloop on 20/08/19.
//

_ = LoggingService(level: .debug)
Log?.debug("hello")

let server = HTTPServer()
server.start()
