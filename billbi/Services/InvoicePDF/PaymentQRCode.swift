import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ParsedPaymentDetails: Equatable {
    var iban: String
    var formattedIBAN: String
    var bic: String

    init(rawValue: String) {
        let lines = rawValue
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var parsedIBAN = ""
        var parsedBIC = ""

        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("iban") {
                parsedIBAN = Self.value(afterLabelIn: line)
            } else if lowercased.hasPrefix("bic") {
                parsedBIC = Self.value(afterLabelIn: line)
            } else if parsedIBAN.isEmpty, line.filter({ !$0.isWhitespace }).count >= 15 {
                parsedIBAN = line
            }
        }

        iban = parsedIBAN.filter { !$0.isWhitespace }.uppercased()
        formattedIBAN = Self.groupedIBAN(iban)
        bic = parsedBIC.uppercased()
    }

    private static func value(afterLabelIn line: String) -> String {
        let separators = CharacterSet(charactersIn: ": ")
        return line
            .drop { !$0.unicodeScalars.contains { separators.contains($0) } }
            .trimmingCharacters(in: separators)
    }

    private static func groupedIBAN(_ value: String) -> String {
        value.enumerated().reduce(into: "") { result, element in
            if element.offset > 0, element.offset.isMultiple(of: 4) {
                result.append(" ")
            }
            result.append(element.element)
        }
    }
}

struct PaymentQRCodeRenderer {
    private let context = CIContext(options: nil)

    func dataURL(for text: String) -> String? {
        guard let payloadData = text.data(using: .utf8) else {
            return nil
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = payloadData
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scale: CGFloat = 8
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent),
              let pngData = Self.pngData(from: cgImage) else {
            return nil
        }

        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}

struct PaymentQRCodePayload: Equatable {
    enum Error: Swift.Error, Equatable {
        case missingRecipientName
        case missingIBAN
        case missingCurrencyCode
        case invalidAmount
    }

    let text: String

    init(
        recipientName: String,
        iban: String,
        bic: String?,
        amountMinorUnits: Int,
        currencyCode: String,
        remittanceText: String
    ) throws {
        let cleanRecipientName = recipientName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let cleanIBAN = iban
            .filter { !$0.isWhitespace }
            .uppercased()
        let cleanBIC = (bic ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let cleanCurrencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanRemittanceText = remittanceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleanRecipientName.isEmpty else { throw Error.missingRecipientName }
        guard !cleanIBAN.isEmpty else { throw Error.missingIBAN }
        guard !cleanCurrencyCode.isEmpty else { throw Error.missingCurrencyCode }
        guard amountMinorUnits > 0 else { throw Error.invalidAmount }

        text = [
            "BCD",
            "002",
            "1",
            "SCT",
            cleanBIC,
            cleanRecipientName,
            cleanIBAN,
            Self.amountLabel(amountMinorUnits: amountMinorUnits, currencyCode: cleanCurrencyCode),
            "",
            "",
            cleanRemittanceText,
        ].joined(separator: "\n")
    }

    nonisolated private static func amountLabel(amountMinorUnits: Int, currencyCode: String) -> String {
        let majorUnits = amountMinorUnits / 100
        let cents = amountMinorUnits % 100
        return "\(currencyCode)\(majorUnits).\(String(format: "%02d", cents))"
    }
}
