//
//  main.swift
//  EstoServer
//
//  Created by jsloop on 20/08/19.
//

import Logging

let log = LoggingService(level: .debug)
Log?.info("hello")

let server = HTTPServer()
server.start()
