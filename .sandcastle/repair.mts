import * as sandcastle from "@ai-hero/sandcastle";
import {
  IMPLEMENTER_EFFORT,
  IMPLEMENTER_MODEL,
  MAX_REPAIR_ATTEMPTS,
} from "./agent-config.mts";
import {
  formatVerificationFailure,
  runHostVerification,
} from "./host-verification.mts";

type IssuePlan = {
  number: number;
  title: string;
  branch: string;
};

type SandcastleSandbox = Awaited<ReturnType<typeof sandcastle.createSandbox>>;

export const verifyAndRepair = async (
  sandbox: SandcastleSandbox,
  issue: IssuePlan,
  stage: string,
  hostVerifyCommands: string[]
) => {
  for (let attempt = 0; attempt <= MAX_REPAIR_ATTEMPTS; attempt++) {
    const verification = await runHostVerification(
      sandbox.worktreePath,
      hostVerifyCommands
    );

    if (verification.ok) {
      console.log(`Host verification passed after ${stage}.`);
      return;
    }

    if (attempt === MAX_REPAIR_ATTEMPTS) {
      throw new Error(
        `Host verification failed after ${stage} for #${issue.number}.\n\n` +
          formatVerificationFailure(verification)
      );
    }

    console.log(
      `Host verification failed after ${stage}; asking agent to repair #${issue.number}.`
    );

    await sandbox.run({
      name: "Repair #" + issue.number,
      agent: sandcastle.codex(IMPLEMENTER_MODEL, {
        effort: IMPLEMENTER_EFFORT,
      }),
      prompt: `Fix the host verification failures for issue #${issue.number}: ${issue.title}.

You are on branch ${issue.branch}. The previous implementation/review pass produced commits, but host-side verification failed on macOS outside the Docker sandbox.

Read the failure output below, inspect the relevant Swift files and tests, make the smallest correct fix, run portable checks such as git diff --check if useful, and commit your fix. Do not run Node/TypeScript substitutes.

<host-verification-failure>
${formatVerificationFailure(verification)}
</host-verification-failure>

Once complete, output <promise>COMPLETE</promise>.`,
    });
  }
};
