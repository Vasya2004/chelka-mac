#!/bin/bash
# Универсальный хук статуса для ИИ-агентов: Claude Code, Codex, Cursor, Kimi.
# Использование: boringnotch-agent-hook.sh <running|waiting|done|error|end|auto> [Имя агента]
# Если boringNotch не запущен, скрипт молча завершается и ничего не ломает.
#   auto — статус берётся из события агента (Cursor: поле status события stop)

STATUS="${1:-running}"
AGENT="${2:-Claude Code}"
INPUT="$(cat)"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"

PAYLOAD="$(STATUS="$STATUS" AGENT="$AGENT" INPUT="$INPUT" HOOK_DIR="$HOOK_DIR" /usr/bin/python3 - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["HOOK_DIR"])
from host_info import host_info

try:
    data = json.loads(os.environ.get("INPUT") or "{}")
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}

agent = os.environ["AGENT"]
status = os.environ["STATUS"]

# Cursor: событие stop несёт итог в поле status
if status == "auto":
    status = {"completed": "done", "aborted": "end", "error": "error"}.get(data.get("status"), "done")

# Единый идентификатор сессии и рабочая папка для разных агентов
sid = data.get("session_id") or data.get("conversation_id") or "session"
roots = data.get("workspace_roots") or []
cwd = data.get("cwd") or (roots[0] if roots else None) or os.environ.get("CURSOR_PROJECT_DIR")
# Для Claude Code идентификатор остаётся прежним, для остальных — с префиксом, чтобы сессии не пересекались
sid = sid if agent == "Claude Code" else f"{agent.lower().replace(' ', '-')}:{sid}"

task = None
if data.get("tool_name"):
    task = data["tool_name"]
elif data.get("command"):
    task = str(data["command"]).strip().splitlines()[0][:60]
elif data.get("prompt"):
    task = str(data["prompt"]).strip().splitlines()[0][:60]

host = host_info()
print(json.dumps({
    "id": sid,
    "agent": agent,
    "status": status,
    "task": task,
    "project": os.path.basename(cwd or "") or None,
    "cwd": cwd,
    "pids": host["pids"],
    "tty": host["tty"],
    "agentPid": host["agent_pid"],
    "transcript": data.get("transcript_path"),
}, ensure_ascii=False))
PY
)"

if [ -n "$BORINGNOTCH_DRY_RUN" ]; then echo "$PAYLOAD"; else
  curl -s -m 1 -o /dev/null -X POST "http://127.0.0.1:48217/agent" \
    -H "Content-Type: application/json" -d "$PAYLOAD" >/dev/null 2>&1
fi

# Claude Code: обновляем расход токенов для полосы лимитов (в фоне, не чаще раза в 3 минуты)
if [ "$AGENT" = "Claude Code" ] && [ -z "$BORINGNOTCH_DRY_RUN" ]; then
  STAMP="$HOME/.cache/boringnotch-claude-activity.stamp"
  mkdir -p "$(dirname "$STAMP")"
  if [ ! -f "$STAMP" ] || [ -n "$(find "$STAMP" -mmin +3 2>/dev/null)" ]; then
    touch "$STAMP"
    ( nice -n 10 /usr/bin/python3 "$HOOK_DIR/claude_activity.py" >/dev/null 2>&1 & )
  fi
fi

# Cursor ждёт ответ на beforeSubmitPrompt: просто разрешаем отправку, ничего не меняя
if echo "$INPUT" | grep -q '"hook_event_name" *: *"beforeSubmitPrompt"'; then
  echo '{"continue": true}'
fi
exit 0
