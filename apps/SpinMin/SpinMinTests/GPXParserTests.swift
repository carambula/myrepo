//
//  GPXParserTests.swift
//  SpinMinTests
//
//  Tests for GPX parsing: distance, elevation gain, coordinates
//

import XCTest
@testable import SpinMin

final class GPXParserTests: XCTestCase {
    
    // Points spaced 0.01 degrees of latitude apart are ~1111.9 m apart
    private let trackGPX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="test">
      <trk>
        <name>Morning Loop</name>
        <trkseg>
          <trkpt lat="45.00" lon="7.00"><ele>100.0</ele></trkpt>
          <trkpt lat="45.01" lon="7.00"><ele>130.0</ele></trkpt>
          <trkpt lat="45.02" lon="7.00"><ele>110.0</ele></trkpt>
        </trkseg>
      </trk>
    </gpx>
    """
    
    func testParsesTrackPoints() throws {
        let route = try GPXParser.parse(data: Data(trackGPX.utf8))
        XCTAssertEqual(route.points.count, 3)
        XCTAssertEqual(route.name, "Morning Loop")
    }
    
    func testDistanceCalculation() throws {
        let route = try GPXParser.parse(data: Data(trackGPX.utf8))
        // Two segments of ~1.112 km each
        XCTAssertEqual(route.distanceKm, 2.224, accuracy: 0.03)
    }
    
    func testElevationGainIgnoresDescent() throws {
        let route = try GPXParser.parse(data: Data(trackGPX.utf8))
        // +30 up, then -20 down: gain is 30
        XCTAssertEqual(route.elevationGainM, 30, accuracy: 0.1)
    }
    
    func testStartCoordinate() throws {
        let route = try GPXParser.parse(data: Data(trackGPX.utf8))
        XCTAssertEqual(route.startCoordinate?.latitude ?? 0, 45.0, accuracy: 0.0001)
        XCTAssertEqual(route.startCoordinate?.longitude ?? 0, 7.0, accuracy: 0.0001)
    }
    
    func testOpenRouteIsNotLoop() throws {
        let route = try GPXParser.parse(data: Data(trackGPX.utf8))
        XCTAssertFalse(route.isLoop)
    }
    
    func testLoopDetection() throws {
        let loopGPX = """
        <gpx version="1.1"><trk><trkseg>
          <trkpt lat="45.00" lon="7.00"></trkpt>
          <trkpt lat="45.01" lon="7.00"></trkpt>
          <trkpt lat="45.001" lon="7.00"></trkpt>
        </trkseg></trk></gpx>
        """
        let route = try GPXParser.parse(data: Data(loopGPX.utf8))
        XCTAssertTrue(route.isLoop)
    }
    
    func testRoutePointsVariant() throws {
        // GPX <rte>/<rtept> format (routes rather than recorded tracks)
        let rteGPX = """
        <gpx version="1.0"><rte><name>Planned Route</name>
          <rtept lat="45.00" lon="7.00"><ele>10</ele></rtept>
          <rtept lat="45.01" lon="7.00"><ele>20</ele></rtept>
        </rte></gpx>
        """
        let route = try GPXParser.parse(data: Data(rteGPX.utf8))
        XCTAssertEqual(route.points.count, 2)
        XCTAssertEqual(route.name, "Planned Route")
        XCTAssertEqual(route.elevationGainM, 10, accuracy: 0.1)
    }
    
    func testEmptyFileThrows() {
        let empty = "<gpx version=\"1.1\"></gpx>"
        XCTAssertThrowsError(try GPXParser.parse(data: Data(empty.utf8))) { error in
            XCTAssertTrue(error is GPXParseError)
        }
    }
    
    func testGarbageDataThrows() {
        XCTAssertThrowsError(try GPXParser.parse(data: Data("not xml at all".utf8)))
    }
    
    func testMissingElevationsProduceZeroGain() throws {
        let noEle = """
        <gpx version="1.1"><trk><trkseg>
          <trkpt lat="45.00" lon="7.00"></trkpt>
          <trkpt lat="45.01" lon="7.00"></trkpt>
        </trkseg></trk></gpx>
        """
        let route = try GPXParser.parse(data: Data(noEle.utf8))
        XCTAssertEqual(route.elevationGainM, 0)
        XCTAssertEqual(route.distanceKm, 1.112, accuracy: 0.02)
    }
}
