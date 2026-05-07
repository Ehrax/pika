import SwiftUI

struct OnboardingView: View {
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    let onComplete: (OnboardingPrimaryCTA) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow = OnboardingFlowModel()
    @State private var businessDraft: OnboardingBusinessDraft
    @State private var clientDraft: OnboardingClientDraft
    @State private var projectDraft: OnboardingProjectDraft
    @State private var savedClientID: WorkspaceClient.ID?
    @State private var errorMessage: String?
    @State private var stepTransitionDirection = 1.0

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

            ZStack(alignment: .bottomTrailing) {
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
                .id(flow.step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(onboardingStepTransition)
                .animation(onboardingStepAnimation, value: flow.step)

                stepFooterActions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BillbiColor.background)
        .accessibilityIdentifier("Billbi Onboarding")
    }

    private var header: some View {
        OnboardingHeaderView(step: flow.step, progressAnimation: onboardingProgressAnimation)
    }

    private var onboardingProgressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24, extraBounce: 0.02)
    }

    private var onboardingStepAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var onboardingStepTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        return .asymmetric(
            insertion: .modifier(
                active: OnboardingStepSlideTransitionModifier(opacity: 0, xOffset: 28 * stepTransitionDirection),
                identity: OnboardingStepSlideTransitionModifier(opacity: 1, xOffset: 0)
            ),
            removal: .modifier(
                active: OnboardingStepSlideTransitionModifier(opacity: 0, xOffset: -16 * stepTransitionDirection),
                identity: OnboardingStepSlideTransitionModifier(opacity: 1, xOffset: 0)
            )
        )
    }

    private var welcomeStep: some View {
        OnboardingWelcomeView(
            onStart: { continueTapped() },
            onSkip: { skip() }
        ) {
            OnboardingWelcomeInvoicePreview(currentDate: currentDate)
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
            VStack(alignment: .leading, spacing: BillbiSpacing.xl) {
                onboardingFormSection("Business profile") {
                    labeledTextField("Business name", text: $businessDraft.businessName)
                    labeledTextField("Legal name", text: $businessDraft.personName)
                    labeledTextField("Address", text: $businessDraft.address)
                    labeledTextField("Email on invoices", text: $businessDraft.email)
                    labeledTextField("Phone", text: $businessDraft.phone)
                }

                onboardingFormSection("Invoice defaults") {
                    labeledTextField("Tax ID / VAT no.", text: $businessDraft.taxIdentifier)
                    labeledCurrencyPicker
                    labeledNumberField("Default hourly rate", value: $businessDraft.defaultHourlyRateMinorUnits)
                    labeledIntegerField("Payment terms", value: $businessDraft.defaultTermsDays)
                }

                onboardingFormSection("Bank account") {
                    labeledTextField("Account name", text: paymentAccountNameBinding)
                    labeledTextField("IBAN", text: paymentIBANBinding)
                    labeledTextField("BIC", text: paymentBICBinding)
                }
            }
        } preview: {
            OnboardingBusinessInvoiceHeaderPreview(businessDraft: businessDraft)
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
            VStack(alignment: .leading, spacing: BillbiSpacing.xl) {
                onboardingFormSection("Client profile") {
                    labeledTextField("Client name", text: $clientDraft.name)
                    labeledTextField("VAT no.", text: $clientDraft.vatNumber)
                }

                onboardingFormSection("Contact") {
                    labeledTextField("Contact email", text: $clientDraft.email)
                    labeledTextField("Contact person", text: $clientDraft.contactPerson)
                    labeledTextField("Phone", text: $clientDraft.phone)
                }

                onboardingFormSection("Billing") {
                    labeledTextField("Billing address", text: $clientDraft.billingAddress)
                }
            }
        } preview: {
            OnboardingClientListPreview(
                clientDraft: clientDraft,
                workspace: workspaceStore.workspace
            )
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
            VStack(alignment: .leading, spacing: BillbiSpacing.xl) {
                onboardingFormSection("Project") {
                    selectedClientContext
                    labeledTextField("Project name", text: $projectDraft.name)
                    labeledNumberField("Project rate", value: $projectDraft.hourlyRateMinorUnits)
                }

                onboardingFormSection("First bucket") {
                    labeledTextField("Bucket name", text: $projectDraft.firstBucketName, prompt: "General")
                    Text("Leave it blank and Billbi will create a General bucket.")
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                }
            }
        } preview: {
            OnboardingProjectPreview(
                projectDraft: projectDraft,
                selectedClientName: selectedClientName,
                workspace: workspaceStore.workspace
            )
        }
    }

    @ViewBuilder
    private var readyStep: some View {
        OnboardingReadyView(
            workspace: workspaceStore.workspace,
            summary: OnboardingFlowModel.readySummary(for: workspaceStore.workspace),
            onOpenApplication: { finish() }
        )
    }

    private var stepNavigationButtons: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Button {
                stepTransitionDirection = -1
                flow.back()
            } label: {
                Label("Back", systemImage: "arrow.left")
            }
            .buttonStyle(.billbiAction(.neutral, size: .large))
            .disabled(flow.step == .welcome)

            Button {
                continueTapped()
            } label: {
                Label(flow.step == .client ? "Save client" : flow.step == .project ? "Create project" : "Continue", systemImage: "arrow.right")
            }
            .buttonStyle(.billbiAction(.primary, size: .large))
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("Continue")
        }
    }

    @ViewBuilder
    private var stepFooterActions: some View {
        if flow.step != .welcome && flow.step != .ready {
            stepNavigationButtons
                .padding(BillbiSpacing.xl)
        }
    }

    private func continueTapped() {
        do {
            switch flow.continueAction(
                workspace: workspaceStore.workspace,
                businessDraft: businessDraft,
                clientDraft: clientDraft,
                projectDraft: projectDraft
            ) {
            case .advanceOnly:
                break
            case .saveBusiness(let draft):
                try workspaceStore.saveOnboardingBusiness(draft)
            case .saveClient(let draft):
                if let client = try workspaceStore.saveOnboardingClient(draft, occurredAt: currentDate) {
                    savedClientID = client.id
                    projectDraft.clientID = client.id
                }
            case .saveProject(let draft):
                projectDraft.clientID = draft.clientID
                _ = try workspaceStore.saveOnboardingProject(draft, occurredAt: currentDate)
            case .complete(let primaryCTA):
                try workspaceStore.completeOnboarding()
                onComplete(primaryCTA)
                return
            }
            errorMessage = nil
            stepTransitionDirection = 1
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
            onComplete(forceDashboard ? .dashboard : OnboardingFlowModel.readySummary(for: workspaceStore.workspace).primaryCTA)
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
            ?? String(localized: "First client")
    }

    private var paymentAccountNameBinding: Binding<String> {
        paymentDetailsBinding(
            get: \.accountName,
            set: { components, value in components.accountName = value }
        )
    }

    private var paymentIBANBinding: Binding<String> {
        paymentDetailsBinding(
            get: \.iban,
            set: { components, value in components.iban = value }
        )
    }

    private var paymentBICBinding: Binding<String> {
        paymentDetailsBinding(
            get: \.bic,
            set: { components, value in components.bic = value }
        )
    }

    private func paymentDetailsBinding(
        get: @escaping (PaymentDetailsComponents) -> String,
        set: @escaping (inout PaymentDetailsComponents, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                get(PaymentDetailsComponents(rawValue: businessDraft.paymentDetails))
            },
            set: { newValue in
                var components = PaymentDetailsComponents(rawValue: businessDraft.paymentDetails)
                set(&components, newValue)
                businessDraft.paymentDetails = components.rawValue
            }
        )
    }

    private func splitStep<Content: View, Preview: View>(
        eyebrow: LocalizedStringKey,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        previewEyebrow: LocalizedStringKey,
        previewTitle: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        OnboardingStepForm(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            previewEyebrow: previewEyebrow,
            previewTitle: previewTitle,
            errorMessage: errorMessage
        ) {
            content()
        } preview: {
            preview()
        }
    }

    private func labeledTextField(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "") -> some View {
        OnboardingLabeledTextField(title, text: text, prompt: prompt, onSubmit: continueTapped)
    }

    private func labeledNumberField(_ title: LocalizedStringKey, value: Binding<Int>) -> some View {
        OnboardingLabeledNumberField(title: title, value: value, onSubmit: continueTapped)
    }

    private func labeledIntegerField(_ title: LocalizedStringKey, value: Binding<Int>, suffix: String? = nil) -> some View {
        OnboardingLabeledIntegerField(title, value: value, suffix: suffix, onSubmit: continueTapped)
    }

    private func onboardingFormSection<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        OnboardingFormSection(title, content: content)
    }

    private var selectedClientContext: some View {
        OnboardingFieldRow("Client") {
            Text(selectedClientName)
                .font(BillbiTypography.body)
                .foregroundStyle(BillbiColor.textPrimary)
                .lineLimit(1)
        }
    }

    private var labeledCurrencyPicker: some View {
        OnboardingFieldRow("Currency") {
            currencyPicker
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

}
