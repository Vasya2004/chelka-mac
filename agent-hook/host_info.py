"""Общая часть хуков boringNotch: цепочка родительских процессов агента и его tty.

boringNotch по цепочке находит приложение, в котором работает агент
(Claude, Terminal, iTerm2, VS Code...), и переходит в него по клику.
"""
import os
import subprocess


def host_info():
    pids = []
    tty = None
    pid = os.getppid()
    for _ in range(40):
        if pid <= 1:
            break
        pids.append(pid)
        try:
            out = subprocess.run(
                ["ps", "-o", "ppid=,tty=", "-p", str(pid)],
                capture_output=True, text=True, timeout=2,
            ).stdout.split()
        except Exception:
            break
        if len(out) < 2:
            break
        ppid, term = out[0], out[1]
        if tty is None and term not in ("??", "?"):
            tty = "/dev/" + term if not term.startswith("/") else term
        try:
            pid = int(ppid)
        except ValueError:
            break
    return {"pids": pids, "tty": tty}
