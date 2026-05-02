import * as sandcastle from "@ai-hero/sandcastle";
import { prdBranchName } from "./branch-names.mts";
import { copyLocalEnvToWorktree } from "./git-helpers.mts";
import type { PrdIssue, PrdWorktree } from "./workflow-types.mts";

export const createPrdWorktree = async (
  prdIssue: PrdIssue,
  baseBranch: string,
  repoRoot: string
): Promise<PrdWorktree> => {
  const branch = prdBranchName(prdIssue);
  const worktree = await sandcastle.createWorktree({
    branchStrategy: { type: "branch", branch, baseBranch },
  });
  await copyLocalEnvToWorktree(repoRoot, worktree.worktreePath);
  return { branch, worktreePath: worktree.worktreePath };
};
