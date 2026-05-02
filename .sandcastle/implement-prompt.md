# TASK

Fix issue #{{ISSUE_NUMBER}}: {{ISSUE_TITLE}}

Read the issue body and comments carefully. Comments may contain the agent brief.

Only work on the issue specified.

Work on branch {{BRANCH}}. Make commits.

# CONTEXT

Here are the last 10 commits:

<recent-commits>

!`git log -n 10 --format="%H%n%ad%n%B---" --date=short`

</recent-commits>

<issue>

!`gh issue view {{ISSUE_NUMBER}} --json number,title,body,comments,labels,url --jq '{number, title, body, url, labels: [.labels[].name], comments: [.comments[].body]}'`

</issue>

<parent-prd>

!`gh issue view ${SANDCASTLE_PRD_ISSUE_NUMBER:-1} --json number,title,body,comments,labels,url --jq '{number, title, body, url, labels: [.labels[].name], comments: [.comments[].body]}'`

</parent-prd>

# EXPLORATION

Explore the repo and fill your context window with relevant information that will allow you to complete the task.

Pay extra attention to test files that touch the relevant parts of the code.

# EXECUTION

If applicable, use RGR to complete the task.

1. RED: write one focused test, then run the narrowest relevant test command and verify it fails for the expected reason.
2. GREEN: write the smallest implementation to pass that test, then rerun the relevant test command and verify it passes.
3. REPEAT until done
4. REFACTOR the code

# FEEDBACK LOOPS

This repository is a SwiftUI macOS app and this agent runs locally with `noSandbox()`, so macOS/Xcode tooling is available.

1. Prefer focused test commands while iterating. For unit-level changes, use `./script/test.sh` or the equivalent narrow `xcodebuild test` invocation.
2. For iOS-specific checks, use `./script/test_ios.sh` or a narrow `xcodebuild` command if the issue calls for it.
3. Run `git diff --check` before committing.
4. Do not use Node/TypeScript substitutes such as `npm run typecheck` or `npm run test` for app verification.

# COMMIT

Make a git commit. The commit message must:

1. Start with `RALPH:` prefix
2. Include task completed + PRD reference
3. Key decisions made
4. Files changed
5. Blockers or notes for next iteration

Keep it concise.

# THE ISSUE

If the task is not complete, leave a comment on the GitHub issue with what was done.

Do not close the issue - this will be done later.

Once complete, output <promise>COMPLETE</promise>.

# FINAL RULES

ONLY WORK ON A SINGLE TASK.
