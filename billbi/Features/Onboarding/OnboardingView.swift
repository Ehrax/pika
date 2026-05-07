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
        .background(Color(nsColor: .textBackgroundColor).opacity(0.08))
        .accessibilityIdentifier("Billbi Onboarding")
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(BillbiColor.brand)
                    .frame(width: 28, height: 28)
                    .overlay(Text("B").font(.headline).foregroundStyle(.white))
                Text("Billbi")
                    .font(.headline)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(String(format: "%02d / 05", flow.step.displayIndex))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step == flow.step ? BillbiColor.brand : Color.secondary.opacity(0.25))
                        .frame(width: step == flow.step ? 26 : 7, height: 7)
                }
            }

            Spacer()

            Button("Skip setup") {
                skip()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("Skip setup")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var welcomeStep: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Welcome to Billbi")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BillbiColor.brand)
                Text("Set up invoicing without the spreadsheet.")
                    .font(.system(size: 52, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("A calm first run for your business profile, first client, first project, and one starter bucket. You can skip now and fill details later.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)

                VStack(spacing: 10) {
                    setupRow("01", title: "About your business", detail: "name, currency, invoice identity")
                    setupRow("02", title: "Add your first client", detail: "someone you actually invoice")
                    setupRow("03", title: "Open your first project", detail: "one bucket to start tracking work")
                }

                HStack {
                    Button {
                        continueTapped()
                    } label: {
                        Label("Let's set up Billbi", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("Continue")

                    Text("~5 min · you can come back later")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(48)
            .frame(minWidth: 520)

            onboardingPreviewPanel(
                eyebrow: "PREVIEW",
                title: "What Billbi feels like day to day"
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    previewInvoiceCard
                    previewProjectCard
                }
            }
        }
    }

    private var businessStep: some View {
        splitStep(
            eyebrow: "STEP 02 · BUSINESS",
            title: "Tell us about your business",
            subtitle: "This goes on invoices. You can change anything later under Settings.",
            previewEyebrow: "LIVE PREVIEW",
            previewTitle: "How your invoice header will look"
        ) {
            VStack(alignment: .leading, spacing: 14) {
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
            title: "Add someone you actually invoice",
            subtitle: "Client name is enough. Billing details can stay empty until invoice review.",
            previewEyebrow: "CLIENTS",
            previewTitle: "Where your client list will live"
        ) {
            VStack(alignment: .leading, spacing: 14) {
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
            title: "Open a project, drop in one bucket",
            subtitle: "Project is the engagement. Bucket is a chunk of work you'll bill for.",
            previewEyebrow: "PREVIEW",
            previewTitle: "What your project will look like"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                labeledTextField("Project name", text: $projectDraft.name)
                twoColumnFields(
                    left: Text("Client\n\(selectedClientName)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8)),
                    right: labeledNumberField("Project rate", value: $projectDraft.hourlyRateMinorUnits)
                )
                Divider().padding(.vertical, 8)
                labeledTextField("First bucket", text: $projectDraft.firstBucketName, prompt: "General")
                Text("Leave blank and Billbi will create a General bucket.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } preview: {
            projectPreview
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(summaryBadge)
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.16), in: Capsule())

            Text(readyTitle)
                .font(.system(size: 52, weight: .bold))
            Text(readySubtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(OnboardingFlowModel.summaryCards(for: workspaceStore.workspace), id: \.self) { card in
                    summaryCard(card)
                }
            }
            .frame(maxWidth: 760)

            HStack(spacing: 18) {
                Button(primaryReadyTitle) {
                    finish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("Continue")

                Button("Go to dashboard") {
                    finish(forceDashboard: true)
                }
                .buttonStyle(.plain)
            }

            tips
        }
        .padding(56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var footer: some View {
        HStack {
            Text("\(flow.step.displayIndex) of 5")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                flow.back()
            } label: {
                Label("Back", systemImage: "arrow.left")
            }
            .disabled(flow.step == .welcome)

            Button {
                continueTapped()
            } label: {
                Label(flow.step == .client ? "Save client" : flow.step == .project ? "Create project" : "Continue", systemImage: "arrow.right")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("Continue")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.bar)
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
            "Enter Billbi"
        case .project:
            "Open project workbench"
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEXT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(readyTips, id: \.self) { tip in
                Label(tip, systemImage: "circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 760, alignment: .leading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var readyTips: [String] {
        let cards = OnboardingFlowModel.summaryCards(for: workspaceStore.workspace)
        if !cards.contains(.business) {
            return ["Add your business profile in Settings", "Create a client", "Open a project with a starter bucket"]
        }
        if !cards.contains(.client) {
            return ["Create your first client", "Open a project", "Review required invoice details before finalizing"]
        }
        if !cards.contains(.project) {
            return ["Open a project for \(workspaceStore.workspace.clients.first?.name ?? "this client")", "Add buckets as work packages", "Review required invoice details before finalizing"]
        }
        return ["Log time in the first bucket", "Mark a bucket ready when work is invoiceable", "Finalize invoices after required details are complete"]
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
                VStack(alignment: .leading, spacing: 22) {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BillbiColor.brand)
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    content()
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                .padding(48)
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
        VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            content()
                .frame(maxWidth: 560)
            Spacer()
        }
        .padding(48)
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.06))
    }

    private func setupRow(_ number: String, title: String, detail: String) -> some View {
        HStack(spacing: 18) {
            Text(number)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func labeledTextField(_ title: String, text: Binding<String>, prompt: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { continueTapped() }
        }
    }

    private func labeledNumberField(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, value: Binding(
                get: { max(value.wrappedValue / 100, 0) },
                set: { value.wrappedValue = max($0, 0) * 100 }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .onSubmit { continueTapped() }
        }
    }

    private func twoColumnFields<Left: View, Right: View>(left: Left, right: Right) -> some View {
        HStack(alignment: .top, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? "Your business")
                        .font(.title2.weight(.bold))
                    Text(businessDraft.personName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Invoice").font(.title.weight(.bold))
                    Text("PREVIEW-001").font(.callout.monospaced())
                }
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("FROM").font(.caption).foregroundStyle(.secondary)
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? "Your business")
                    Text(businessDraft.address)
                    Text(businessDraft.taxIdentifier)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("TERMS").font(.caption).foregroundStyle(.secondary)
                    Text(businessDraft.paymentTerms.nilIfTrimmedEmpty ?? "Net 14")
                    Text("\(businessDraft.currencyCode) \(businessDraft.defaultHourlyRateMinorUnits / 100)/h")
                }
            }
            Text("line items appear after time is logged...")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .foregroundStyle(.black)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var clientListPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clients").font(.headline)
                Spacer()
                Text(clientDraft.name.nilIfTrimmedEmpty == nil ? "0 clients" : "1 client")
                    .foregroundStyle(.secondary)
            }
            .padding()
            Divider()
            HStack {
                Circle().fill(BillbiColor.brand).frame(width: 34, height: 34)
                    .overlay(Text(String(clientDraft.name.prefix(1)).uppercased().nilIfEmpty ?? "C").foregroundStyle(.white))
                VStack(alignment: .leading) {
                    Text(clientDraft.name.nilIfTrimmedEmpty ?? "Your first client")
                        .font(.headline)
                    Text(clientDraft.email.nilIfTrimmedEmpty ?? "billing details later")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
        }
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var projectPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(projectDraft.name.nilIfTrimmedEmpty ?? "First project")
                    .font(.title3.weight(.bold))
                Text("\(selectedClientName) · \(projectDraft.currencyCode.nilIfTrimmedEmpty ?? workspaceStore.workspace.businessProfile.currencyCode) \(projectDraft.hourlyRateMinorUnits / 100)/h")
                    .foregroundStyle(.secondary)
            }
            .padding()
            Divider()
            HStack {
                Image(systemName: "diamond")
                VStack(alignment: .leading) {
                    Text(projectDraft.firstBucketName.nilIfTrimmedEmpty ?? "General")
                        .font(.headline)
                    Text("hourly · ready to track")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("0.0 h")
                    .font(.body.monospacedDigit())
            }
            .padding()
        }
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var previewInvoiceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW-001").font(.headline.monospaced())
            Text("draft").foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("General")
                Spacer()
                Text("0.0 h")
            }
        }
        .padding()
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var previewProjectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRACKING").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text("First project · General").font(.headline)
            Text("00:00:00").font(.largeTitle.monospacedDigit().weight(.bold))
        }
        .padding()
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
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
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var panelBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor).opacity(0.86)
    }
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
