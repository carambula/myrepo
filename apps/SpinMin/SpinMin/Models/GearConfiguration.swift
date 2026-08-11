//
//  GearConfiguration.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation
import SwiftData

@Model
final class GearConfiguration {
    var id: UUID
    var name: String
    var drivetrainType: DrivetrainType
    
    // Chainrings
    var largeChainring: Int?  // For 2x (e.g., 50t)
    var smallChainring: Int   // For 1x or 2x (e.g., 34t or 42t)
    
    // Cassette
    var cassetteTeeth: [Int]  // Array of cog sizes [11, 13, 15, 17, 19, 21, 24, 28, 32]
    
    // Wheel specs
    var wheelDiameter: WheelSize
    var tireWidthMM: Int
    
    // Optional: Link to popular drivetrain
    var popularDrivetrainID: String?
    
    var createdAt: Date
    
    init(
        name: String,
        drivetrainType: DrivetrainType,
        smallChainring: Int,
        largeChainring: Int? = nil,
        cassetteTeeth: [Int],
        wheelDiameter: WheelSize,
        tireWidthMM: Int,
        popularDrivetrainID: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.drivetrainType = drivetrainType
        self.smallChainring = smallChainring
        self.largeChainring = largeChainring
        self.cassetteTeeth = cassetteTeeth
        self.wheelDiameter = wheelDiameter
        self.tireWidthMM = tireWidthMM
        self.popularDrivetrainID = popularDrivetrainID
        self.createdAt = Date()
    }
}

enum DrivetrainType: String, Codable, CaseIterable {
    case single = "1x"
    case double = "2x"
    
    var description: String {
        switch self {
        case .single: return "1x (Single)"
        case .double: return "2x (Double)"
        }
    }
}

enum WheelSize: String, Codable, CaseIterable {
    case road700c = "700c"
    case gravel650b = "650b"
    case mtb29 = "29\""
    case mtb27_5 = "27.5\""
    case mtb26 = "26\""
    
    // BSD (Bead Seat Diameter) in mm
    var bsdMM: Double {
        switch self {
        case .road700c: return 622
        case .gravel650b: return 584
        case .mtb29: return 622
        case .mtb27_5: return 584
        case .mtb26: return 559
        }
    }
    
    var displayName: String {
        switch self {
        case .road700c: return "700c (Road)"
        case .gravel650b: return "650b (Gravel)"
        case .mtb29: return "29\" (MTB)"
        case .mtb27_5: return "27.5\" (MTB)"
        case .mtb26: return "26\" (MTB)"
        }
    }
}

// Popular drivetrains from Shimano, SRAM, Campagnolo
struct PopularDrivetrain: Identifiable, Codable, Hashable {
    let id: String
    let manufacturer: Manufacturer
    let groupsetName: String
    let year: Int
    let category: BikeCategory
    let drivetrainType: DrivetrainType
    let chainrings: [Int]  // [large, small] for 2x, or [single] for 1x
    let cassettes: [[Int]] // Common cassette options
    let speeds: Int        // 11-speed, 12-speed, etc.
    
    enum Manufacturer: String, Codable {
        case shimano = "Shimano"
        case sram = "SRAM"
        case campagnolo = "Campagnolo"
    }
    
    enum BikeCategory: String, Codable {
        case road = "Road"
        case gravel = "Gravel"
        case mtb = "Mountain"
    }
    
    var displayName: String {
        "\(manufacturer.rawValue) \(groupsetName)"
    }
    
    var chainringDescription: String {
        if drivetrainType == .double {
            return "\(chainrings[0])/\(chainrings[1])t"
        } else {
            return "\(chainrings[0])t"
        }
    }
    
    static let database: [PopularDrivetrain] = [
        // SHIMANO ROAD (2x)
        PopularDrivetrain(
            id: "shimano-dura-ace-9200-5236",
            manufacturer: .shimano,
            groupsetName: "Dura-Ace R9200",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [52, 36],
            cassettes: [
                [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30],
                [11, 12, 13, 14, 15, 17, 19, 21, 23, 25, 28]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "shimano-ultegra-8100-5236",
            manufacturer: .shimano,
            groupsetName: "Ultegra R8100",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [52, 36],
            cassettes: [
                [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30],
                [11, 12, 13, 14, 15, 17, 19, 21, 23, 25, 28]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "shimano-105-7100-5034",
            manufacturer: .shimano,
            groupsetName: "105 R7100",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [50, 34],
            cassettes: [
                [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30],
                [11, 13, 15, 17, 19, 21, 23, 25, 27, 30, 34]
            ],
            speeds: 12
        ),
        
        // SHIMANO GRAVEL (1x & 2x)
        PopularDrivetrain(
            id: "shimano-grx-820-2x",
            manufacturer: .shimano,
            groupsetName: "GRX RX820",
            year: 2024,
            category: .gravel,
            drivetrainType: .double,
            chainrings: [48, 31],
            cassettes: [
                [11, 13, 15, 17, 19, 21, 24, 27, 31, 35, 40],
                [11, 13, 15, 17, 19, 21, 24, 28, 32, 37, 42]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "shimano-grx-820-1x",
            manufacturer: .shimano,
            groupsetName: "GRX RX820 1x",
            year: 2024,
            category: .gravel,
            drivetrainType: .single,
            chainrings: [40],
            cassettes: [
                [11, 13, 15, 17, 19, 21, 24, 27, 31, 35, 40],
                [10, 12, 14, 16, 18, 21, 24, 28, 33, 39, 45]
            ],
            speeds: 12
        ),
        
        // SRAM ROAD (2x)
        PopularDrivetrain(
            id: "sram-red-etap-5237",
            manufacturer: .sram,
            groupsetName: "RED eTap AXS",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [52, 37],
            cassettes: [
                [10, 11, 12, 13, 14, 15, 17, 19, 21, 24, 28, 33]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "sram-force-etap-4835",
            manufacturer: .sram,
            groupsetName: "Force eTap AXS",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [48, 35],
            cassettes: [
                [10, 11, 12, 13, 14, 15, 17, 19, 21, 24, 28, 33]
            ],
            speeds: 12
        ),
        
        // SRAM GRAVEL (1x)
        PopularDrivetrain(
            id: "sram-red-xplr-1x",
            manufacturer: .sram,
            groupsetName: "RED XPLR",
            year: 2024,
            category: .gravel,
            drivetrainType: .single,
            chainrings: [40],
            cassettes: [
                [10, 11, 13, 15, 17, 19, 21, 24, 28, 32, 36, 44]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "sram-force-xplr-1x",
            manufacturer: .sram,
            groupsetName: "Force XPLR",
            year: 2024,
            category: .gravel,
            drivetrainType: .single,
            chainrings: [42],
            cassettes: [
                [10, 11, 13, 15, 17, 19, 21, 24, 28, 32, 36, 44]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "sram-rival-xplr-1x",
            manufacturer: .sram,
            groupsetName: "Rival XPLR",
            year: 2024,
            category: .gravel,
            drivetrainType: .single,
            chainrings: [40],
            cassettes: [
                [10, 11, 13, 15, 17, 19, 21, 24, 28, 32, 36, 44]
            ],
            speeds: 12
        ),
        
        // SRAM MTB (1x)
        PopularDrivetrain(
            id: "sram-xx-eagle-1x",
            manufacturer: .sram,
            groupsetName: "XX Eagle AXS",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [10, 12, 14, 16, 18, 21, 24, 28, 32, 36, 42, 52]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "sram-x01-eagle-1x",
            manufacturer: .sram,
            groupsetName: "X01 Eagle",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [10, 12, 14, 16, 18, 21, 24, 28, 32, 36, 42, 50]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "sram-gx-eagle-1x",
            manufacturer: .sram,
            groupsetName: "GX Eagle",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [10, 12, 14, 16, 18, 21, 24, 28, 32, 36, 42, 50]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "sram-nx-eagle-1x",
            manufacturer: .sram,
            groupsetName: "NX Eagle",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [11, 13, 15, 17, 19, 22, 25, 28, 32, 36, 42, 50]
            ],
            speeds: 12
        ),
        
        // CAMPAGNOLO ROAD (2x)
        PopularDrivetrain(
            id: "campagnolo-super-record-5239",
            manufacturer: .campagnolo,
            groupsetName: "Super Record",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [52, 39],
            cassettes: [
                [10, 11, 12, 13, 14, 15, 17, 19, 21, 23, 26, 29],
                [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34]
            ],
            speeds: 13
        ),
        PopularDrivetrain(
            id: "campagnolo-record-5239",
            manufacturer: .campagnolo,
            groupsetName: "Record",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [52, 39],
            cassettes: [
                [10, 11, 12, 13, 14, 15, 17, 19, 21, 23, 26, 29],
                [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34]
            ],
            speeds: 13
        ),
        PopularDrivetrain(
            id: "campagnolo-chorus-5236",
            manufacturer: .campagnolo,
            groupsetName: "Chorus",
            year: 2024,
            category: .road,
            drivetrainType: .double,
            chainrings: [52, 36],
            cassettes: [
                [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34]
            ],
            speeds: 13
        ),
        
        // CAMPAGNOLO GRAVEL
        PopularDrivetrain(
            id: "campagnolo-ekar-1x",
            manufacturer: .campagnolo,
            groupsetName: "Ekar",
            year: 2024,
            category: .gravel,
            drivetrainType: .single,
            chainrings: [40],
            cassettes: [
                [9, 10, 11, 13, 15, 17, 19, 22, 25, 28, 32, 36, 42]
            ],
            speeds: 13
        ),
        
        // SHIMANO MTB
        PopularDrivetrain(
            id: "shimano-xtr-m9100-1x",
            manufacturer: .shimano,
            groupsetName: "XTR M9100",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [10, 12, 14, 16, 18, 21, 24, 28, 33, 39, 45, 51]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "shimano-xt-m8100-1x",
            manufacturer: .shimano,
            groupsetName: "XT M8100",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [10, 12, 14, 16, 18, 21, 24, 28, 33, 39, 45, 51]
            ],
            speeds: 12
        ),
        PopularDrivetrain(
            id: "shimano-slx-m7100-1x",
            manufacturer: .shimano,
            groupsetName: "SLX M7100",
            year: 2024,
            category: .mtb,
            drivetrainType: .single,
            chainrings: [32],
            cassettes: [
                [10, 12, 14, 16, 18, 21, 24, 28, 33, 39, 45, 51]
            ],
            speeds: 12
        ),
    ]
}
