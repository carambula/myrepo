//
//  GPXParser.swift
//  SpinMin
//
//  Parses GPX files into route data: distance, elevation gain, and
//  start coordinates.
//

import Foundation
import CoreLocation

struct GPXRoute {
    var name: String?
    var points: [GPXPoint]
    
    /// Total distance in kilometers (haversine over consecutive points)
    var distanceKm: Double {
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for index in 1..<points.count {
            total += points[index - 1].distance(to: points[index])
        }
        return total / 1000
    }
    
    /// Total climbing in meters. Small downhill/uphill jitter below the
    /// threshold is ignored so GPS noise doesn't inflate the number.
    var elevationGainM: Double {
        let elevations = points.compactMap { $0.elevation }
        guard elevations.count > 1 else { return 0 }
        
        let threshold: Double = 2.0
        var gain: Double = 0
        var reference = elevations[0]
        
        for elevation in elevations.dropFirst() {
            let delta = elevation - reference
            if delta >= threshold {
                gain += delta
                reference = elevation
            } else if delta <= -threshold {
                reference = elevation
            }
        }
        return gain
    }
    
    var startCoordinate: (latitude: Double, longitude: Double)? {
        guard let first = points.first else { return nil }
        return (first.latitude, first.longitude)
    }
    
    /// Loop detection: start and end within 500 m of each other
    var isLoop: Bool {
        guard let first = points.first, let last = points.last, points.count > 2 else {
            return false
        }
        return first.distance(to: last) < 500
    }
}

struct GPXPoint {
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    
    func distance(to other: GPXPoint) -> Double {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
}

enum GPXParseError: LocalizedError {
    case invalidFile
    case noTrackPoints
    
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "This file could not be read as GPX."
        case .noTrackPoints: return "The GPX file contains no track or route points."
        }
    }
}

/// Parses GPX 1.0/1.1 documents. Reads both <trkpt> (tracks) and
/// <rtept> (routes) points.
final class GPXParser: NSObject, XMLParserDelegate {
    
    static func parse(data: Data) throws -> GPXRoute {
        let parser = GPXParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            throw GPXParseError.invalidFile
        }
        guard !parser.points.isEmpty else {
            throw GPXParseError.noTrackPoints
        }
        
        return GPXRoute(name: parser.routeName, points: parser.points)
    }
    
    // MARK: - Parser State
    
    private var points: [GPXPoint] = []
    private var routeName: String?
    
    private var currentLatitude: Double?
    private var currentLongitude: Double?
    private var currentElevation: Double?
    private var insidePoint = false
    private var currentElementText = ""
    private var nameDepthContext: String?
    private var elementStack: [String] = []
    
    // MARK: - XMLParserDelegate
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        elementStack.append(elementName)
        currentElementText = ""
        
        if elementName == "trkpt" || elementName == "rtept" {
            insidePoint = true
            currentLatitude = attributes["lat"].flatMap(Double.init)
            currentLongitude = attributes["lon"].flatMap(Double.init)
            currentElevation = nil
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementText += string
    }
    
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        defer { elementStack.removeLast() }
        
        switch elementName {
        case "trkpt", "rtept":
            if let lat = currentLatitude, let lon = currentLongitude {
                points.append(GPXPoint(latitude: lat, longitude: lon, elevation: currentElevation))
            }
            insidePoint = false
        case "ele" where insidePoint:
            currentElevation = Double(currentElementText.trimmingCharacters(in: .whitespacesAndNewlines))
        case "name":
            // Prefer the first name found at track/route/metadata level,
            // ignoring names inside individual points
            if !insidePoint && routeName == nil {
                let trimmed = currentElementText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    routeName = trimmed
                }
            }
        default:
            break
        }
    }
}
