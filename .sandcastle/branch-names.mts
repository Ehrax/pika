import type { PlannedIssue, PrdIssue } from "./workflow-types.mts";

const slugify = (value: string) =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 72);

export const issueBranchName = (issue: PlannedIssue) =>
  `sandcastle/issue-${issue.number}-${slugify(issue.title)}`;

export const prdBranchName = (issue: PrdIssue) =>
  process.env.SANDCASTLE_PR_BRANCH ??
  `sandcastle/prd-${issue.number}-${slugify(issue.title)}`;
