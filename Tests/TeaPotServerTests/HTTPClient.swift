//
//  HTTPClient.swift
//  TeaPotServerTests
//
//  Created by jsloop on 25/08/19.
//

import Foundation

public class HTTPClient: NSObject {
    private lazy var opsQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "\(Const.serverName) API Test Queue"
        q.qualityOfService = .default
        return q
    }()
    private lazy var configuration = { URLSessionConfiguration.default }()
    private lazy var urlSession = { URLSession(configuration: self.configuration, delegate: self, delegateQueue: self.opsQueue) }()

    /// Make a GET request to the given URL and invokes the completion handler when done.
    public func get(_ url: URL, completion: @escaping (Data?) -> Void) {
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "GET"
        let task = self.urlSession.dataTask(with: urlReq) { data, response, error in
            if let aData = data { completion(aData) } else { completion(nil) }
        }
        task.resume()
    }

    /// Make a POST request with the given data as the body, with the headers and invokes the completion handler when done.
    public func post(_ url: URL, data: Data?, headers: [String: String]?, completion: @escaping (Data?) -> Void) {
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "POST"
        urlReq.httpBody = data
        if let someHeaders = headers {
            someHeaders.forEach { kv in
                let (key, value) = kv
                urlReq.addValue(value, forHTTPHeaderField: key)
            }
        }
        let task = self.urlSession.dataTask(with: urlReq) { data, response, error in
            if let aData = data { completion(aData) } else { completion(nil) }
        }
        task.resume()
    }
}

extension HTTPClient: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        /// Ignore self-signed SSL certificate validation
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
