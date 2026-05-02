import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { chmod, copyFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";
import type { PrdIssue } from "./workflow-types.mts";

const execFileAsync = promisify(execFile);

export const runCommand = async (
  command: string,
  args: string[],
  cwd = process.cwd()
) => {
  const { stdout } = await execFileAsync(command, args, {
    cwd,
    maxBuffer: 1024 * 1024 * 20,
  });
  return stdout.trim();
};

export const tryRunCommand = async (
  command: string,
  args: string[],
  cwd = process.cwd()
) => {
  try {
    return await runCommand(command, args, cwd);
  } catch {
    return undefined;
  }
};

export const currentBranch = async () =>
  process.env.SANDCASTLE_BASE_BRANCH ??
  (await runCommand("git", ["rev-parse", "--abbrev-ref", "HEAD"]));

export const readPrdIssue = async (
  issueNumber: number
): Promise<PrdIssue> =>
  JSON.parse(
    await runCommand("gh", [
      "issue",
      "view",
      String(issueNumber),
      "--json",
      "number,title,body,url",
    ])
  ) as PrdIssue;

export const copyLocalEnvToWorktree = async (
  repoRoot: string,
  worktreePath: string
) => {
  const source = join(repoRoot, ".sandcastle", ".env");
  if (!existsSync(source)) {
    return;
  }

  const targetDir = join(worktreePath, ".sandcastle");
  await mkdir(targetDir, { recursive: true });
  const target = join(targetDir, ".env");
  await copyFile(source, target);
  await chmod(target, 0o600);
};

export const cleanupPrdWorktree = async (worktreePath: string) => {
  const worktrees = await runCommand("git", ["worktree", "list", "--porcelain"]);
  const nestedWorktrees = worktrees
    .split("\n")
    .filter((line) => line.startsWith("worktree "))
    .map((line) => line.slice("worktree ".length).trim())
    .filter((path) =>
      path.startsWith(join(worktreePath, ".sandcastle", "worktrees"))
    );

  for (const nestedWorktree of nestedWorktrees) {
    await tryRunCommand("git", ["worktree", "remove", "--force", nestedWorktree]);
  }

  await runCommand("git", ["worktree", "remove", "--force", worktreePath]);
  await runCommand("git", ["worktree", "prune"]);
};
