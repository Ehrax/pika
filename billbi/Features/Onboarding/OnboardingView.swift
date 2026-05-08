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
            currencyCode: firstProject?.currencyCode ?? "EUR",
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
        OnboardingBusinessStep(
            businessDraft: $businessDraft,
            errorMessage: errorMessage,
            onSubmit: continueTapped
        )
    }

    private var clientStep: some View {
        OnboardingClientStep(
            clientDraft: $clientDraft,
            workspace: workspaceStore.workspace,
            errorMessage: errorMessage,
            onSubmit: continueTapped
        )
    }

    private var projectStep: some View {
        OnboardingProjectStep(
            projectDraft: $projectDraft,
            selectedClientName: selectedClientName,
            workspace: workspaceStore.workspace,
            errorMessage: errorMessage,
            onSubmit: continueTapped
        )
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

}
