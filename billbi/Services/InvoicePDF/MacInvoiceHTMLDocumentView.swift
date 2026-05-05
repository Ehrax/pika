import SwiftUI

#if os(macOS)
import Combine
import WebKit

@MainActor
final class InvoiceHTMLPreviewState: ObservableObject {
    @Published private(set) var requestedInvoiceID: WorkspaceInvoice.ID?
    @Published private(set) var loadedInvoiceID: WorkspaceInvoice.ID?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?

    fileprivate weak var webView: WKWebView?

    var canExportSelectedDocument: Bool {
        requestedInvoiceID != nil && requestedInvoiceID == loadedInvoiceID && !isLoading
    }

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func prepareToLoad(invoiceID: WorkspaceInvoice.ID, force: Bool = false) {
        guard force || requestedInvoiceID != invoiceID else { return }
        requestedInvoiceID = invoiceID
        loadedInvoiceID = nil
        isLoading = true
        lastError = nil
    }

    func didFinishLoading(invoiceID: WorkspaceInvoice.ID) {
        guard requestedInvoiceID == invoiceID else { return }
        loadedInvoiceID = invoiceID
        isLoading = false
        lastError = nil
    }

    func didFailLoading(invoiceID: WorkspaceInvoice.ID, error: Error) {
        guard requestedInvoiceID == invoiceID else { return }
        loadedInvoiceID = nil
        isLoading = false
        lastError = error
    }

    func pdfDataForSelectedDocument() async throws -> Data {
        guard canExportSelectedDocument, let webView else {
            throw InvoicePDFService.Error.renderingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let configuration = WKPDFConfiguration()
            webView.createPDF(configuration: configuration) { result in
                continuation.resume(with: result)
            }
        }
    }
}

struct MacInvoiceHTMLDocumentView: NSViewRepresentable {
    let rendered: InvoicePDFService.RenderedInvoiceHTML
    let invoiceID: WorkspaceInvoice.ID
    @ObservedObject var state: InvoiceHTMLPreviewState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        state.attach(webView: view)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.invoiceID = invoiceID
        state.attach(webView: view)
        guard context.coordinator.shouldLoad(rendered: rendered, invoiceID: invoiceID) else { return }
        state.prepareToLoad(invoiceID: invoiceID, force: true)
        view.loadHTMLString(rendered.html, baseURL: rendered.resourceBaseURL ?? Bundle.main.resourceURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var state: InvoiceHTMLPreviewState?
        var invoiceID: WorkspaceInvoice.ID?
        private var lastLoadedInvoiceID: WorkspaceInvoice.ID?
        private var lastLoadedHTML: String?

        init(state: InvoiceHTMLPreviewState) {
            self.state = state
        }

        func shouldLoad(rendered: InvoicePDFService.RenderedInvoiceHTML, invoiceID: WorkspaceInvoice.ID) -> Bool {
            defer {
                lastLoadedInvoiceID = invoiceID
                lastLoadedHTML = rendered.html
            }

            return lastLoadedInvoiceID != invoiceID || lastLoadedHTML != rendered.html
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let invoiceID else { return }
            state?.didFinishLoading(invoiceID: invoiceID)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard let invoiceID else { return }
            state?.didFailLoading(invoiceID: invoiceID, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard let invoiceID else { return }
            state?.didFailLoading(invoiceID: invoiceID, error: error)
        }
    }
}
#endif
