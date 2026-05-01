import * as sandcastle from "@ai-hero/sandcastle";
import {
  IMPLEMENTER_EFFORT,
  IMPLEMENTER_MODEL,
  MAX_ITERATIONS,
  MAX_PARALLEL,
  MERGER_EFFORT,
  MERGER_MODEL,
  PLANNER_EFFORT,
  PLANNER_MODEL,
  REVIEWER_EFFORT,
  REVIEWER_MODEL,
} from "./agent-config.mts";
import { noSandbox } from "@ai-hero/sandcastle/sandboxes/no-sandbox";
import { runWithConcurrencyLimit } from "./concurrency.mts";

type IssuePlan = {
  number: number;
  title: string;
  branch: string;
};

const hostSandbox = noSandbox();

const parsePlan = (stdout: string) => {
  const planMatch = stdout.match(/<plan>([\s\S]*?)<\/plan>/);
  if (!planMatch) {
    throw new Error("Orchestrator did not produce a <plan> tag.\n\n" + stdout);
  }

  return JSON.parse(planMatch[1]) as { issues: IssuePlan[] };
};

const runPlanner = async () => {
  const plan = await sandcastle.run({
    sandbox: hostSandbox,
    branchStrategy: { type: "head" },
    name: "Planner",
    agent: sandcastle.codex(PLANNER_MODEL, { effort: PLANNER_EFFORT }),
    promptFile: "./.sandcastle/plan-prompt.md",
  });

  return parsePlan(plan.stdout).issues;
};

const implementAndReviewIssue = async (issue: IssuePlan) => {
  const result = await sandcastle.run({
    sandbox: hostSandbox,
    branchStrategy: { type: "branch", branch: issue.branch },
    name: "Implementer #" + issue.number,
    agent: sandcastle.codex(IMPLEMENTER_MODEL, {
      effort: IMPLEMENTER_EFFORT,
    }),
    promptFile: "./.sandcastle/implement-prompt.md",
    promptArgs: {
      ISSUE_NUMBER: String(issue.number),
      ISSUE_TITLE: issue.title,
      BRANCH: issue.branch,
    },
  });

  if (result.commits.length === 0) {
    return result;
  }

  await sandcastle.run({
    sandbox: hostSandbox,
    branchStrategy: { type: "branch", branch: issue.branch },
    name: "Reviewer #" + issue.number,
    agent: sandcastle.codex(REVIEWER_MODEL, {
      effort: REVIEWER_EFFORT,
    }),
    promptFile: "./.sandcastle/review-prompt.md",
    promptArgs: {
      ISSUE_NUMBER: String(issue.number),
      ISSUE_TITLE: issue.title,
      BRANCH: issue.branch,
    },
  });

  return result;
};

const mergeCompletedBranches = async (completedIssues: IssuePlan[]) => {
  const completedBranches = completedIssues.map((issue) => issue.branch);

  await sandcastle.run({
    sandbox: hostSandbox,
    branchStrategy: { type: "head" },
    name: "Merger",
    maxIterations: 10,
    agent: sandcastle.codex(MERGER_MODEL, { effort: MERGER_EFFORT }),
    promptFile: "./.sandcastle/merge-prompt.md",
    promptArgs: {
      BRANCHES: completedBranches.map((branch) => `- ${branch}`).join("\n"),
      ISSUES: completedIssues
        .map((issue) => `- #${issue.number}: ${issue.title}`)
        .join("\n"),
    },
  });
};

for (let iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
  console.log(`\n=== Iteration ${iteration}/${MAX_ITERATIONS} ===\n`);

  const issues = await runPlanner();

  if (issues.length === 0) {
    console.log("No issues to work on. Exiting.");
    break;
  }

  console.log(
    `Planning complete. ${issues.length} issue(s) to work in parallel:`
  );
  for (const issue of issues) {
    console.log(`  #${issue.number}: ${issue.title} -> ${issue.branch}`);
  }

  const settled = await runWithConcurrencyLimit(
    issues,
    MAX_PARALLEL,
    implementAndReviewIssue
  );

  for (const [i, outcome] of settled.entries()) {
    if (outcome.status === "rejected") {
      console.error(
        `  x #${issues[i].number} (${issues[i].branch}) failed: ${outcome.reason}`
      );
    }
  }

  const completedIssues = settled
    .map((outcome, i) => ({ outcome, issue: issues[i] }))
    .filter(
      (
        entry
      ): entry is {
        outcome: PromiseFulfilledResult<
          Awaited<ReturnType<typeof sandcastle.run>>
        >;
        issue: IssuePlan;
      } =>
        entry.outcome.status === "fulfilled" &&
        entry.outcome.value.commits.length > 0
    )
    .map((entry) => entry.issue);

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

  await mergeCompletedBranches(completedIssues);
  console.log("\nBranches merged.");
}

console.log("\nAll done.");
