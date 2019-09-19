//
//  Utils.swift
//  TeaPotServer
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

    public func dateToString(for date: Date? = nil, withFormat format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        df.timeZone = TimeZone.current
        return df.string(from: date ?? Date())
    }
}

public enum DateFormat: String {
    case dd_MMM_yyyy_HH_mm_ss = "dd-MMM-yyyy-HH:mm:ss"
}
