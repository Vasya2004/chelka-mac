#!/bin/bash
# Строка состояния Claude Code: передаёт остаток лимитов (5 часов и неделя) в boringNotch
# и выводит их короткой строкой. Если лимитов в данных нет (например, API-ключ вместо подписки), ничего не выводит.
input="$(cat)"

OUT="$(INPUT="$input" /usr/bin/python3 - <<'PY'
import json, os, sys
try:
    data = json.loads(os.environ.get("INPUT") or "{}")
except Exception:
    sys.exit(0)
limits = data.get("rate_limits")
if not isinstance(limits, dict):
    sys.exit(0)
def left(key):
    w = limits.get(key)
    if isinstance(w, dict) and isinstance(w.get("used_percentage"), (int, float)):
        return round(100 - min(max(w["used_percentage"], 0), 100))
    return None
five, week = left("five_hour"), left("seven_day")
parts = []
if five is not None: parts.append(f"5h {five}% left")
if week is not None: parts.append(f"week {week}% left")
# первая строка — полезная нагрузка для boringNotch, вторая — текст для строки состояния
print(json.dumps({"provider": "claude", "rate_limits": limits}))
print(" · ".join(parts))
PY
)"

[ -z "$OUT" ] && exit 0
PAYLOAD="$(echo "$OUT" | sed -n 1p)"
TEXT="$(echo "$OUT" | sed -n 2p)"
curl -s -m 1 -o /dev/null -X POST "http://127.0.0.1:48217/usage" \
  -H "Content-Type: application/json" -d "$PAYLOAD" >/dev/null 2>&1
[ -n "$TEXT" ] && echo "$TEXT"
exit 0
