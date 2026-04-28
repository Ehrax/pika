import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import OSLog

struct InvoicePDFService {
    enum Error: Swift.Error, Equatable {
        case notImplemented
        case renderingFailed
    }

    struct RenderedInvoice: Equatable {
        var data: Data
        var metadata: Metadata
    }

    struct Metadata: Equatable {
        var invoiceNumber: String
        var clientName: String
        var projectName: String
        var bucketName: String
        var templateName: String
        var currencyCode: String
        var totalLabel: String
        var lineItemCount: Int
        var pageCount: Int
        var suggestedFilename: String
    }

    static func placeholder() -> InvoicePDFService {
        InvoicePDFService()
    }

    func renderDraftPDF() throws -> Data {
        throw Error.notImplemented
    }

    func renderInvoice(
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection
    ) throws -> RenderedInvoice {
        let metadata = Metadata(
            invoiceNumber: row.number,
            clientName: row.clientName,
            projectName: row.projectName,
            bucketName: row.bucketName,
            templateName: row.template.displayName,
            currencyCode: profile.currencyCode,
            totalLabel: row.totalLabel,
            lineItemCount: row.lineItems.count,
            pageCount: InvoicePDFRenderer.pageCount(forLineItemCount: row.lineItems.count),
            suggestedFilename: Self.filename(invoiceNumber: row.number, clientName: row.clientName)
        )
        let data = try InvoicePDFRenderer(profile: profile, row: row, metadata: metadata).render()

        Self.logger.info(
            "Rendered invoice PDF \(metadata.invoiceNumber, privacy: .public) for \(metadata.clientName, privacy: .public)"
        )

        return RenderedInvoice(data: data, metadata: metadata)
    }

    private static let logger = Logger(subsystem: "dev.ehrax.pika", category: "InvoicePDFService")

    private static func filename(invoiceNumber: String, clientName: String) -> String {
        let rawName = "\(invoiceNumber)-\(clientName)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = rawName
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }

        return "\(cleaned).pdf"
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
        let cleanRecipientName = recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIBAN = iban
            .filter { !$0.isWhitespace }
            .uppercased()
        let cleanBIC = (bic ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let cleanCurrencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanRemittanceText = remittanceText.trimmingCharacters(in: .whitespacesAndNewlines)

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

private struct InvoicePDFRenderer {
    let profile: BusinessProfileProjection
    let row: WorkspaceInvoiceRowProjection
    let metadata: InvoicePDFService.Metadata

    private let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 56
    private let ciContext = CIContext()
    private static let firstPageLineItemCapacity = 5
    private static let continuationPageLineItemCapacity = 10

    static func pageCount(forLineItemCount count: Int) -> Int {
        guard count > firstPageLineItemCapacity else {
            return 1
        }

        let remaining = count - firstPageLineItemCapacity
        return 1 + Int(ceil(Double(remaining) / Double(continuationPageLineItemCapacity)))
    }

    func render() throws -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw InvoicePDFService.Error.renderingFailed
        }

        var mediaBox = page
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw InvoicePDFService.Error.renderingFailed
        }

        let pages = paginatedLineItems()
        for (index, lineItems) in pages.enumerated() {
            context.beginPDFPage(nil)
            drawPage(
                in: context,
                lineItems: lineItems,
                pageNumber: index + 1,
                pageCount: pages.count
            )
            context.endPDFPage()
        }
        context.closePDF()

        return pdfData as Data
    }

    private func drawPage(
        in context: CGContext,
        lineItems: ArraySlice<WorkspaceInvoiceLineItemProjection>,
        pageNumber: Int,
        pageCount: Int
    ) {
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(page)

        if pageNumber > 1 {
            drawContinuationPage(
                in: context,
                lineItems: lineItems,
                pageNumber: pageNumber,
                pageCount: pageCount
            )
            return
        }

        let rightX = page.width - margin - 190
        drawText(profile.businessName, in: CGRect(x: margin, y: 72, width: 260, height: 26), size: 18, weight: .bold, context: context)
        let addressBlock = profile.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = profile.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxIdentifier = profile.taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let contactBlock = [
            email,
            phone,
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let headerTopY: CGFloat = 104
        let sectionPadding: CGFloat = 18
        let headerLineHeight: CGFloat = 14
        let blockGap: CGFloat = 5
        var currentY = headerTopY

        if !addressBlock.isEmpty {
            let addressLineCount = max(1, addressBlock.split(separator: "\n", omittingEmptySubsequences: false).count)
            let addressHeight = CGFloat(addressLineCount) * headerLineHeight
            drawText(addressBlock, in: CGRect(x: margin, y: currentY, width: 260, height: addressHeight), size: 10, color: .secondary, context: context)
            currentY += addressHeight
        }

        if !contactBlock.isEmpty {
            if currentY > headerTopY {
                currentY += blockGap
            }
            let contactLineCount = max(1, contactBlock.split(separator: "\n", omittingEmptySubsequences: false).count)
            let contactHeight = CGFloat(contactLineCount) * headerLineHeight
            drawText(contactBlock, in: CGRect(x: margin, y: currentY, width: 260, height: contactHeight), size: 10, color: .secondary, context: context)
            currentY += contactHeight
        }

        if !taxIdentifier.isEmpty {
            if currentY > headerTopY {
                currentY += blockGap
            }
            let taxLabel = "Steuernummer:"
            drawText(taxLabel, in: CGRect(x: margin, y: currentY, width: 260, height: headerLineHeight), size: 10, color: .secondary, context: context)
            let taxValueX = margin + textWidth(taxLabel + " ", size: 10, weight: .regular)
            drawText(taxIdentifier, in: CGRect(x: taxValueX, y: currentY, width: max(0, 260 - (taxValueX - margin)), height: headerLineHeight), size: 10, weight: .bold, color: .secondary, context: context)
            currentY += headerLineHeight
        }

        drawText("Rechnung", in: CGRect(x: rightX, y: 72, width: 190, height: 30), size: 24, weight: .bold, alignment: .right, context: context)
        drawText(row.number, in: CGRect(x: rightX, y: 106, width: 190, height: 18), size: 11, color: .primary, alignment: .right, context: context)
        drawPageNumber(pageNumber: pageNumber, pageCount: pageCount, context: context)

        let topDividerY = currentY + sectionPadding
        drawDivider(y: topDividerY, context: context)
        let contentTopY = topDividerY + sectionPadding

        drawText("Rechnungsempfänger", in: CGRect(x: margin, y: contentTopY, width: 180, height: 14), size: 9, weight: .bold, color: .secondary, context: context)
        drawText(row.clientName, in: CGRect(x: margin, y: contentTopY + 20, width: 230, height: 22), size: 14, weight: .bold, context: context)
        drawText(row.billingAddress, in: CGRect(x: margin, y: contentTopY + 44, width: 240, height: 56), size: 10, color: .secondary, context: context)

        let issueDate = dateLabel(row.issueDate)
        let servicePeriod = row.servicePeriod.isEmpty ? issueDate : row.servicePeriod
        let dateInfoX = page.width - margin - 250
        let dateGap: CGFloat = 6
        let dateValueWidth = textWidth(issueDate, size: 10, weight: .bold)
        let dateLabelWidth = textWidth("Rechnungsdatum: ", size: 10, weight: .regular)
        let dateValueX = dateInfoX + (250 - dateValueWidth)
        let dateLabelX = dateValueX - dateGap - dateLabelWidth
        let dateInfoY = contentTopY + 44
        drawText("Rechnungsdatum:", in: CGRect(x: dateLabelX, y: dateInfoY, width: dateLabelWidth, height: 16), size: 10, color: .primary, alignment: .right, context: context)
        drawText(issueDate, in: CGRect(x: dateValueX, y: dateInfoY, width: dateValueWidth, height: 16), size: 10, weight: .bold, color: .primary, alignment: .right, context: context)

        let introY = (contentTopY + 48 + 56) + 35
        let introPrefix = "Hiermit erlaube ich mir, für den folgenden Leistungszeitraum "
        let introSuffix = "folgende Leistungen in Rechnung zu stellen:"

        drawAttributedText(
            [
                TextRun(introPrefix),
                TextRun("\(servicePeriod) ", weight: .bold),
                TextRun(introSuffix),
            ],
            in: CGRect(x: margin, y: introY, width: page.width - (margin * 2), height: 32),
            size: 10,
            color: .primary,
            context: context
        )

        let dividerY = drawLineItems(lineItems, tableY: introY + 45, context: context)
        if pageNumber == pageCount {
            drawClosingSection(startY: dividerY + 12, context: context)
        }
    }

    private func drawContinuationPage(
        in context: CGContext,
        lineItems: ArraySlice<WorkspaceInvoiceLineItemProjection>,
        pageNumber: Int,
        pageCount: Int
    ) {
        drawText(profile.businessName, in: CGRect(x: margin, y: 72, width: 260, height: 22), size: 14, weight: .bold, context: context)
        drawText(row.number, in: CGRect(x: page.width - margin - 190, y: 74, width: 190, height: 18), size: 11, color: .secondary, alignment: .right, context: context)
        drawPageNumber(pageNumber: pageNumber, pageCount: pageCount, context: context)
        drawDivider(y: 112, context: context)

        let dividerY = drawLineItems(lineItems, tableY: 146, context: context)
        if pageNumber == pageCount {
            drawClosingSection(startY: dividerY + 12, context: context)
        }
    }

    private func drawLineItems(
        _ lineItems: ArraySlice<WorkspaceInvoiceLineItemProjection>,
        tableY: CGFloat,
        context: CGContext
    ) -> CGFloat {
        let columns = tableColumns(y: tableY)
        let rowTopOffset: CGFloat = 38
        let rowHeight: CGFloat = 38

        drawText("Pos. / Bezeichnung", in: columns.description, size: 10, color: .secondary, context: context)
        drawText("Menge", in: columns.quantity, size: 10, color: .secondary, alignment: .right, context: context)
        drawText("Einheit", in: columns.unit, size: 10, color: .secondary, context: context)
        drawText("Einzelpreis", in: columns.unitPrice, size: 10, color: .secondary, alignment: .right, context: context)
        drawText("Gesamtpreis", in: columns.total, size: 10, color: .secondary, alignment: .right, context: context)
        drawDivider(y: tableY + 26, context: context)

        for (index, item) in lineItems.enumerated() {
            let y = tableY + rowTopOffset + CGFloat(index) * rowHeight
            drawText("\(index + 1)  \(item.description)", in: CGRect(x: columns.description.minX, y: y, width: columns.description.width, height: 30), size: 10, context: context)
            drawText(item.quantityValueLabel, in: CGRect(x: columns.quantity.minX, y: y, width: columns.quantity.width, height: 18), size: 10, color: .primary, alignment: .right, context: context)
            drawText(item.unitLabel, in: CGRect(x: columns.unit.minX, y: y, width: columns.unit.width, height: 30), size: 10, color: .primary, context: context)
            drawText(item.unitPriceLabel, in: CGRect(x: columns.unitPrice.minX, y: y, width: columns.unitPrice.width, height: 18), size: 10, alignment: .right, context: context)
            drawText(item.amountLabel, in: CGRect(x: columns.total.minX, y: y, width: columns.total.width, height: 18), size: 10, alignment: .right, context: context)
        }

        let rowCount = max(lineItems.count, 1)
        let dividerY = tableY + rowTopOffset + CGFloat(rowCount) * rowHeight + 4
        drawDivider(y: dividerY, context: context)

        return dividerY
    }

    private func tableColumns(y: CGFloat) -> (
        description: CGRect,
        quantity: CGRect,
        unit: CGRect,
        unitPrice: CGRect,
        total: CGRect
    ) {
        let columnGap: CGFloat = 10
        let quantityWidth: CGFloat = 40
        let unitWidth: CGFloat = 60
        let unitPriceWidth: CGFloat = 85
        let totalWidth: CGFloat = 95
        let total = CGRect(x: page.width - margin - totalWidth, y: y, width: totalWidth, height: 18)
        let unitPrice = CGRect(x: total.minX - columnGap - unitPriceWidth, y: y, width: unitPriceWidth, height: 18)
        let unit = CGRect(x: unitPrice.minX - columnGap - unitWidth, y: y, width: unitWidth, height: 18)
        let quantity = CGRect(x: unit.minX - columnGap - quantityWidth, y: y, width: quantityWidth, height: 18)
        let description = CGRect(x: margin, y: y, width: quantity.minX - columnGap - margin, height: 18)

        return (description, quantity, unit, unitPrice, total)
    }

    private func drawClosingSection(startY: CGFloat, context: CGContext) {
        let columns = tableColumns(y: startY)
        let totalLabelWidth: CGFloat = 120
        let totalLabelX = columns.total.minX - 14 - totalLabelWidth
        drawText("Gesamtsumme", in: CGRect(x: totalLabelX, y: startY, width: totalLabelWidth, height: 20), size: 11, weight: .bold, alignment: .right, context: context)
        drawText(row.totalLabel, in: CGRect(x: columns.total.minX, y: startY, width: columns.total.width, height: 20), size: 11, weight: .bold, alignment: .right, context: context)

        let taxAndPaymentNote = """
        Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.

        Der Rechnungsbetrag ist bitte innerhalb von 14 Tagen nach Rechnungseingang auf folgendes Konto zu überweisen:
        """
        drawText(
            taxAndPaymentNote,
            in: CGRect(x: margin, y: startY + 38, width: page.width - (margin * 2), height: 92),
            size: 10,
            color: .primary,
            context: context
        )

        let paymentDetails = ParsedPaymentDetails(rawValue: profile.paymentDetails)
        let ibanLabel = "IBAN:"
        let ibanValue = paymentDetails.iban ?? profile.paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let ibanY = startY + 104
        drawText(ibanLabel, in: CGRect(x: margin, y: ibanY, width: 40, height: 16), size: 10, color: .primary, context: context)
        let ibanValueX = margin + textWidth(ibanLabel + " ", size: 10, weight: .regular)
        drawText(ibanValue, in: CGRect(x: ibanValueX, y: ibanY, width: 240, height: 16), size: 10, weight: .bold, color: .primary, context: context)

        let thankYouY: CGFloat
        if let bicValue = paymentDetails.bic {
            let bicLabel = "BIC:"
            let bicY = ibanY + 18
            drawText(bicLabel, in: CGRect(x: margin, y: bicY, width: 40, height: 16), size: 10, color: .primary, context: context)
            let bicValueX = margin + textWidth(bicLabel + " ", size: 10, weight: .regular)
            drawText(bicValue, in: CGRect(x: bicValueX, y: bicY, width: 180, height: 16), size: 10, weight: .bold, color: .primary, context: context)
            thankYouY = bicY + 34
        } else {
            thankYouY = ibanY + 34
        }

        drawText(
            "Vielen Dank für die Zusammenarbeit!",
            in: CGRect(x: margin, y: thankYouY, width: page.width - (margin * 2), height: 16),
            size: 10,
            color: .primary,
            context: context
        )

        drawBottomRightPaymentQRCode(paymentDetails: paymentDetails, context: context)
    }

    private func drawBottomRightPaymentQRCode(
        paymentDetails: ParsedPaymentDetails,
        context: CGContext
    ) {
        let qrSize: CGFloat = 72
        let captionWidth: CGFloat = 112
        let captionHeight: CGFloat = 14
        let captionGap: CGFloat = 6
        let captionX = page.width - margin - captionWidth
        let qrX = captionX + ((captionWidth - qrSize) / 2)
        let qrY = page.height - margin - qrSize - captionGap - captionHeight

        _ = drawPaymentQRCode(
            paymentDetails: paymentDetails,
            topY: qrY,
            x: qrX,
            size: qrSize,
            captionX: captionX,
            captionWidth: captionWidth,
            context: context
        )
    }

    private func drawPaymentQRCode(
        paymentDetails: ParsedPaymentDetails,
        topY: CGFloat,
        x: CGFloat,
        size: CGFloat,
        captionX: CGFloat,
        captionWidth: CGFloat,
        context: CGContext
    ) -> CGFloat? {
        guard let iban = paymentDetails.iban else { return nil }

        let payload = try? PaymentQRCodePayload(
            recipientName: profile.businessName,
            iban: iban,
            bic: paymentDetails.bic,
            amountMinorUnits: row.invoice.totalMinorUnits,
            currencyCode: row.invoice.currencyCode.isEmpty ? metadata.currencyCode : row.invoice.currencyCode,
            remittanceText: "Rechnung \(row.number)"
        )
        guard let payload, let qrImage = makeQRCodeImage(text: payload.text, size: size) else {
            return nil
        }

        let qrY = topY
        let imageRect = CGRect(x: x, y: page.height - qrY - size, width: size, height: size)

        context.saveGState()
        context.interpolationQuality = .none
        context.draw(qrImage, in: imageRect)
        context.restoreGState()

        drawText(
            "Für Banking-App scannen",
            in: CGRect(x: captionX, y: qrY + size + 6, width: captionWidth, height: 14),
            size: 8,
            color: .secondary,
            alignment: .center,
            context: context
        )

        return qrY + size + 20
    }

    private func makeQRCodeImage(text: String, size: CGFloat) -> CGImage? {
        guard let data = text.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return ciContext.createCGImage(scaledImage, from: scaledImage.extent)
    }

    private func drawPageNumber(pageNumber: Int, pageCount: Int, context: CGContext) {
        guard pageCount > 1 else { return }

        drawText(
            "Seite \(pageNumber) von \(pageCount)",
            in: CGRect(x: page.width - margin - 190, y: 150, width: 190, height: 16),
            size: 9,
            color: .secondary,
            alignment: .right,
            context: context
        )
    }

    private func paginatedLineItems() -> [ArraySlice<WorkspaceInvoiceLineItemProjection>] {
        guard row.lineItems.count > Self.firstPageLineItemCapacity else {
            return [row.lineItems[...]]
        }

        var pages: [ArraySlice<WorkspaceInvoiceLineItemProjection>] = [
            row.lineItems.prefix(Self.firstPageLineItemCapacity),
        ]

        var startIndex = row.lineItems.index(row.lineItems.startIndex, offsetBy: Self.firstPageLineItemCapacity)
        while startIndex < row.lineItems.endIndex {
            let endIndex = row.lineItems.index(
                startIndex,
                offsetBy: Self.continuationPageLineItemCapacity,
                limitedBy: row.lineItems.endIndex
            ) ?? row.lineItems.endIndex
            pages.append(row.lineItems[startIndex..<endIndex])
            startIndex = endIndex
        }

        return pages
    }

    private func drawDivider(y: CGFloat, context: CGContext) {
        context.setStrokeColor(CGColor(gray: 0.86, alpha: 1))
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: page.height - y))
        context.addLine(to: CGPoint(x: page.width - margin, y: page.height - y))
        context.strokePath()
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        size: CGFloat,
        weight: FontWeight = .regular,
        color: TextColor = .primary,
        alignment: CTTextAlignment = .left,
        context: CGContext
    ) {
        var textAlignment = alignment
        let paragraph = withUnsafeBytes(of: &textAlignment) { bytes in
            var setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: bytes.baseAddress!
            )
            return CTParagraphStyleCreate(&setting, 1)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(weight.fontName as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let drawingRect = CGRect(
            x: rect.minX,
            y: page.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        let path = CGPath(rect: drawingRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributed.length), path, nil)

        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private func drawAttributedText(
        _ runs: [TextRun],
        in rect: CGRect,
        size: CGFloat,
        color: TextColor = .primary,
        alignment: CTTextAlignment = .left,
        context: CGContext
    ) {
        var textAlignment = alignment
        let paragraph = withUnsafeBytes(of: &textAlignment) { bytes in
            var setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: bytes.baseAddress!
            )
            return CTParagraphStyleCreate(&setting, 1)
        }

        let attributed = NSMutableAttributedString()
        for run in runs {
            attributed.append(
                NSAttributedString(
                    string: run.text,
                    attributes: [
                        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(run.weight.fontName as CFString, size, nil),
                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
                        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
                    ]
                )
            )
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let drawingRect = CGRect(
            x: rect.minX,
            y: page.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        let path = CGPath(rect: drawingRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributed.length), path, nil)

        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private func textWidth(_ text: String, size: CGFloat, weight: FontWeight) -> CGFloat {
        let font = CTFontCreateWithName(weight.fontName as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        return ceil(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.timeStyle = .none
        let formatted = formatter.string(from: date).trimmingCharacters(in: .whitespacesAndNewlines)
        if formatted.isEmpty {
            return date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
        }
        return formatted
    }
}

private struct ParsedPaymentDetails: Equatable {
    let iban: String?
    let bic: String?

    init(rawValue: String) {
        let words = rawValue
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .map(String.init)

        iban = Self.value(after: "IBAN", in: words).map(Self.formattedIBAN)
        bic = Self.value(after: "BIC", in: words)?.uppercased()
    }

    nonisolated private static func value(after label: String, in words: [String]) -> String? {
        guard let labelIndex = words.firstIndex(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) else {
            return nil
        }

        let valueWords = words[(labelIndex + 1)...]
            .prefix { word in
                word.caseInsensitiveCompare("IBAN") != .orderedSame
                    && word.caseInsensitiveCompare("BIC") != .orderedSame
            }
        let value = valueWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    nonisolated private static func formattedIBAN(_ value: String) -> String {
        let cleanValue = value.filter { !$0.isWhitespace }.uppercased()
        return cleanValue.enumerated().reduce(into: "") { result, pair in
            if pair.offset > 0, pair.offset.isMultiple(of: 4) {
                result.append(" ")
            }
            result.append(pair.element)
        }
    }
}

private struct TextRun {
    let text: String
    let weight: FontWeight

    init(_ text: String, weight: FontWeight = .regular) {
        self.text = text
        self.weight = weight
    }
}

private enum FontWeight {
    case regular
    case bold

    var fontName: String {
        switch self {
        case .regular:
            return "Helvetica"
        case .bold:
            return "Helvetica-Bold"
        }
    }
}

private enum TextColor {
    case primary
    case secondary

    var cgColor: CGColor {
        switch self {
        case .primary:
            return CGColor(gray: 0.08, alpha: 1)
        case .secondary:
            return CGColor(gray: 0.36, alpha: 1)
        }
    }
}
