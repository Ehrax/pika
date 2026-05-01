import { spawn } from "node:child_process";

export type HostCommandResult = {
  command: string;
  exitCode: number;
  output: string;
};

export type HostVerificationResult = {
  ok: boolean;
  results: HostCommandResult[];
};

export const hostVerifyCommandsFromEnv = (
  envName: string,
  fallback: string[]
) =>
  process.env[envName]?.split("\n")
    .map((command) => command.trim())
    .filter(Boolean) ?? fallback;

export const truncateOutput = (output: string, maxLength = 24_000) =>
  output.length <= maxLength
    ? output
    : output.slice(output.length - maxLength);

export const runHostCommand = (
  command: string,
  cwd: string,
  maxOutputLength?: number
) =>
  new Promise<HostCommandResult>((resolve, reject) => {
    const child = spawn("bash", ["-lc", command], {
      cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });

    const outputChunks: string[] = [];
    child.stdout.on("data", (chunk) => outputChunks.push(chunk.toString()));
    child.stderr.on("data", (chunk) => outputChunks.push(chunk.toString()));
    child.on("error", reject);
    child.on("close", (code) => {
      resolve({
        command,
        exitCode: code ?? 0,
        output: truncateOutput(outputChunks.join(""), maxOutputLength),
      });
    });
  });

export const runHostVerification = async (
  worktreePath: string,
  commands: string[],
  label = "Host verify"
): Promise<HostVerificationResult> => {
  const results: HostCommandResult[] = [];

  for (const command of commands) {
    console.log(`\n${label}: ${command}`);
    const result = await runHostCommand(command, worktreePath);
    results.push(result);

    if (result.output.trim()) {
      console.log(result.output);
    }

    if (result.exitCode !== 0) {
      return { ok: false, results };
    }
  }

  return { ok: true, results };
};

export const formatVerificationFailure = (
  verification: HostVerificationResult
) =>
  verification.results
    .filter((result) => result.exitCode !== 0)
    .map(
      (result) => `Command: ${result.command}
Exit code: ${result.exitCode}

Output:
${result.output}`
    )
    .join("\n\n---\n\n");
