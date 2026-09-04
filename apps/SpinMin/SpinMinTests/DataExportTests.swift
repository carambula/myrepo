//
//  DataExportTests.swift
//  SpinMinTests
//
//  Tests for CSV/JSON export serialization
//

import XCTest
@testable import SpinMin

final class DataExportTests: XCTestCase {
    
    private func sampleRows() -> [DataExportService.ExportRow] {
        [
            DataExportService.ExportRow(fields: [
                ("date", "2026-08-01"),
                ("name", "Morning Ride"),
                ("distance_km", "42.50"),
            ]),
            DataExportService.ExportRow(fields: [
                ("date", "2026-08-02"),
                ("name", "Hills, sweat and \"fun\""),
                ("distance_km", "80.00"),
            ]),
        ]
    }
    
    func testCSVHeaderAndRowCount() {
        let csv = DataExportService.toCSV(sampleRows())
        let lines = csv.components(separatedBy: "\n")
        
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "date,name,distance_km")
        XCTAssertEqual(lines[1], "2026-08-01,Morning Ride,42.50")
    }
    
    func testCSVEscapesCommasAndQuotes() {
        let csv = DataExportService.toCSV(sampleRows())
        let lines = csv.components(separatedBy: "\n")
        
        // RFC 4180: embedded quotes doubled, field wrapped in quotes
        XCTAssertTrue(lines[2].contains("\"Hills, sweat and \"\"fun\"\"\""))
    }
    
    func testCSVEscapeHelper() {
        XCTAssertEqual(DataExportService.csvEscape("plain"), "plain")
        XCTAssertEqual(DataExportService.csvEscape("a,b"), "\"a,b\"")
        XCTAssertEqual(DataExportService.csvEscape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(DataExportService.csvEscape("line\nbreak"), "\"line\nbreak\"")
    }
    
    func testEmptyRowsProduceEmptyCSV() {
        XCTAssertEqual(DataExportService.toCSV([]), "")
    }
    
    func testJSONRoundTrips() throws {
        let json = DataExportService.toJSON(sampleRows())
        let data = Data(json.utf8)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: String]]
        
        XCTAssertEqual(decoded?.count, 2)
        XCTAssertEqual(decoded?[0]["name"], "Morning Ride")
        XCTAssertEqual(decoded?[1]["distance_km"], "80.00")
    }
}
