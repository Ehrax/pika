# Store Onboarding Completion In The Workspace

Onboarding completion is stored in the Workspace data model instead of local app preferences. This makes first-run completion follow the workspace across restore and sync, at the cost of treating a UI setup flag as workspace state. A debug-only reset may clear the completion flag for development and QA, but normal production users should not see a re-run onboarding action.
