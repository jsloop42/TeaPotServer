//
//  Utils.swift
//  EstoServer
//
//  Created by jsloop on 24/08/19.
//

import Foundation

public class Utils {
    public static let shared = Utils()

    private init() {}

    public func getLocalTimeDateFormatter() -> ISO8601DateFormatter {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]
        df.timeZone = TimeZone.current
        return df
    }

    public func localTimeToString() -> String {
        let df = self.getLocalTimeDateFormatter()
        return df.string(from: Date())
    }

    public func localTimeToDate(_ dateString: String) -> Date? {
        let df = self.getLocalTimeDateFormatter()
        return df.date(from: dateString)
    }
}
