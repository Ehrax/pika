export type PlannedIssue = {
  number: number;
  title: string;
};

export type IssuePlan = PlannedIssue & {
  branch: string;
};

export type PrdIssue = {
  number: number;
  title: string;
  body: string;
  url: string;
};

export type PrdWorktree = {
  branch: string;
  worktreePath: string;
};
