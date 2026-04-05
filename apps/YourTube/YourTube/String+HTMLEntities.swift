import Foundation

extension String {
    var decodedHTMLEntities: String {
        guard contains("&") else { return self }
        var output = ""
        var index = startIndex

        while index < endIndex {
            if self[index] != "&" {
                output.append(self[index])
                formIndex(after: &index)
                continue
            }

            guard let semicolon = self[index...].firstIndex(of: ";") else {
                output.append(self[index])
                formIndex(after: &index)
                continue
            }

            let entityRange = index...semicolon
            let entity = String(self[entityRange])
            if let decoded = Self.decodeEntity(entity) {
                output.append(decoded)
                index = self.index(after: semicolon)
            } else {
                output.append(self[index])
                formIndex(after: &index)
            }
        }

        return output
    }

    private static func decodeEntity(_ entity: String) -> Character? {
        guard entity.hasPrefix("&"), entity.hasSuffix(";"), entity.count >= 3 else {
            return nil
        }

        let content = entity.dropFirst().dropLast()

        if content.hasPrefix("#x") || content.hasPrefix("#X") {
            let hex = content.dropFirst(2)
            if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) {
                return Character(scalar)
            }
            return nil
        }

        if content.hasPrefix("#") {
            let dec = content.dropFirst()
            if let value = UInt32(dec, radix: 10), let scalar = UnicodeScalar(value) {
                return Character(scalar)
            }
            return nil
        }

        switch content {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return "\u{00A0}"
        default: return nil
        }
    }
}
