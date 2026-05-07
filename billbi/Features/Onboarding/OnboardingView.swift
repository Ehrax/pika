import SwiftUI

struct OnboardingView: View {
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    let onComplete: (OnboardingPrimaryCTA) -> Void

    @State private var flow = OnboardingFlowModel()
    @State private var businessDraft: OnboardingBusinessDraft
    @State private var clientDraft: OnboardingClientDraft
    @State private var projectDraft: OnboardingProjectDraft
    @State private var savedClientID: WorkspaceClient.ID?
    @State private var errorMessage: String?
#if os(macOS)
    @StateObject private var welcomeInvoicePreviewState = InvoiceHTMLPreviewState()
#endif

    init(
        workspaceStore: WorkspaceStore,
        currentDate: Date = .now,
        onComplete: @escaping (OnboardingPrimaryCTA) -> Void
    ) {
        self.workspaceStore = workspaceStore
        self.currentDate = currentDate
        self.onComplete = onComplete

        let workspace = workspaceStore.workspace
        let firstClient = workspace.clients.first
        let firstProject = workspace.activeProjects.first
        _businessDraft = State(initialValue: OnboardingBusinessDraft(profile: workspace.businessProfile))
        _clientDraft = State(initialValue: OnboardingClientDraft(
            name: firstClient?.name ?? "",
            email: firstClient?.email ?? "",
            billingAddress: firstClient?.billingAddress ?? ""
        ))
        _projectDraft = State(initialValue: OnboardingProjectDraft(
            name: firstProject?.name ?? "",
            clientID: firstProject?.clientID ?? firstClient?.id,
            currencyCode: firstProject?.currencyCode ?? workspace.businessProfile.currencyCode,
            firstBucketName: firstProject?.buckets.first?.name ?? "",
            hourlyRateMinorUnits: firstProject?.buckets.first?.hourlyRateMinorUnits ?? 8_000
        ))
        _savedClientID = State(initialValue: firstProject?.clientID ?? firstClient?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch flow.step {
                case .welcome:
                    welcomeStep
                case .business:
                    businessStep
                case .client:
                    clientStep
                case .project:
                    projectStep
                case .ready:
                    readyStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if flow.step != .welcome && flow.step != .ready {
                footer
            }
        }
        .background(BillbiColor.background)
        .accessibilityIdentifier("Billbi Onboarding")
    }

    private var header: some View {
        HStack {
            HStack(spacing: BillbiSpacing.sm) {
                RoundedRectangle(cornerRadius: BillbiRadius.lg)
                    .fill(BillbiColor.brand)
                    .frame(width: 28, height: 28)
                    .overlay(Text("B").font(BillbiTypography.subheading.weight(.bold)).foregroundStyle(.white))
                Text("Billbi")
                    .font(BillbiTypography.heading)
                    .foregroundStyle(BillbiColor.textPrimary)
            }

            Spacer()

            HStack(spacing: BillbiSpacing.xs) {
                Text(String(format: "%02d / 05", flow.step.displayIndex))
                    .font(BillbiTypography.small.monospacedDigit())
                    .foregroundStyle(BillbiColor.textSecondary)
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step == flow.step ? BillbiColor.brand : BillbiColor.surfaceAlt2)
                        .frame(width: step == flow.step ? 26 : 7, height: 7)
                }
            }

            Spacer()

            Button {
                skip()
            } label: {
                Label("Skip setup", systemImage: "forward.end")
            }
            .buttonStyle(.billbiAction(.neutral))
            .accessibilityIdentifier("Skip setup")
        }
        .padding(.horizontal, BillbiSpacing.xl)
        .padding(.vertical, BillbiSpacing.md)
        .background(BillbiColor.surface)
    }

    private var welcomeStep: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                Text("Welcome to Billbi")
                    .font(BillbiTypography.subheading)
                    .foregroundStyle(BillbiColor.brand)
                Text("Start with the parts every invoice needs.")
                    .font(BillbiTypography.display)
                    .foregroundStyle(BillbiColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Add your business, one client, and a starter project. Billbi keeps the setup light, and you can fill the rest in later.")
                    .font(BillbiTypography.body)
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineSpacing(3)

                VStack(spacing: BillbiSpacing.sm) {
                    setupRow("01", title: "Business basics", detail: "name, currency, default rate")
                    setupRow("02", title: "First client", detail: "a real client, with details optional")
                    setupRow("03", title: "Starter project", detail: "one bucket so work has a place")
                }

                HStack(spacing: BillbiSpacing.md) {
                    Button {
                        continueTapped()
                    } label: {
                        Label("Start setup", systemImage: "arrow.right")
                    }
                    .buttonStyle(.billbiAction(.primary))
                    .accessibilityIdentifier("Continue")

                    Text("About five minutes. Skip any detail you do not have yet.")
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                }
                Spacer()
            }
            .padding(BillbiSpacing.xl)
            .frame(minWidth: 520)

            onboardingPreviewPanel(
                eyebrow: "PREVIEW",
                title: "A workspace for time, projects, and invoices"
            ) {
                welcomeInvoicePreview
            }
        }
    }

    private var businessStep: some View {
        splitStep(
            eyebrow: "STEP 02 · BUSINESS",
            title: "Set your business identity",
            subtitle: "A business name is enough for now. These details become the default sender on future invoices.",
            previewEyebrow: "LIVE PREVIEW",
            previewTitle: "How your invoice header will look"
        ) {
            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                labeledTextField("Business name", text: $businessDraft.businessName)
                twoColumnFields(
                    left: labeledTextField("Legal name", text: $businessDraft.personName),
                    right: labeledTextField("Tax ID / VAT no.", text: $businessDraft.taxIdentifier)
                )
                labeledTextField("Address", text: $businessDraft.address)
                twoColumnFields(
                    left: labeledTextField("Email on invoices", text: $businessDraft.email),
                    right: labeledTextField("Phone", text: $businessDraft.phone)
                )
                currencyPicker
                twoColumnFields(
                    left: labeledNumberField("Default hourly rate", value: $businessDraft.defaultHourlyRateMinorUnits),
                    right: labeledTextField("Payment terms", text: $businessDraft.paymentTerms)
                )
                labeledTextField("Payment details", text: $businessDraft.paymentDetails)
            }
        } preview: {
            invoiceHeaderPreview
        }
    }

    private var clientStep: some View {
        splitStep(
            eyebrow: "STEP 03 · FIRST CLIENT",
            title: "Add the client you will bill first",
            subtitle: "A client name creates the record. Email, contact, and billing details can wait until invoice review.",
            previewEyebrow: "CLIENTS",
            previewTitle: "Where your client list will live"
        ) {
            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                labeledTextField("Client name", text: $clientDraft.name)
                twoColumnFields(
                    left: labeledTextField("Contact email", text: $clientDraft.email),
                    right: labeledTextField("Contact person", text: $clientDraft.contactPerson)
                )
                twoColumnFields(
                    left: labeledTextField("Phone", text: $clientDraft.phone),
                    right: labeledTextField("VAT no.", text: $clientDraft.vatNumber)
                )
                labeledTextField("Billing address", text: $clientDraft.billingAddress)
            }
        } preview: {
            clientListPreview
        }
    }

    private var projectStep: some View {
        splitStep(
            eyebrow: "STEP 04 · FIRST PROJECT",
            title: "Create the first place for work",
            subtitle: "Projects belong to clients. Buckets group the time or costs you will eventually invoice.",
            previewEyebrow: "PREVIEW",
            previewTitle: "What your project will look like"
        ) {
            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                labeledTextField("Project name", text: $projectDraft.name)
                twoColumnFields(
                    left: Text("Client\n\(selectedClientName)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(BillbiTypography.body)
                        .foregroundStyle(BillbiColor.textPrimary)
                        .padding(BillbiSpacing.md)
                        .background(panelBackground, in: RoundedRectangle(cornerRadius: BillbiRadius.lg)),
                    right: labeledNumberField("Project rate", value: $projectDraft.hourlyRateMinorUnits)
                )
                Divider().padding(.vertical, BillbiSpacing.sm)
                labeledTextField("First bucket", text: $projectDraft.firstBucketName, prompt: "General")
                Text("Leave it blank and Billbi will create a General bucket.")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
        } preview: {
            projectPreview
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
            StatusBadge(OnboardingFlowModel.summaryCards(for: workspaceStore.workspace).isEmpty ? .neutral : .success, title: summaryBadge)

            Text(readyTitle)
                .font(BillbiTypography.display)
                .foregroundStyle(BillbiColor.textPrimary)
            Text(readySubtitle)
                .font(BillbiTypography.body)
                .foregroundStyle(BillbiColor.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BillbiSpacing.md) {
                ForEach(OnboardingFlowModel.summaryCards(for: workspaceStore.workspace), id: \.self) { card in
                    summaryCard(card)
                }
            }
            .frame(maxWidth: 760)

            HStack(spacing: BillbiSpacing.md) {
                Button(primaryReadyTitle) {
                    finish()
                }
                .buttonStyle(.billbiAction(.primary))
                .accessibilityIdentifier("Continue")

                Button {
                    finish(forceDashboard: true)
                } label: {
                    Label("Go to dashboard", systemImage: "gauge")
                }
                .buttonStyle(.billbiAction(.neutral))
            }

            tips
        }
        .padding(BillbiSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var footer: some View {
        HStack {
            Text("\(flow.step.displayIndex) of 5")
                .font(BillbiTypography.small.monospacedDigit())
                .foregroundStyle(BillbiColor.textSecondary)
            Spacer()
            Button {
                flow.back()
            } label: {
                Label("Back", systemImage: "arrow.left")
            }
            .buttonStyle(.billbiAction(.neutral))
            .disabled(flow.step == .welcome)

            Button {
                continueTapped()
            } label: {
                Label(flow.step == .client ? "Save client" : flow.step == .project ? "Create project" : "Continue", systemImage: "arrow.right")
            }
            .buttonStyle(.billbiAction(.primary))
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("Continue")
        }
        .padding(BillbiSpacing.md)
        .background(BillbiColor.surface)
    }

    private func continueTapped() {
        do {
            switch flow.step {
            case .welcome:
                break
            case .business:
                try workspaceStore.saveOnboardingBusiness(businessDraft)
            case .client:
                if let client = try workspaceStore.saveOnboardingClient(clientDraft, occurredAt: currentDate) {
                    savedClientID = client.id
                    projectDraft.clientID = client.id
                }
            case .project:
                if projectDraft.clientID == nil {
                    projectDraft.clientID = savedClientID ?? workspaceStore.workspace.clients.first?.id
                }
                _ = try workspaceStore.saveOnboardingProject(projectDraft, occurredAt: currentDate)
            case .ready:
                finish()
                return
            }
            errorMessage = nil
            flow.advance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func skip() {
        do {
            try workspaceStore.completeOnboarding()
            onComplete(.dashboard)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish(forceDashboard: Bool = false) {
        do {
            try workspaceStore.completeOnboarding()
            onComplete(forceDashboard ? .dashboard : OnboardingFlowModel.primaryCTA(for: workspaceStore.workspace))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var selectedClientName: String {
        let clientID = projectDraft.clientID ?? savedClientID
        return workspaceStore.workspace.clients.first(where: { $0.id == clientID })?.name
            ?? clientDraft.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? "First client"
    }

    private var projectPreviewTotalAmount: String {
        let currencyCode = projectDraft.currencyCode.nilIfTrimmedEmpty
            ?? workspaceStore.workspace.businessProfile.currencyCode
        guard currencyCode == "EUR" else {
            return "\(currencyCode) 0.00"
        }
        return MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
            .string(fromMinorUnits: 0)
    }

    private var summaryBadge: String {
        OnboardingFlowModel.summaryCards(for: workspaceStore.workspace).isEmpty ? "SETUP SKIPPED" : "READY"
    }

    private var readyTitle: String {
        workspaceStore.workspace.businessProfile.personName.nilIfTrimmedEmpty.map { "You're ready, \($0)." } ?? "You're ready."
    }

    private var readySubtitle: String {
        let cards = OnboardingFlowModel.summaryCards(for: workspaceStore.workspace)
        if cards.contains(.project), let project = workspaceStore.workspace.activeProjects.first {
            return "\(project.name) is ready with \(project.buckets.first?.name ?? "General")."
        }
        if cards.contains(.client), let client = workspaceStore.workspace.clients.first {
            return "\(client.name) is saved. Add a project when you're ready."
        }
        if cards.contains(.business) {
            return "\(workspaceStore.workspace.businessProfile.businessName) is saved. Add clients and projects next."
        }
        return "You can start from the dashboard and fill details later."
    }

    private var primaryReadyTitle: String {
        switch OnboardingFlowModel.primaryCTA(for: workspaceStore.workspace) {
        case .dashboard:
            "Enter workspace"
        case .project:
            "Open project"
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            Text("NEXT")
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textSecondary)
            ForEach(readyTips, id: \.self) { tip in
                Label(tip, systemImage: "circle")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
        }
        .padding(BillbiSpacing.md)
        .frame(maxWidth: 760, alignment: .leading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }

    private var readyTips: [String] {
        let cards = OnboardingFlowModel.summaryCards(for: workspaceStore.workspace)
        if !cards.contains(.business) {
            return ["Add your business profile in Settings", "Create your first client", "Open a project with a starter bucket"]
        }
        if !cards.contains(.client) {
            return ["Create your first client", "Open a project", "Review invoice details before finalizing"]
        }
        if !cards.contains(.project) {
            return ["Open a project for \(workspaceStore.workspace.clients.first?.name ?? "this client")", "Use buckets for billable work", "Review invoice details before finalizing"]
        }
        return ["Log time in the first bucket", "Mark work ready when it is invoiceable", "Finalize invoices after details are complete"]
    }

    private func splitStep<Content: View, Preview: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        previewEyebrow: String,
        previewTitle: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                    Text(eyebrow)
                        .font(BillbiTypography.micro)
                        .foregroundStyle(BillbiColor.brand)
                    Text(title)
                        .font(BillbiTypography.display)
                        .foregroundStyle(BillbiColor.textPrimary)
                    Text(subtitle)
                        .font(BillbiTypography.body)
                        .foregroundStyle(BillbiColor.textSecondary)
                    content()
                    if let errorMessage {
                        Text(errorMessage)
                            .font(BillbiTypography.small)
                            .foregroundStyle(BillbiColor.danger)
                    }
                }
                .padding(BillbiSpacing.xl)
            }
            .frame(minWidth: 560)

            onboardingPreviewPanel(eyebrow: previewEyebrow, title: previewTitle) {
                preview()
            }
        }
    }

    private func onboardingPreviewPanel<Content: View>(
        eyebrow: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            Text(eyebrow)
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textSecondary)
            Text(title)
                .font(BillbiTypography.heading)
                .foregroundStyle(BillbiColor.textPrimary)

            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(BillbiSpacing.xl)
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.surfaceAlt)
    }

    private func setupRow(_ number: String, title: String, detail: String) -> some View {
        HStack(spacing: BillbiSpacing.md) {
            Text(number)
                .font(BillbiTypography.body.monospacedDigit())
                .foregroundStyle(BillbiColor.textSecondary)
            VStack(alignment: .leading) {
                Text(title)
                    .font(BillbiTypography.subheading)
                    .foregroundStyle(BillbiColor.textPrimary)
                Text(detail)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BillbiColor.textSecondary)
        }
        .padding(BillbiSpacing.md)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }

    private func labeledTextField(_ title: String, text: Binding<String>, prompt: String = "") -> some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
            Text(title)
                .font(BillbiTypography.small.weight(.medium))
                .foregroundStyle(BillbiColor.textMuted)
            TextField(prompt, text: text)
                .textFieldStyle(.billbiInput)
                .onSubmit { continueTapped() }
        }
    }

    private func labeledNumberField(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
            Text(title)
                .font(BillbiTypography.small.weight(.medium))
                .foregroundStyle(BillbiColor.textMuted)
            TextField(title, value: Binding(
                get: { max(value.wrappedValue / 100, 0) },
                set: { value.wrappedValue = max($0, 0) * 100 }
            ), format: .number)
            .textFieldStyle(.billbiInput)
            .onSubmit { continueTapped() }
        }
    }

    private func twoColumnFields<Left: View, Right: View>(left: Left, right: Right) -> some View {
        HStack(alignment: .top, spacing: BillbiSpacing.md) {
            left
            right
        }
    }

    private var currencyPicker: some View {
        Picker("Currency", selection: $businessDraft.currencyCode) {
            Text("EUR").tag("EUR")
            Text("CHF").tag("CHF")
            Text("USD").tag("USD")
            Text("GBP").tag("GBP")
        }
        .pickerStyle(.segmented)
    }

    private var invoiceHeaderPreview: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? "Your business")
                        .font(BillbiTypography.heading)
                    Text(businessDraft.personName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(Color.gray)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Invoice").font(BillbiTypography.heading.weight(.bold))
                    Text("PREVIEW-001").font(BillbiTypography.small.monospaced())
                }
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("FROM").font(BillbiTypography.micro).foregroundStyle(Color.gray)
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? "Your business")
                    Text(businessDraft.address)
                    Text(businessDraft.taxIdentifier)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("TERMS").font(BillbiTypography.micro).foregroundStyle(Color.gray)
                    Text(businessDraft.paymentTerms.nilIfTrimmedEmpty ?? "Net 14")
                    Text("\(businessDraft.currencyCode) \(businessDraft.defaultHourlyRateMinorUnits / 100)/h")
                }
            }
            Text("line items appear after time is logged...")
                .foregroundStyle(Color.gray)
        }
        .padding(BillbiSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .foregroundStyle(Color.black)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: BillbiRadius.lg)
                .stroke(Color.black.opacity(0.12))
        }
    }

    private var clientListPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clients").font(BillbiTypography.heading)
                Spacer()
                Text(clientDraft.name.nilIfTrimmedEmpty == nil ? "0 clients" : "1 client")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
            .padding(BillbiSpacing.md)
            Divider()

            ClientRow(client: previewClient, isSelected: false)
                .padding(.horizontal, BillbiSpacing.sm)
                .padding(.vertical, BillbiSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }

    @ViewBuilder
    private var welcomeInvoicePreview: some View {
#if os(macOS)
        let row = sampleInvoiceRow
        if let rendered = try? InvoicePDFService.placeholder().renderInvoiceHTML(profile: sampleInvoiceProfile, row: row) {
            MacInvoiceHTMLDocumentView(
                rendered: rendered,
                invoiceID: row.id,
                state: welcomeInvoicePreviewState
            )
            .frame(maxWidth: .infinity, minHeight: 680, maxHeight: .infinity, alignment: .top)
            .background(Color.white, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.lg)
                    .stroke(BillbiColor.border)
            }
        } else {
            ContentUnavailableView(
                "Preview unavailable",
                systemImage: "doc.richtext",
                description: Text("The sample invoice could not be rendered.")
            )
        }
#else
        invoiceHeaderPreview
#endif
    }

    private var projectPreview: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(projectDraft.name.nilIfTrimmedEmpty ?? "First project")
                        .font(BillbiTypography.subheading)
                        .foregroundStyle(BillbiColor.textPrimary)
                    Text(selectedClientName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                    Text("1 bucket")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BillbiColor.textMuted)
                }

                Spacer()

                StatusBadge(.success, title: "Active")
            }

            HStack(spacing: BillbiSpacing.sm) {
                onboardingProjectCountPill(value: 1, label: "Open")
                onboardingProjectCountPill(value: 0, label: "Ready", tone: .success)
                onboardingProjectCountPill(value: 0, label: "Invoiced", tone: .warning)
            }

            Divider()

            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text(projectPreviewTotalAmount)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                Text("total billed + open")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textMuted)
            }

            onboardingBucketRow
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .padding(BillbiSpacing.md)
        .billbiSurface()
    }

    private var onboardingBucketRow: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "diamond")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(projectDraft.firstBucketName.nilIfTrimmedEmpty ?? "General")
                    .font(BillbiTypography.body)
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text("0.0 h · \(projectPreviewTotalAmount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            StatusBadge(.neutral, title: "Open")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: false)
    }

    private func onboardingProjectCountPill(
        value: Int,
        label: String,
        tone: BillbiStatusTone = .neutral
    ) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(BillbiTypography.small)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, BillbiSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
    }

    private func summaryCard(_ card: OnboardingSummaryCard) -> some View {
        let workspace = workspaceStore.workspace
        let title: String
        let detail: String
        switch card {
        case .business:
            title = "BUSINESS"
            detail = workspace.businessProfile.businessName
        case .client:
            title = "CLIENT"
            detail = workspace.clients.first?.name ?? ""
        case .project:
            title = "PROJECT"
            detail = workspace.activeProjects.first?.name ?? ""
        case .bucket:
            title = "FIRST BUCKET"
            detail = workspace.activeProjects.first?.buckets.first?.name ?? ""
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textSecondary)
            Text(detail)
                .font(BillbiTypography.subheading)
                .foregroundStyle(BillbiColor.textPrimary)
        }
        .padding(BillbiSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }

    private var panelBackground: some ShapeStyle {
        BillbiColor.surface
    }

    private var previewClient: WorkspaceClient {
        WorkspaceClient(
            id: Self.sampleClientID,
            name: clientDraft.name.nilIfTrimmedEmpty ?? "Your first client",
            email: clientDraft.email.nilIfTrimmedEmpty ?? "billing details later",
            billingAddress: clientDraft.billingAddress,
            defaultTermsDays: workspaceStore.workspace.businessProfile.defaultTermsDays,
            isArchived: false
        )
    }

    private var sampleInvoiceProfile: BusinessProfileProjection {
        BusinessProfileProjection(
            businessName: "Billbi Studio",
            personName: "Alex Morgan",
            email: "hello@billbi.example",
            phone: "+41 31 555 01 80",
            address: "Aarstrasse 18\n3005 Bern\nSwitzerland",
            taxIdentifier: "CHE-123.456.789 MWST",
            invoicePrefix: "PREVIEW",
            nextInvoiceNumber: 1,
            currencyCode: "EUR",
            paymentDetails: "IBAN CH93 0076 2011 6238 5295 7",
            taxNote: "Reverse charge may apply where required.",
            defaultTermsDays: 14
        )
    }

    private var sampleInvoiceRow: WorkspaceInvoiceRowProjection {
        let invoice = WorkspaceInvoice(
            id: Self.sampleInvoiceID,
            number: "PREVIEW-001",
            businessSnapshot: sampleInvoiceProfile,
            clientSnapshot: WorkspaceClient(
                id: Self.sampleClientID,
                name: "Northwind Labs",
                email: "billing@northwind.example",
                billingAddress: "42 Harbor Road\nDublin 2\nIreland",
                defaultTermsDays: 14
            ),
            clientID: Self.sampleClientID,
            clientName: "Northwind Labs",
            projectID: Self.sampleProjectID,
            projectName: "Website retainer",
            bucketID: Self.sampleBucketID,
            bucketName: "Design sprint",
            issueDate: Date.billbiDate(year: 2026, month: 5, day: 7),
            dueDate: Date.billbiDate(year: 2026, month: 5, day: 21),
            servicePeriod: "May 2026",
            status: .finalized,
            totalMinorUnits: 218_000,
            lineItems: [
                WorkspaceInvoiceLineItemSnapshot(
                    id: Self.sampleLineItemAID,
                    description: "Discovery workshop and scope refinement",
                    quantityLabel: "6.0 h",
                    amountMinorUnits: 48_000
                ),
                WorkspaceInvoiceLineItemSnapshot(
                    id: Self.sampleLineItemBID,
                    description: "Interface design sprint",
                    quantityLabel: "18.5 h",
                    amountMinorUnits: 148_000
                ),
                WorkspaceInvoiceLineItemSnapshot(
                    id: Self.sampleLineItemCID,
                    description: "Prototype review package",
                    quantityLabel: "1 item",
                    amountMinorUnits: 22_000
                ),
            ],
            currencyCode: "EUR",
            note: "Thank you for the continued collaboration."
        )

        return WorkspaceInvoiceRowProjection(
            invoice: invoice,
            projectName: "Website retainer",
            billingAddress: "42 Harbor Road\nDublin 2\nIreland",
            on: currentDate,
            formatter: MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        )
    }

    private static let sampleInvoiceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let sampleClientID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let sampleProjectID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let sampleBucketID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private static let sampleLineItemAID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    private static let sampleLineItemBID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    private static let sampleLineItemCID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var nilIfTrimmedEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
