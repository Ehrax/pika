import { docker } from "@ai-hero/sandcastle/sandboxes/docker";

export const codexAuthHook = {
  command:
    'mkdir -p "$CODEX_HOME" && cp /mnt/host-codex/auth.json "$CODEX_HOME/auth.json" && chmod 600 "$CODEX_HOME/auth.json" && if [ -f /mnt/host-codex/config.toml ]; then cp /mnt/host-codex/config.toml "$CODEX_HOME/config.toml"; fi',
};

export const codexDocker = docker({
  env: {
    CODEX_HOME: "/codex-home",
    GIT_CONFIG_GLOBAL: "/codex-home/.gitconfig",
  },
  mounts: [
    {
      hostPath: "~/.codex",
      sandboxPath: "/mnt/host-codex",
      readonly: true,
    },
    {
      hostPath: ".sandcastle/codex-home",
      sandboxPath: "/codex-home",
    },
  ],
});
