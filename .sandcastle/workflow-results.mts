import * as sandcastle from "@ai-hero/sandcastle";
import type { IssuePlan } from "./workflow-types.mts";

export const completedIssuesFromSettled = (
  settled: PromiseSettledResult<Awaited<ReturnType<typeof sandcastle.run>>>[],
  issues: IssuePlan[]
) =>
  settled
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
