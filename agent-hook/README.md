# Agent hooks for Chelka

Chelka listens on `http://127.0.0.1:48217`. These scripts send it status events. They exit silently if Chelka is not running.

| Script | Purpose |
|---|---|
| `boringnotch-agent-hook.sh <status> [Agent name]` | Status events: `running`, `waiting`, `done`, `error`, `end`, `auto` (Cursor `stop`) |
| `boringnotch-permission-hook.sh` | Claude Code `PermissionRequest`: shows Allow/Deny in the notch and returns the answer |
| `boringnotch-statusline.sh` | Claude Code status line: forwards real rate limits (terminal sessions with a subscription) |
| `claude_activity.py` | Token usage for the last 5 hours / 7 days (called by the status hook, throttled) |
| `host_info.py` | Helper: process chain used to jump to the right window |
| `demo.sh [error\|waiting]` | Manual demo with a fake "Demo (тест)" agent |

Use absolute paths to the scripts below (replace `/path/to/chelka-mac`).

## Claude Code (`~/.claude/settings.json`)

```json
{
  "hooks": {
    "UserPromptSubmit": [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh running", "timeout": 5}]}],
    "PreToolUse":       [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh running", "timeout": 5}]}],
    "PermissionRequest":[{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-permission-hook.sh", "timeout": 330}]}],
    "Notification":     [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh waiting", "timeout": 5}]}],
    "Stop":             [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh done", "timeout": 5}]}],
    "StopFailure":      [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh error", "timeout": 5}]}],
    "SessionEnd":       [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh end", "timeout": 5}]}]
  },
  "statusLine": {"type": "command", "command": "/path/to/chelka-mac/agent-hook/boringnotch-statusline.sh"}
}
```

Merge these into your existing `hooks` instead of replacing them.

## Codex

Chelka detects Codex automatically from `~/.codex/sessions`. Hooks are optional (Codex asks you to approve new hooks with `/hooks`).

## Cursor (`~/.cursor/hooks.json`)

Add `{"command": ".../boringnotch-agent-hook.sh running Cursor"}` under `beforeSubmitPrompt`, `afterAgentThought`, `afterFileEdit`, `afterShellExecution`, `afterMCPExecution`, and `{"command": ".../boringnotch-agent-hook.sh auto Cursor"}` under `stop`.

## Kimi (`~/.kimi/config.toml`)

```toml
[[hooks]]
event = "UserPromptSubmit"
command = "/path/to/chelka-mac/agent-hook/boringnotch-agent-hook.sh running Kimi"
timeout = 5
```

Repeat for `PreToolUse`/`PostToolUse` (`running`), `Stop` (`done`), `SessionEnd` (`end`).
