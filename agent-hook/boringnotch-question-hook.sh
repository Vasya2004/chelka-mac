#!/bin/bash
# Хук PreToolUse для Claude Code (matcher: AskUserQuestion|ExitPlanMode): когда агент задаёт вопрос с вариантами
# ответа или просит утвердить план, карточка появляется в «чёлке» Chelka. Ответ из «чёлки» возвращается агенту
# вместо диалога в терминале. Если Chelka не запущена, функция выключена, вы нажали «In terminal» или не ответили
# за 5 минут — скрипт ничего не выводит, и Claude Code спросит как обычно.

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
inp = data.get("tool_input") or {}
if tool == "AskUserQuestion":
    kind = "question"
elif tool == "ExitPlanMode":
    kind = "plan"
else:
    sys.exit(0)
host = host_info("Claude Code")
print(json.dumps({
    "id": data.get("session_id") or "claude-code",
    "agent": "Claude Code",
    "project": os.path.basename(data.get("cwd") or "") or None,
    "tool": tool,
    "kind": kind,
    "questions": inp.get("questions") if kind == "question" else None,
    "plan": (inp.get("plan") or "")[:4000] if kind == "plan" else None,
    "detail": "",
    "cwd": data.get("cwd"),
    "pids": host["pids"],
    "tty": host["tty"],
}, ensure_ascii=False))
PY
)"

[ -z "$PAYLOAD" ] && exit 0

RESPONSE="$(curl -s -m 300 -w '\n%{http_code}' -X POST "http://127.0.0.1:48217/permission" \
  -H "Content-Type: application/json" -d "$PAYLOAD" 2>/dev/null)"
CODE="${RESPONSE##*$'\n'}"
BODY="${RESPONSE%$'\n'*}"

if [ "$CODE" = "200" ] && [ -n "$BODY" ]; then
  INPUT="$INPUT" BODY="$BODY" /usr/bin/python3 - <<'PY'
import json, os
try:
    data = json.loads(os.environ["INPUT"])
    reply = json.loads(os.environ["BODY"])
except Exception:
    raise SystemExit(0)
tool_input = data.get("tool_input") or {}
if "answers" in reply:
    # Вопросы: возвращаем исходные вопросы и добавляем выбранные ответы
    out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow",
                                  "updatedInput": {**tool_input, "answers": reply["answers"]}}}
elif reply.get("behavior") == "allow":
    # План утверждён
    out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": tool_input}}
else:
    out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                  "permissionDecisionReason": reply.get("message") or "Declined from Chelka"}}
print(json.dumps(out, ensure_ascii=False))
PY
fi
exit 0
