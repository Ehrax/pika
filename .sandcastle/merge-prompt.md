# TASK

Merge the following branches into the current branch:

{{BRANCHES}}

For each branch:

1. Run `git merge <branch> --no-edit`
2. If there are merge conflicts, resolve them intelligently by reading both sides and choosing the correct resolution
3. Run the relevant Swift/Xcode checks after conflict resolution. Prefer `./script/test.sh` for unit-level changes, plus narrower or broader `xcodebuild` checks when the merged branches require them. Run `git diff --check` before committing.
4. If conflicts introduce obvious issues, fix them before proceeding. Do not run Node/TypeScript substitutes such as `npm run typecheck` or `npm run test`.

After all branches are merged, make a single commit summarizing the merge.

# CLOSE ISSUES

For each branch that was merged, close its issue. If there are any parent issues (such as PRD's) which closing the issue would complete, close those too.

Here are all the issues:

{{ISSUES}}

Once you've merged everything you can, output <promise>COMPLETE</promise>.
