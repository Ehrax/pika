import Foundation
import Testing
@testable import billbi
#if os(macOS)
import WebKit
#endif

struct InvoicePDFServiceTests {
    @Test func paymentQRCodePayloadBuildsEPCSepaTransferText() throws {
        let payload = try PaymentQRCodePayload(
            recipientName: "Ehrax Studio",
            iban: "DE32 1001 1001 2141 1444 52",
            bic: "NTSBDEB1XXX",
            amountMinorUnits: 120_000,
            currencyCode: "EUR",
            remittanceText: "Rechnung EHX-2026-004"
        )

        #expect(payload.text == """
        BCD
        002
        1
        SCT
        NTSBDEB1XXX
        EHRAX STUDIO
        DE32100110012141144452
        EUR1200.00


        RECHNUNG EHX-2026-004
        """)
    }

    @Test func renderInvoiceHTMLUsesSnapshotDataAndEscapesTemplateValues() throws {
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let invoice = WorkspaceInvoice(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000088")!,
            number: "EHX-2026-088",
            businessSnapshot: BusinessProfileProjection(
                businessName: "Snapshot Studio <GmbH>",
                personName: "Ada & Grace",
                email: "billing@example.test",
                address: "Snapshot Street 4\n10115 Berlin",
                taxIdentifier: "16/123/45678",
                economicIdentifier: "DE-WID-42",
                invoicePrefix: "EHX",
                nextInvoiceNumber: 89,
                currencyCode: "EUR",
                paymentDetails: "IBAN DE32 1001 1001 2141 1444 52",
                taxNote: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
                defaultTermsDays: 14
            ),
            clientSnapshot: WorkspaceClient(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000088")!,
                name: "Client & Co <Berlin>",
                email: "casey@example.test",
                billingAddress: "Client Road 9\n10999 Berlin",
                defaultTermsDays: 14
            ),
            clientName: "Mutable Client Name",
            projectName: "Website <Refresh>",
            bucketName: "Launch & QA",
            issueDate: Date.billbiDate(year: 2026, month: 5, day: 1),
            dueDate: Date.billbiDate(year: 2026, month: 5, day: 15),
            servicePeriod: "April 2026",
            status: .finalized,
            totalMinorUnits: 120_000,
            lineItems: [
                WorkspaceInvoiceLineItemSnapshot(
                    description: "Design & implementation <phase>",
                    quantityLabel: "12h",
                    amountMinorUnits: 120_000
                ),
            ],
            note: "Thank you & see <you> soon."
        )
        let row = WorkspaceInvoiceRowProjection(
            invoice: invoice,
            projectName: "Mutable Project",
            billingAddress: "Mutable Address",
            on: WorkspaceFixtures.today,
            formatter: formatter
        )

        let rendered = try InvoicePDFService.placeholder().renderInvoiceHTML(
            profile: WorkspaceFixtures.demoWorkspace.businessProfile,
            row: row
        )

        #expect(rendered.metadata.invoiceNumber == "EHX-2026-088")
        #expect(rendered.metadata.clientName == "Client & Co <Berlin>")
        #expect(rendered.metadata.templateName == "Kleinunternehmer Classic")
        #expect(rendered.metadata.currencyCode == "EUR")
        #expect(rendered.metadata.lineItemCount == 1)
        #expect(rendered.metadata.pageCount == 1)
        #expect(rendered.metadata.suggestedFilename == "EHX-2026-088-Client---Co--Berlin-.pdf")
        #expect(rendered.templateFolderName == "kleinunternehmer-classic")
        #expect(rendered.resourceBaseURL != nil)
        #expect(rendered.html.contains("Snapshot Studio &lt;GmbH&gt;"))
        #expect(rendered.html.contains("Client &amp; Co &lt;Berlin&gt;"))
        #expect(rendered.html.contains("Design &amp; implementation &lt;phase&gt;"))
        #expect(rendered.html.contains("Thank you &amp; see &lt;you&gt; soon."))
        #expect(rendered.html.contains("IBAN: <strong>DE32 1001 1001 2141 1444 52</strong>"))
        #expect(rendered.html.contains("Rechnungsempfänger"))
        #expect(rendered.html.contains("Pos. / Bezeichnung"))
        #expect(rendered.html.contains("Gesamtsumme"))
        #expect(rendered.html.contains("Für Banking-App scannen"))
        #expect(rendered.html.contains("data:image/png;base64,"))
        #expect(rendered.html.contains(#"<link rel="stylesheet" href="style.css">"#))
        #expect(rendered.html.contains(#"<table class="line-items">"#))
        #expect(!rendered.html.contains("{{>"))
        #expect(!rendered.html.contains("{{"))
        #expect(!rendered.html.contains("<script"))
    }

    @Test func invoiceTemplateResourceLookupFindsBundledDocumentStylesheetAndPartials() throws {
        let resources = try InvoiceTemplateResources(template: .kleinunternehmerClassic)

        #expect(resources.folderName == "kleinunternehmer-classic")
        #expect(resources.document.contains("{{invoiceNumber}}"))
        #expect(resources.stylesheet.contains("@page"))
        #expect(resources.stylesheet.contains("--invoice-ink"))
        #expect(resources.partials.keys.contains("line-items"))
        #expect(resources.partials.keys.contains("payment-details"))
        #expect(resources.partials.keys.contains("legal-notes"))
        #expect(resources.baseURL != nil)
        #expect(resources.document.contains(#"<link rel="stylesheet" href="style.css">"#))
    }

    #if os(macOS)
    @MainActor
    @Test func invoiceHTMLPreviewStateOnlyEnablesExportForLoadedSelectedDocument() {
        let state = InvoiceHTMLPreviewState()
        let firstInvoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000101")!
        let secondInvoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000102")!

        state.prepareToLoad(invoiceID: firstInvoiceID)

        #expect(!state.canExportSelectedDocument)
        #expect(state.requestedInvoiceID == firstInvoiceID)
        #expect(state.loadedInvoiceID == nil)
        #expect(state.isLoading)

        state.didFinishLoading(invoiceID: firstInvoiceID)

        #expect(state.canExportSelectedDocument)
        #expect(state.loadedInvoiceID == firstInvoiceID)
        #expect(!state.isLoading)

        state.prepareToLoad(invoiceID: secondInvoiceID)

        #expect(!state.canExportSelectedDocument)
        #expect(state.requestedInvoiceID == secondInvoiceID)
        #expect(state.loadedInvoiceID == nil)
        #expect(state.isLoading)

        state.didFinishLoading(invoiceID: firstInvoiceID)

        #expect(!state.canExportSelectedDocument)
        #expect(state.loadedInvoiceID == nil)
        #expect(state.isLoading)

        state.didFinishLoading(invoiceID: secondInvoiceID)

        #expect(state.canExportSelectedDocument)
        #expect(state.loadedInvoiceID == secondInvoiceID)
        #expect(!state.isLoading)

        state.prepareToLoad(invoiceID: secondInvoiceID)

        #expect(state.canExportSelectedDocument)
        #expect(state.loadedInvoiceID == secondInvoiceID)
        #expect(!state.isLoading)
    }

    @MainActor
    @Test func invoiceHTMLPreviewStateExportsLoadedWebKitDocumentAsPDFData() async throws {
        let state = InvoiceHTMLPreviewState()
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000103")!
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842))
        let loader = WebViewLoadProbe()
        webView.navigationDelegate = loader

        state.attach(webView: webView)
        state.prepareToLoad(invoiceID: invoiceID)
        webView.loadHTMLString(
            """
            <!doctype html>
            <html><head><meta charset="utf-8"><style>@page { size: A4; }</style></head>
            <body><main><h1>Invoice Smoke</h1><p>Rendered from WebKit.</p></main></body></html>
            """,
            baseURL: nil
        )
        try await loader.waitForLoad()
        state.didFinishLoading(invoiceID: invoiceID)

        let data = try await state.pdfDataForSelectedDocument()

        #expect(data.count > 1_000)
        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
    }
    #endif

}

#if os(macOS)
@MainActor
private final class WebViewLoadProbe: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func waitForLoad() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
#endif
