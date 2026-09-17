#!/usr/bin/env python3
"""Brief de tareas pendientes de Google Tasks al inicio de una sesion de Claude Code.

Modos:
  show     imprime el brief cacheado del working dir (instantaneo, hook sincronico)
  refresh  consulta el MCP global-tasks, resume con haiku y reescribe el cache (hook async)

El cache es por working dir, porque la separacion proyecto/globales depende del cwd.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

CACHE_DIR = Path(
    os.environ.get("CLAUDE_TASKS_BRIEF_CACHE") or Path.home() / ".claude" / "cache" / "tasks-brief"
)
CLAUDE_JSON = Path.home() / ".claude.json"
GUARD_ENV = "CLAUDE_TASKS_BRIEF"
MCP_SERVER = "global-tasks"
MCP_TIMEOUT = 45
HAIKU_TIMEOUT = 180
MIN_REFRESH_SECONDS = 1800  # no rehace el brief si el cache es mas nuevo que esto
EMPTY_BRIEF = "Sin tareas pendientes en Google Tasks."


def read_cwd():
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    return data.get("cwd") or os.getcwd()


def cache_path(cwd):
    key = hashlib.sha1(cwd.encode()).hexdigest()[:10]
    name = Path(cwd).name or "root"
    return CACHE_DIR / f"{name}-{key}.txt"


def emit(message=None):
    if not message:
        print("{}")
        return
    print(
        json.dumps(
            {
                "systemMessage": message,
                "suppressOutput": True,
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": message,
                },
            }
        )
    )


def age_label(seconds):
    if seconds < 90:
        return "hace un momento"
    if seconds < 3600:
        return f"hace {int(seconds // 60)} min"
    if seconds < 86400:
        return f"hace {int(seconds // 3600)} h"
    return f"hace {int(seconds // 86400)} d"


def show(cwd):
    path = cache_path(cwd)
    if not path.exists():
        emit("Tareas: primer brief en preparacion. Aparece en la proxima ventana.")
        return
    body = path.read_text(encoding="utf-8").strip()
    age = age_label(time.time() - path.stat().st_mtime)
    emit(f"{body}\n(cache {age})")


def mcp_pending_tasks():
    cfg = json.loads(CLAUDE_JSON.read_text(encoding="utf-8"))["mcpServers"][MCP_SERVER]
    env = dict(os.environ)
    env.update(cfg.get("env") or {})
    env[GUARD_ENV] = "1"
    requests = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "tasks-brief", "version": "1"},
            },
        },
        {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "list", "arguments": {}}},
    ]
    proc = subprocess.Popen(
        [cfg["command"], *cfg.get("args", [])],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        env=env,
        text=True,
    )
    payload = "".join(json.dumps(r) + "\n" for r in requests)
    try:
        out, _ = proc.communicate(payload, timeout=MCP_TIMEOUT)
    except subprocess.TimeoutExpired:
        proc.kill()
        raise
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get("id") != 2:
            continue
        content = (msg.get("result") or {}).get("content") or []
        return "\n".join(c.get("text", "") for c in content if c.get("type") == "text").strip()
    raise RuntimeError("el MCP global-tasks no devolvio resultado")


def build_prompt(cwd, tasks_text):
    project = Path(cwd).name or cwd
    today = datetime.now().strftime("%Y-%m-%d")
    return f"""Working dir: {cwd}
Proyecto del working dir: {project}
Hoy: {today}

Salida cruda del MCP global-tasks con las tareas de Google Tasks:
<<<
{tasks_text}
>>>

Escribi un resumen en texto plano, en espanol, sin markdown ni preambulo, con este formato exacto:

Tareas — {project}
- <titulo corto> — <dato clave>
Globales
- <titulo corto> — <dato clave>

Reglas:
- Incluí solo tareas con status needsAction.
- Una tarea va en la seccion del proyecto si su titulo o sus notas mencionan {project}; el resto van en Globales.
- Saca el prefijo del proyecto del titulo en la seccion del proyecto.
- El dato clave es el vencimiento, el bloqueo o el proximo paso. Una linea por tarea.
- Maximo 8 lineas por seccion. Si hay mas, cerra con "- (+N mas)".
- Si una seccion queda vacia, escribi "- (nada)".
- No agregues nada fuera de ese formato."""


def claude_bin():
    return shutil.which("claude") or str(Path.home() / ".local" / "bin" / "claude")


def summarize(prompt):
    env = dict(os.environ)
    env[GUARD_ENV] = "1"
    cmd = [
        claude_bin(),
        "-p",
        "--model",
        "haiku",
        "--no-session-persistence",
        "--disable-slash-commands",
        "--strict-mcp-config",
        "--mcp-config",
        '{"mcpServers":{}}',
    ]
    res = subprocess.run(
        cmd,
        input=prompt,
        capture_output=True,
        text=True,
        env=env,
        timeout=HAIKU_TIMEOUT,
    )
    if res.returncode != 0:
        raise RuntimeError(f"claude -p fallo: {res.stderr.strip()[:200]}")
    return res.stdout.strip()


def refresh(cwd):
    if os.environ.get(GUARD_ENV) == "1":
        return
    path = cache_path(cwd)
    fresh = path.exists() and time.time() - path.stat().st_mtime < MIN_REFRESH_SECONDS
    if fresh and os.environ.get("CLAUDE_TASKS_BRIEF_FORCE") != "1":
        return
    tasks_text = mcp_pending_tasks()
    if not tasks_text or "Found 0 tasks" in tasks_text:
        brief = EMPTY_BRIEF
    else:
        brief = summarize(build_prompt(cwd, tasks_text)) or EMPTY_BRIEF
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(brief + "\n", encoding="utf-8")
    tmp.replace(path)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "show"
    cwd = read_cwd()
    try:
        if mode == "refresh":
            refresh(cwd)
            print("{}")
        else:
            show(cwd)
    except Exception:
        print("{}")


if __name__ == "__main__":
    main()
