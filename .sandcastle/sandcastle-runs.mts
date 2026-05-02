import * as sandcastle from "@ai-hero/sandcastle";
import { noSandbox } from "@ai-hero/sandcastle/sandboxes/no-sandbox";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import {
  FINALIZER_EFFORT,
  FINALIZER_MODEL,
  IMPLEMENTER_EFFORT,
  IMPLEMENTER_MODEL,
  MERGER_EFFORT,
  MERGER_MODEL,
  PLANNER_EFFORT,
  PLANNER_MODEL,
  REVIEWER_EFFORT,
  REVIEWER_MODEL,
} from "./agent-config.mts";
import { issueBranchName } from "./branch-names.mts";
import { tryRunCommand } from "./git-helpers.mts";
import type { IssuePlan, PlannedIssue, PrdIssue } from "./workflow-types.mts";

const sandboxForRun = (repoRoot: string, scope: string) => {
  const gitConfigDir = join(repoRoot, ".sandcastle", "gitconfigs");
  mkdirSync(gitConfigDir, { recursive: true });
  return noSandbox({
    env: {
      GIT_CONFIG_GLOBAL: join(gitConfigDir, `${scope}.gitconfig`),
    },
  });
};

const logPath = (repoRoot: string, filename: string) =>
  join(repoRoot, ".sandcastle", "logs", filename);

const parsePlan = (stdout: string) => {
  const planMatch = stdout.match(/<plan>([\s\S]*?)<\/plan>/);
  if (!planMatch) {
    throw new Error("Orchestrator did not produce a <plan> tag.\n\n" + stdout);
  }

  return JSON.parse(planMatch[1]) as { issues: PlannedIssue[] };
};

export const runPlanner = async (
  worktreePath: string,
  repoRoot: string,
  prdIssueNumber: number
) => {
  const plan = await sandcastle.run({
    cwd: worktreePath,
    sandbox: sandboxForRun(repoRoot, "planner"),
    branchStrategy: { type: "head" },
    name: "Planner",
    logging: {
      type: "file",
      path: logPath(repoRoot, "main-planner.log"),
    },
    agent: sandcastle.codex(PLANNER_MODEL, { effort: PLANNER_EFFORT }),
    promptFile: join(repoRoot, ".sandcastle", "plan-prompt.md"),
    promptArgs: {
      PRD_ISSUE_NUMBER: String(prdIssueNumber),
    },
  });

  return parsePlan(plan.stdout).issues.map((issue) => ({
    ...issue,
    branch: issueBranchName(issue),
  }));
};

export const implementAndReviewIssue = async (
  issue: IssuePlan,
  worktreePath: string,
  repoRoot: string,
  prdBranch: string
) => {
  const result = await sandcastle.run({
    cwd: repoRoot,
    sandbox: sandboxForRun(repoRoot, `implementer-${issue.number}`),
    branchStrategy: {
      type: "branch",
      branch: issue.branch,
      baseBranch: prdBranch,
    },
    name: "Implementer #" + issue.number,
    logging: {
      type: "file",
      path: logPath(
        repoRoot,
        `${issue.branch.replaceAll("/", "-")}-implementer-${issue.number}.log`
      ),
    },
    agent: sandcastle.codex(IMPLEMENTER_MODEL, {
      effort: IMPLEMENTER_EFFORT,
    }),
    promptFile: join(repoRoot, ".sandcastle", "implement-prompt.md"),
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
    cwd: repoRoot,
    sandbox: sandboxForRun(repoRoot, `reviewer-${issue.number}`),
    branchStrategy: {
      type: "branch",
      branch: issue.branch,
      baseBranch: prdBranch,
    },
    name: "Reviewer #" + issue.number,
    logging: {
      type: "file",
      path: logPath(
        repoRoot,
        `${issue.branch.replaceAll("/", "-")}-reviewer-${issue.number}.log`
      ),
    },
    agent: sandcastle.codex(REVIEWER_MODEL, {
      effort: REVIEWER_EFFORT,
    }),
    promptFile: join(repoRoot, ".sandcastle", "review-prompt.md"),
    promptArgs: {
      ISSUE_NUMBER: String(issue.number),
      ISSUE_TITLE: issue.title,
      BRANCH: issue.branch,
    },
  });

  return result;
};

export const mergeCompletedBranches = async (
  completedIssues: IssuePlan[],
  worktreePath: string,
  repoRoot: string,
  prdBranch: string
) => {
  const completedBranches = completedIssues.map((issue) => issue.branch);

  await sandcastle.run({
    cwd: worktreePath,
    sandbox: sandboxForRun(repoRoot, "merger"),
    branchStrategy: { type: "head" },
    name: "Merger",
    logging: {
      type: "file",
      path: logPath(repoRoot, "main-merger.log"),
    },
    maxIterations: 10,
    agent: sandcastle.codex(MERGER_MODEL, { effort: MERGER_EFFORT }),
    promptFile: join(repoRoot, ".sandcastle", "merge-prompt.md"),
    promptArgs: {
      PRD_BRANCH: prdBranch,
      BRANCHES: completedBranches.map((branch) => `- ${branch}`).join("\n"),
      ISSUES: completedIssues
        .map((issue) => `- #${issue.number}: ${issue.title}`)
        .join("\n"),
    },
  });

  await cleanupMergedIssueBranches(completedBranches, worktreePath);
};

export const runPrCreatorAgent = async (
  prdIssue: PrdIssue,
  worktreePath: string,
  repoRoot: string,
  prdBranch: string,
  baseBranch: string
) =>
  sandcastle.run({
    cwd: worktreePath,
    sandbox: sandboxForRun(repoRoot, "pr-creator"),
    branchStrategy: { type: "head" },
    name: "PR Creator",
    logging: {
      type: "file",
      path: logPath(repoRoot, "main-pr-creator.log"),
    },
    maxIterations: 5,
    agent: sandcastle.codex(FINALIZER_MODEL, { effort: FINALIZER_EFFORT }),
    promptFile: join(repoRoot, ".sandcastle", "final-pr-prompt.md"),
    promptArgs: {
      BASE_BRANCH: baseBranch,
      PRD_BRANCH: prdBranch,
      PRD_ISSUE_NUMBER: String(prdIssue.number),
      PRD_TITLE: prdIssue.title,
      PRD_URL: prdIssue.url,
    },
  });

const cleanupMergedIssueBranches = async (
  branches: string[],
  worktreePath: string
) => {
  for (const branch of branches) {
    const isMerged =
      (await tryRunCommand(
        "git",
        ["merge-base", "--is-ancestor", branch, "HEAD"],
        worktreePath
      )) !== undefined;
    if (!isMerged) {
      continue;
    }

    await tryRunCommand("git", ["branch", "-D", branch], worktreePath);
  }
};
