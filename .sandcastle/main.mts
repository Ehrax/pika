import { MAX_ITERATIONS, MAX_PARALLEL } from "./agent-config.mts";
import { runWithConcurrencyLimit } from "./concurrency.mts";
import {
  cleanupPrdWorktree,
  currentBranch,
  readPrdIssue,
} from "./git-helpers.mts";
import { createPrdWorktree } from "./prd-worktree.mts";
import {
  implementAndReviewIssue,
  mergeCompletedBranches,
  runPrCreatorAgent,
  runPlanner,
} from "./sandcastle-runs.mts";
import { completedIssuesFromSettled } from "./workflow-results.mts";

const repoRoot = process.cwd();
const prdIssueNumber = Number(
  process.env.SANDCASTLE_PRD_ISSUE_NUMBER ??
  process.env.SANDCASTLE_PRD_ISSUE ??
  "1"
);

const prdIssue = await readPrdIssue(prdIssueNumber);
const baseBranch = await currentBranch();
const { branch: prdBranch, worktreePath } = await createPrdWorktree(
  prdIssue,
  baseBranch,
  repoRoot
);

console.log(`PRD branch: ${prdBranch}`);
console.log(`PRD worktree: ${worktreePath}`);

let prCreated = false;

for (let iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
  console.log(`\n=== Iteration ${iteration}/${MAX_ITERATIONS} ===\n`);

  const issues = await runPlanner(worktreePath, repoRoot, prdIssueNumber);

  if (issues.length === 0) {
    console.log("No ready child issues left. Creating PR.");
    await runPrCreatorAgent(prdIssue, worktreePath, repoRoot, prdBranch, baseBranch);
    await cleanupPrdWorktree(worktreePath);
    console.log("PRD worktree cleaned up.");
    prCreated = true;
    break;
  }

  console.log(
    `Planning complete. ${issues.length} issue(s) to work in parallel:`
  );
  for (const issue of issues) {
    console.log(`  #${issue.number}: ${issue.title} -> ${issue.branch}`);
  }

  const settled = await runWithConcurrencyLimit(issues, MAX_PARALLEL, (issue) =>
    implementAndReviewIssue(issue, worktreePath, repoRoot, prdBranch)
  );

  for (const [i, outcome] of settled.entries()) {
    if (outcome.status === "rejected") {
      console.error(
        `  x #${issues[i].number} (${issues[i].branch}) failed: ${outcome.reason}`
      );
    }
  }

  const completedIssues = completedIssuesFromSettled(settled, issues);

  console.log(
    `\nExecution complete. ${completedIssues.length} branch(es) with commits:`
  );
  for (const issue of completedIssues) {
    console.log(`  ${issue.branch}`);
  }

  if (completedIssues.length === 0) {
    console.log("No commits produced. Nothing to merge.");
    continue;
  }

  await mergeCompletedBranches(
    completedIssues,
    worktreePath,
    repoRoot,
    prdBranch
  );
  console.log(`\nBranches merged into ${prdBranch}.`);
}

if (!prCreated) {
  console.log(
    `Reached ${MAX_ITERATIONS} iteration(s) without exhausting child issues. PR not created yet.`
  );
}

console.log("\nAll done.");
