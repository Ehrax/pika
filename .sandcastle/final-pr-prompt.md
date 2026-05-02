# TASK

Create or update the GitHub pull request for the PRD branch with a polished Markdown description.

You are running locally in the clean PRD worktree on branch `{{PRD_BRANCH}}`.

# INPUTS

- Base branch: `{{BASE_BRANCH}}`
- Head branch: `{{PRD_BRANCH}}`
- PRD issue: #{{PRD_ISSUE_NUMBER}} - {{PRD_TITLE}}
- PRD URL: {{PRD_URL}}

# STEPS

1. Verify the worktree is clean with `git status --porcelain`.
2. Push the PRD branch with `git push -u origin {{PRD_BRANCH}}`.
3. Inspect the branch history with `git log --oneline {{BASE_BRANCH}}..HEAD`.
4. Inspect linked child issues from the branch history and PRD text as needed using `gh issue view`.
5. Write a concise PR body as Markdown. It should include:
   - `Completes #{{PRD_ISSUE_NUMBER}}`
   - A short summary of the architectural outcome
   - A bullet list of notable child issues/changes
   - A short verification section based on checks actually mentioned in merge commits/logs
   - The PRD URL
6. Put the Markdown body in a temporary file and pass that file to `gh pr create --body-file` or `gh pr edit --body-file`. Do not pass escaped `\n` text.
7. If a PR already exists for `{{PRD_BRANCH}}`, update its title/body and print its URL.
8. Otherwise create a GitHub PR with:
   - base: `{{BASE_BRANCH}}`
   - head: `{{PRD_BRANCH}}`
   - title: `PRD #{{PRD_ISSUE_NUMBER}}: {{PRD_TITLE}}`
   - the Markdown body file.
9. Print the PR URL.

Do not close the PRD issue manually; the PR body should let GitHub close it on merge.
Do not mention local worktree paths or local machine state in the PR.
Do not leave literal `\n` sequences in the PR body.

Once complete, output <promise>COMPLETE</promise>.
