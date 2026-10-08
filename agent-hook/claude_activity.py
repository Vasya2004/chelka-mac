#!/usr/bin/env python3
"""Считает, сколько токенов израсходовано в Claude Code за 5 часов и за 7 дней (по журналам ~/.claude/projects),
и отправляет итог в boringNotch. Читает только поля usage и timestamp, текст сообщений не используется."""
import glob, json, os, sys, time, urllib.request
from datetime import datetime, timezone

now = time.time()
H5, D7 = 5 * 3600, 7 * 86400
LOOKBACK = 35 * 86400  # за какой период ищем «рекордные» окна
EVENT_DAYS = 9          # история для расчёта окон Claude (сессия 5 часов и неделя) — как её видит приложение
best = {}  # id сообщения -> (время, токены); одно сообщение пишется в журнал несколько раз при стриминге

for path in glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"), recursive=True):
    try:
        if now - os.path.getmtime(path) > LOOKBACK:
            continue
        with open(path, "r", errors="ignore") as f:
            for line in f:
                if '"usage"' not in line or '"assistant"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                msg = d.get("message") or {}
                u = msg.get("usage")
                ts = d.get("timestamp")
                if not isinstance(u, dict) or not ts:
                    continue
                try:
                    t = datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
                except Exception:
                    continue
                if now - t > LOOKBACK:
                    continue
                # кэш-чтения не считаем: они почти не расходуют лимит
                tokens = (u.get("input_tokens") or 0) + (u.get("output_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
                key = msg.get("id") or d.get("uuid")
                prev = best.get(key)
                if prev is None or tokens > prev[1]:
                    best[key] = (t, tokens)
    except Exception:
        continue

t5 = sum(tok for t, tok in best.values() if now - t <= H5)
t7 = sum(tok for t, tok in best.values() if now - t <= D7)

# Рекорды: самое «тяжёлое» скользящее окно в 5 часов и в 7 дней за период наблюдения
hours, days = {}, {}
for t, tok in best.values():
    hours[int(t // 3600)] = hours.get(int(t // 3600), 0) + tok
    days[int(t // 86400)] = days.get(int(t // 86400), 0) + tok
peak5 = max((sum(hours.get(h - k, 0) for k in range(5)) for h in hours), default=0)
peak7 = max((sum(days.get(d - k, 0) for k in range(7)) for d in days), default=0)
peak5, peak7 = max(peak5, t5), max(peak7, t7)

# История расхода: токены по 2-минутным интервалам (только непустые). По ней приложение само считает сессию и неделю.
buckets = {}
for t, tok in best.values():
    if now - t <= EVENT_DAYS * 86400:
        k = int(t // 120) * 120
        buckets[k] = buckets.get(k, 0) + tok
events = [[k, v] for k, v in sorted(buckets.items())]

payload = json.dumps({"provider": "claude", "activity": {"tokens_5h": t5, "tokens_7d": t7, "peak_5h": peak5, "peak_7d": peak7, "events": events}}).encode()
if os.environ.get("BORINGNOTCH_DRY_RUN"):
    print(payload.decode()); sys.exit(0)
try:
    req = urllib.request.Request("http://127.0.0.1:48217/usage", data=payload, headers={"Content-Type": "application/json"})
    urllib.request.urlopen(req, timeout=2).read()
except Exception:
    pass
