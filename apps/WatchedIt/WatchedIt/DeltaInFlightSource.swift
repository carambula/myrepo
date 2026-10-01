//
//  DeltaInFlightSource.swift
//  WatchedIt
//

import Foundation

public enum DeltaInFlightSource {
    public static let identifier = "delta-in-flight"
    public static let displayName = "Delta in-flight"
    public static let catalogURL = "https://www.delta.com/us/en/onboard/inflight-entertainment/current-movies"

    public static func isDeltaInFlightName(_ name: String) -> Bool {
        let key = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return key == "delta in flight"
            || key == "delta inflight"
            || key == "delta studio"
    }
}
