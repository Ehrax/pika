import Foundation
import CoreGraphics
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

private struct InvoicePDFRenderer {
    let profile: BusinessProfileProjection
    let row: WorkspaceInvoiceRowProjection
    let metadata: InvoicePDFService.Metadata

    private let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 56
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
        drawText("\(profile.address)\n\(profile.email)", in: CGRect(x: margin, y: 104, width: 260, height: 46), size: 10, color: .secondary, context: context)

        drawText("Invoice", in: CGRect(x: rightX, y: 72, width: 190, height: 30), size: 24, weight: .bold, alignment: .right, context: context)
        drawText(row.number, in: CGRect(x: rightX, y: 106, width: 190, height: 18), size: 11, color: .secondary, alignment: .right, context: context)
        drawText("Currency \(metadata.currencyCode)", in: CGRect(x: rightX, y: 128, width: 190, height: 18), size: 10, color: .secondary, alignment: .right, context: context)
        drawPageNumber(pageNumber: pageNumber, pageCount: pageCount, context: context)

        drawDivider(y: 176, context: context)

        drawText("Bill to", in: CGRect(x: margin, y: 210, width: 180, height: 16), size: 10, weight: .bold, color: .secondary, context: context)
        drawText(row.clientName, in: CGRect(x: margin, y: 232, width: 230, height: 22), size: 14, weight: .bold, context: context)
        drawText(row.billingAddress, in: CGRect(x: margin, y: 258, width: 240, height: 56), size: 10, color: .secondary, context: context)

        drawText("Project", in: CGRect(x: margin, y: 318, width: 80, height: 16), size: 10, weight: .bold, color: .secondary, context: context)
        drawText(row.projectName, in: CGRect(x: margin + 82, y: 318, width: 200, height: 16), size: 10, context: context)
        drawText("Bucket", in: CGRect(x: margin, y: 340, width: 80, height: 16), size: 10, weight: .bold, color: .secondary, context: context)
        drawText(row.bucketName, in: CGRect(x: margin + 82, y: 340, width: 200, height: 16), size: 10, context: context)

        let dates = [
            ("Issue date", dateLabel(row.issueDate)),
            ("Due date", dateLabel(row.dueDate)),
            ("Status", row.statusTitle),
        ]
        for (index, pair) in dates.enumerated() {
            let y = 210 + CGFloat(index * 34)
            drawText(pair.0, in: CGRect(x: rightX, y: y, width: 90, height: 16), size: 10, weight: .bold, color: .secondary, context: context)
            drawText(pair.1, in: CGRect(x: rightX + 95, y: y, width: 95, height: 16), size: 10, alignment: .right, context: context)
        }

        let dividerY = drawLineItems(lineItems, tableY: 390, context: context)
        if pageNumber == pageCount {
            drawClosingSection(startY: dividerY + 24, context: context)
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
            drawClosingSection(startY: dividerY + 24, context: context)
        }
    }

    private func drawLineItems(
        _ lineItems: ArraySlice<WorkspaceInvoiceLineItemProjection>,
        tableY: CGFloat,
        context: CGContext
    ) -> CGFloat {
        drawText("Description", in: CGRect(x: margin, y: tableY, width: 270, height: 18), size: 10, weight: .bold, color: .secondary, context: context)
        drawText("Qty", in: CGRect(x: page.width - margin - 220, y: tableY, width: 70, height: 18), size: 10, weight: .bold, color: .secondary, alignment: .right, context: context)
        drawText("Amount", in: CGRect(x: page.width - margin - 120, y: tableY, width: 120, height: 18), size: 10, weight: .bold, color: .secondary, alignment: .right, context: context)
        drawDivider(y: tableY + 26, context: context)

        for (index, item) in lineItems.enumerated() {
            let y = tableY + 48 + CGFloat(index * 34)
            drawText(item.description, in: CGRect(x: margin, y: y, width: 300, height: 18), size: 12, context: context)
            drawText(item.quantityLabel, in: CGRect(x: page.width - margin - 220, y: y, width: 70, height: 18), size: 10, color: .secondary, alignment: .right, context: context)
            drawText(item.amountLabel, in: CGRect(x: page.width - margin - 120, y: y, width: 120, height: 18), size: 12, alignment: .right, context: context)
        }

        let dividerY = tableY + 58 + CGFloat(max(lineItems.count, 1) * 34)
        drawDivider(y: dividerY, context: context)

        return dividerY
    }

    private func drawClosingSection(startY: CGFloat, context: CGContext) {
        let totalsX = page.width - margin - 220
        drawText("Payment details", in: CGRect(x: margin, y: startY, width: 200, height: 18), size: 10, weight: .bold, color: .secondary, context: context)
        drawText(profile.paymentDetails, in: CGRect(x: margin, y: startY + 22, width: 250, height: 44), size: 10, context: context)

        drawText("Subtotal", in: CGRect(x: totalsX, y: startY, width: 100, height: 18), size: 11, color: .secondary, context: context)
        drawText(row.totalLabel, in: CGRect(x: totalsX + 100, y: startY, width: 120, height: 18), size: 11, alignment: .right, context: context)
        drawText("Total", in: CGRect(x: totalsX, y: startY + 30, width: 100, height: 24), size: 16, weight: .bold, context: context)
        drawText(row.totalLabel, in: CGRect(x: totalsX + 100, y: startY + 30, width: 120, height: 24), size: 16, weight: .bold, alignment: .right, context: context)

        drawText("Tax note", in: CGRect(x: margin, y: startY + 86, width: 200, height: 18), size: 10, weight: .bold, color: .secondary, context: context)
        drawText(profile.taxNote, in: CGRect(x: margin, y: startY + 108, width: 250, height: 44), size: 10, context: context)

        drawText(
            "Thank you for your business.",
            in: CGRect(x: page.width - margin - 220, y: startY + 86, width: 220, height: 18),
            size: 10,
            color: .secondary,
            alignment: .right,
            context: context
        )
    }

    private func drawPageNumber(pageNumber: Int, pageCount: Int, context: CGContext) {
        guard pageCount > 1 else { return }

        drawText(
            "Page \(pageNumber) of \(pageCount)",
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

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
