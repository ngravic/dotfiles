#!/usr/bin/env python3
"""Brief de tareas pendientes de Google Tasks al inicio de una sesion de Claude Code.

Modos:
  show        imprime el brief cacheado del working dir (instantaneo, hook sincronico)
  refresh     consulta el MCP global-tasks, resume con haiku y reescribe el cache (hook async)
  now [pedido] como refresh pero sincronico, sin mirar la edad del cache, e imprime el brief
              en texto plano (comando /pending-tasks). Con un pedido no vacio hace lo mismo
              que raw.
  raw         imprime todas las listas con estado y notas, sin haiku ni cache, para que Claude
              arme la vista que pide el usuario
  ensure-list [proyecto]
              imprime el id de la lista del proyecto (por defecto el del working dir) y la crea
              si no existe. El MCP no crea listas: esto llama directo a la API de Google Tasks
              con las credenciales del MCP

Cada proyecto tiene su lista en Google Tasks, con el nombre de la carpeta del repo. Las tareas
sin proyecto van a la lista general, que el brief muestra como Globales. El estado sale de
cada tarea: pendiente sin marca es Por hacer, pendiente con "▶ " al principio del titulo es
En curso y completada es Hecha.

El cache es por working dir, porque la seccion del proyecto depende del cwd.
"""

import hashlib
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

CACHE_DIR = Path(
    os.environ.get("CLAUDE_TASKS_BRIEF_CACHE") or Path.home() / ".claude" / "cache" / "tasks-brief"
)
CLAUDE_JSON = Path.home() / ".claude.json"
GUARD_ENV = "CLAUDE_TASKS_BRIEF"
MCP_SERVER = "global-tasks"
MCP_TIMEOUT = 60
HAIKU_TIMEOUT = 180
GIT_TIMEOUT = 5
API_TIMEOUT = 20
TOKEN_URL = "https://oauth2.googleapis.com/token"
TASK_LISTS_URL = "https://tasks.googleapis.com/tasks/v1/users/@me/lists"
MIN_REFRESH_SECONDS = 1800  # no rehace el brief si el cache es mas nuevo que esto
GENERAL_LIST = "Mis tareas"
IN_PROGRESS_MARK = "▶"
MAX_LINES = 8  # tareas por seccion del brief
MAX_DONE = 10  # hechas por lista en el modo raw
MAX_RAW_NOTES = 240
MAX_PROMPT_NOTES = 1500
UNDERLINE_CYAN = "\033[4;36m"
BOLD_RED = "\033[1;31m"
WHITE = "\033[97m"
RESET = "\033[0m"

TODO = "Por hacer"
IN_PROGRESS = "En curso"
DONE = "Hecha"

TASK_LIST_LINE = re.compile(r"^- (?P<title>.*?) \| id:(?P<id>\S+)")
TREE_LINE = re.compile(
    r"^\s*\[(?P<mark>[ x])\] (?P<title>.*?)(?: \(due: (?P<due>[^)]*)\))? \| id:(?P<id>\S+)\s*$"
)
NOTES_CHUNK = re.compile(r"\) - Notes: (?P<notes>.*?) - ID: (?P<id>[\w-]+) - Status:", re.S)


@dataclass(frozen=True)
class Task:
    id: str
    list_title: str
    title: str  # sin la marca de En curso
    state: str
    due: str = ""
    notes: str = ""


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


def project_from_common_dir(common_dir):
    """Carpeta del repo a partir del git common dir. En un repo con .bare es la que lo contiene."""
    if common_dir.name in (".git", ".bare"):
        return common_dir.parent.name
    return common_dir.name.removesuffix(".git")


def git_common_dir(cwd):
    try:
        res = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"],
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    out = res.stdout.strip()
    return Path(out) if res.returncode == 0 and out else None


def project_name(cwd):
    common_dir = git_common_dir(cwd)
    if common_dir:
        return project_from_common_dir(common_dir)
    return Path(cwd).name or cwd


def emit(message=None, display=None):
    """display es la version con color para la terminal; a Claude le llega message."""
    if not message:
        print("{}")
        return
    print(
        json.dumps(
            {
                "systemMessage": display or message,
                "suppressOutput": True,
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": message,
                },
            }
        )
    )


def paint(color, text):
    return f"{color}{text}{RESET}"


def line_color(line):
    if not line.startswith("- "):
        return UNDERLINE_CYAN
    if "Vencid" in line:
        return BOLD_RED
    return WHITE


def colorize(body):
    """Titulos de seccion en cian subrayado, tareas vencidas en rojo y el resto en blanco."""
    return "\n".join(paint(line_color(line), line) for line in body.splitlines())


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
    footer = f"(cache {age_label(time.time() - path.stat().st_mtime)})"
    emit(f"{body}\n{footer}", display=f"\n{colorize(body)}\n{paint(WHITE, footer)}")


def mcp_config():
    return json.loads(CLAUDE_JSON.read_text(encoding="utf-8"))["mcpServers"][MCP_SERVER]


class McpSession:
    """Cliente minimo del MCP global-tasks por stdio: un pedido por vez, con un plazo total."""

    def __init__(self):
        cfg = mcp_config()
        env = dict(os.environ)
        env.update(cfg.get("env") or {})
        env[GUARD_ENV] = "1"
        self.proc = subprocess.Popen(
            [cfg["command"], *cfg.get("args", [])],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=env,
            text=True,
        )
        self.lines = queue.Queue()
        self.deadline = time.monotonic() + MCP_TIMEOUT
        self.next_id = 1
        threading.Thread(target=self._pump, daemon=True).start()

    def __enter__(self):
        try:
            self.request(
                "initialize",
                {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "tasks-brief", "version": "2"},
                },
            )
            self._send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
        except Exception:
            self.__exit__()
            raise
        return self

    def __exit__(self, *exc):
        # cerrar stdin le da EOF al server de node que lanza npx; matar solo npx lo dejaria vivo
        try:
            self.proc.stdin.close()
            self.proc.wait(timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            self.proc.kill()
            self.proc.wait()

    def _pump(self):
        for line in self.proc.stdout:
            self.lines.put(line)
        self.lines.put(None)

    def _send(self, message):
        self.proc.stdin.write(json.dumps(message) + "\n")
        self.proc.stdin.flush()

    def _next_message(self):
        remaining = self.deadline - time.monotonic()
        try:
            line = self.lines.get(timeout=max(remaining, 0))
        except queue.Empty:
            raise TimeoutError("el MCP global-tasks no respondio a tiempo") from None
        if line is None:
            raise RuntimeError("el MCP global-tasks se cerro")
        try:
            return json.loads(line)
        except ValueError:
            return {}

    def request(self, method, params):
        request_id = self.next_id
        self.next_id += 1
        self._send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        while True:
            msg = self._next_message()
            if msg.get("id") != request_id:
                continue
            if "error" in msg:
                raise RuntimeError(f"el MCP global-tasks fallo: {msg['error']}")
            return msg.get("result") or {}

    def call_tool(self, name, arguments):
        result = self.request("tools/call", {"name": name, "arguments": arguments})
        content = result.get("content") or []
        text = "\n".join(c.get("text", "") for c in content if c.get("type") == "text").strip()
        if result.get("isError"):
            raise RuntimeError(f"{name} fallo: {text[:200]}")
        return text


def parse_task_lists(text):
    """Salida de list_task_lists -> [(id, titulo)]."""
    matches = (TASK_LIST_LINE.match(line) for line in text.splitlines())
    return [(m["id"], m["title"]) for m in matches if m]


def parse_notes(text):
    """Salida de list -> {id: notas}. Es la unica herramienta del MCP que trae las notas."""
    return {
        m["id"]: m["notes"].strip()
        for m in NOTES_CHUNK.finditer(text)
        if m["notes"].strip() not in ("", "undefined")
    }


def task_state(mark, title):
    if mark == "x":
        return DONE, title
    if title.startswith(IN_PROGRESS_MARK):
        return IN_PROGRESS, title[len(IN_PROGRESS_MARK) :].strip()
    return TODO, title


def parse_tree(list_title, text, notes):
    """Salida de list_with_tree -> [Task]. Las subtareas quedan en la misma lista, sin anidar."""
    tasks = []
    for line in text.splitlines():
        m = TREE_LINE.match(line)
        if not m:
            continue
        state, title = task_state(m["mark"], m["title"])
        due = (m["due"] or "")[:10]
        tasks.append(Task(m["id"], list_title, title, state, due, notes.get(m["id"], "")))
    return tasks


def fetch_tasks():
    """Todas las tareas de todas las listas, con las hechas incluidas."""
    with McpSession() as mcp:
        lists = parse_task_lists(mcp.call_tool("list_task_lists", {}))
        notes = parse_notes(mcp.call_tool("list", {}))
        tasks = []
        for list_id, list_title in lists:
            tree = mcp.call_tool(
                "list_with_tree", {"taskListId": list_id, "showCompleted": True, "showHidden": True}
            )
            tasks.extend(parse_tree(list_title, tree, notes))
    return lists, tasks


def brief_groups(tasks, project):
    """(En curso, Por hacer) de la lista del proyecto y pendientes de la lista general."""
    own = [t for t in tasks if t.list_title == project]
    general = [t for t in tasks if t.list_title == GENERAL_LIST and t.state != DONE]
    return (
        [t for t in own if t.state == IN_PROGRESS],
        [t for t in own if t.state == TODO],
        sorted(general, key=lambda t: t.state != IN_PROGRESS),
    )


def today():
    return datetime.now().strftime("%Y-%m-%d")


def default_line(task, day):
    if not task.due:
        return task.title
    label = "Vencida" if task.due < day else "vence"
    return f"{task.title} — {label} {task.due}"


def task_lines(group, lines, mark_in_progress=False):
    day = today()
    shown = []
    for t in group[:MAX_LINES]:
        mark = f"{IN_PROGRESS_MARK} " if mark_in_progress and t.state == IN_PROGRESS else ""
        shown.append(f"- {mark}{lines.get(t.id) or default_line(t, day)}")
    extra = len(group) - MAX_LINES
    return shown + ([f"- (+{extra} más)"] if extra > 0 else [])


def render_brief(project, has_list, groups, lines):
    """lines da la linea de cada tarea por id; las que faltan usan default_line."""
    in_progress, todo, general = groups
    out = [f"Tareas — {project}"]
    if not has_list:
        out.append(f"- (no hay lista {project} en Google Tasks)")
    elif not in_progress and not todo:
        out.append("- (nada)")
    for heading, group in ((IN_PROGRESS, in_progress), (TODO, todo)):
        if group:
            out += [heading, *task_lines(group, lines)]
    out += ["Globales", *(task_lines(general, lines, mark_in_progress=True) or ["- (nada)"])]
    return "\n".join(out)


def build_summary_prompt(tasks, day):
    items = []
    for n, t in enumerate(tasks, 1):
        notes = " ".join(t.notes.split())[:MAX_PROMPT_NOTES] or "(sin notas)"
        items.append(f"{n}. Titulo: {t.title} | Vence: {t.due or 'sin fecha'} | Notas: {notes}")
    listing = "\n".join(items)
    return f"""Hoy: {day}

Para cada tarea escribi una linea corta en espanol: "<titulo corto> — <dato clave>".

Reglas:
- El titulo corto resume el titulo en pocas palabras.
- El dato clave es el vencimiento, el bloqueo o el proximo paso. Si no hay ninguno, escribi "Sin información".
- Si la tarea ya vencio, el dato clave empieza con "Vencida".
- Responde solo con un objeto JSON que va del numero de tarea a su linea, por ejemplo {{"1": "...", "2": "..."}}.

Tareas:
{listing}"""


def parse_summary(reply, tasks):
    """Respuesta de haiku -> {id: linea}. Si no es JSON valido, no hay lineas."""
    start, end = reply.find("{"), reply.rfind("}")
    try:
        data = json.loads(reply[start : end + 1]) if start >= 0 else {}
    except ValueError:
        return {}
    if not isinstance(data, dict):
        return {}
    by_number = {str(n): t.id for n, t in enumerate(tasks, 1)}
    return {
        by_number[k]: " ".join(v.split())
        for k, v in data.items()
        if k in by_number and isinstance(v, str) and v.strip()
    }


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


def summary_lines(tasks):
    """Linea de haiku por tarea. Si haiku falla, el brief sale igual con default_line."""
    if not tasks:
        return {}
    try:
        return parse_summary(summarize(build_summary_prompt(tasks, today())), tasks)
    except Exception:
        return {}


def build_brief(cwd):
    project = project_name(cwd)
    lists, tasks = fetch_tasks()
    groups = brief_groups(tasks, project)
    visible = [t for group in groups for t in group[:MAX_LINES]]
    has_list = any(title == project for _, title in lists)
    return render_brief(project, has_list, groups, summary_lines(visible))


def raw_task_lines(task):
    due = f" (vence {task.due})" if task.due else ""
    out = [f"- [{task.state}] {task.title}{due}"]
    notes = " ".join(task.notes.split())
    if notes:
        cut = "…" if len(notes) > MAX_RAW_NOTES else ""
        out.append(f"  Notas: {notes[:MAX_RAW_NOTES]}{cut}")
    return out


def raw_listing(tasks, lists, project):
    """Todas las listas completas. Las hechas van al final de cada lista, hasta MAX_DONE."""
    out = [f"Tareas por lista (hoy {today()}, proyecto actual {project})"]
    for _, list_title in lists:
        own = [t for t in tasks if t.list_title == list_title]
        pending = [t for t in own if t.state != DONE]
        done = [t for t in own if t.state == DONE]
        suffix = " (Globales)" if list_title == GENERAL_LIST else ""
        out += ["", f"## {list_title}{suffix}"]
        for t in sorted(pending, key=lambda t: t.state != IN_PROGRESS) + done[:MAX_DONE]:
            out += raw_task_lines(t)
        if len(done) > MAX_DONE:
            out.append(f"- (+{len(done) - MAX_DONE} hechas más)")
        if not own:
            out.append("- (vacía)")
    return "\n".join(out)


def find_list(lists, name):
    return next((list_id for list_id, title in lists if title == name), None)


def google_access_token():
    env = mcp_config().get("env") or {}
    data = urllib.parse.urlencode(
        {
            "client_id": env["GOOGLE_CLIENT_ID"],
            "client_secret": env["GOOGLE_CLIENT_SECRET"],
            "refresh_token": env["GOOGLE_REFRESH_TOKEN"],
            "grant_type": "refresh_token",
        }
    ).encode()
    with urllib.request.urlopen(TOKEN_URL, data, timeout=API_TIMEOUT) as res:
        return json.load(res)["access_token"]


def create_task_list(title):
    req = urllib.request.Request(
        TASK_LISTS_URL,
        data=json.dumps({"title": title}).encode(),
        headers={
            "Authorization": f"Bearer {google_access_token()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=API_TIMEOUT) as res:
        return json.load(res)["id"]


def ensure_list(name):
    """(id, creada) de la lista con ese nombre. La crea si no existe."""
    with McpSession() as mcp:
        list_id = find_list(parse_task_lists(mcp.call_tool("list_task_lists", {})), name)
    if list_id:
        return list_id, False
    return create_task_list(name), True


def write_cache(path, brief):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(brief + "\n", encoding="utf-8")
    tmp.replace(path)


def refresh(cwd):
    if os.environ.get(GUARD_ENV) == "1":
        return
    path = cache_path(cwd)
    fresh = path.exists() and time.time() - path.stat().st_mtime < MIN_REFRESH_SECONDS
    if fresh and os.environ.get("CLAUDE_TASKS_BRIEF_FORCE") != "1":
        return
    write_cache(path, build_brief(cwd))


def now(cwd):
    brief = build_brief(cwd)
    write_cache(cache_path(cwd), brief)
    print(brief)


def raw(cwd):
    lists, tasks = fetch_tasks()
    print(raw_listing(tasks, lists, project_name(cwd)))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "show"
    if mode == "ensure-list":
        name = " ".join(sys.argv[2:]).strip() or project_name(os.getcwd())
        try:
            list_id, created = ensure_list(name)
        except Exception as exc:
            print(f"No pude asegurar la lista {name}: {exc}")
            sys.exit(1)
        print(f"{list_id}\t{name}\t{'creada' if created else 'existente'}")
        return
    if mode in ("now", "raw"):
        # lo corre /pending-tasks: no hay JSON en stdin y el error tiene que verse
        has_request = bool(" ".join(sys.argv[2:]).strip())
        try:
            if mode == "raw" or has_request:
                raw(os.getcwd())
            else:
                now(os.getcwd())
        except Exception as exc:
            print(f"No pude traer las tareas: {exc}")
        return
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
