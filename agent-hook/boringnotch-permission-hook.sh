#!/bin/bash
# Хук PermissionRequest для Claude Code: показывает запрос разрешения в «чёлке» boringNotch
# и возвращает ответ «Allow / Deny». Если boringNotch не запущен, выключено в настройках,
# вы не ответили за 5 минут или ответили в терминале — скрипт ничего не выводит,
# и Claude Code работает как обычно (спросит в терминале).

INPUT="$(cat)"

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"

PAYLOAD="$(INPUT="$INPUT" HOOK_DIR="$HOOK_DIR" /usr/bin/python3 - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["HOOK_DIR"])
from host_info import host_info
try:
    data = json.loads(os.environ.get("INPUT") or "{}")
except Exception:
    sys.exit(0)
tool = data.get("tool_name") or ""
# Вопросы агента и план — не разрешение на действие, их оставляем терминалу
if tool in ("AskUserQuestion", "ExitPlanMode"):
    sys.exit(0)
inp = data.get("tool_input") or {}
if tool == "Bash":
    detail = inp.get("command", "")
elif inp.get("file_path"):
    detail = inp["file_path"]
elif inp.get("url"):
    detail = inp["url"]
elif inp.get("query"):
    detail = inp["query"]
elif inp.get("description"):
    detail = inp["description"]
else:
    detail = json.dumps(inp, ensure_ascii=False)
# Правила «всегда разрешать», которые предлагает сам Claude Code: вернём их в ответе, если нажмут «Always»
suggestions = data.get("permission_suggestions") or []
suggestion_text = None
for entry in suggestions:
    if entry.get("type") == "addRules":
        parts = []
        for rule in entry.get("rules") or []:
            name = rule.get("toolName") or ""
            content = rule.get("ruleContent")
            parts.append(f"{name}({content})" if content else name)
        if parts:
            suggestion_text = ", ".join(parts)[:120]
            break
    elif entry.get("type") == "setMode":
        suggestion_text = f"mode: {entry.get('mode')}"
        break
    elif entry.get("type") == "addDirectories":
        suggestion_text = "directory: " + ", ".join(entry.get("directories") or [])[:100]
        break
host = host_info("Claude Code")
print(json.dumps({
    "id": data.get("session_id") or "claude-code",
    "agent": "Claude Code",
    "project": os.path.basename(data.get("cwd") or "") or None,
    "tool": tool,
    "detail": detail[:600],
    "cwd": data.get("cwd"),
    "pids": host["pids"],
    "tty": host["tty"],
    "suggestions": suggestions,
    "suggestionText": suggestion_text,
}, ensure_ascii=False))
PY
)"

[ -z "$PAYLOAD" ] && exit 0

RESPONSE="$(curl -s -m 300 -w '\n%{http_code}' -X POST "http://127.0.0.1:48217/permission" \
  -H "Content-Type: application/json" -d "$PAYLOAD" 2>/dev/null)"
CODE="${RESPONSE##*$'\n'}"
BODY="${RESPONSE%$'\n'*}"

if [ "$CODE" = "200" ] && [ -n "$BODY" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":%s}}\n' "$BODY"
fi
exit 0
