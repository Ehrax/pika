# TASK

Create the GitHub pull request for the completed PRD branch.

You are running locally in the clean PRD worktree on branch `{{PRD_BRANCH}}`.

# INPUTS

- Base branch: `{{BASE_BRANCH}}`
- Head branch: `{{PRD_BRANCH}}`
- PRD issue: #{{PRD_ISSUE_NUMBER}} - {{PRD_TITLE}}
- PRD URL: {{PRD_URL}}

# STEPS

1. Verify the worktree is clean with `git status --porcelain`.
2. Push the PRD branch with `git push -u origin {{PRD_BRANCH}}`.
3. If a PR already exists for `{{PRD_BRANCH}}`, print its URL.
4. Otherwise create a GitHub PR with:
   - base: `{{BASE_BRANCH}}`
   - head: `{{PRD_BRANCH}}`
   - title: `PRD #{{PRD_ISSUE_NUMBER}}: {{PRD_TITLE}}`
   - body including `Completes #{{PRD_ISSUE_NUMBER}}` and the PRD URL.
5. Print the PR URL.

Do not close the PRD issue manually; the PR body should let GitHub close it on merge.

Once complete, output <promise>COMPLETE</promise>.
