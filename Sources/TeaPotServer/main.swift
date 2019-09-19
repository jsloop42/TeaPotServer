//
//  main.swift
//  TeaPotServer
//
//  Created by jsloop on 20/08/19.
//
import Dispatch

_ = LoggingService(level: .debug)

let server = HTTPServer()
server.start()  // This will keep running
