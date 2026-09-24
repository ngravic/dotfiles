# claude

Configuración de Claude Code. Los archivos viven acá y se symlinkean a
`~/.claude`.

`~/.claude` mezcla configuración con estado en tiempo de ejecución: historial,
sesiones, caches, plugins instalados y credenciales. Por eso no se symlinkea la
carpeta entera. Se symlinkea archivo por archivo.

## Qué se versiona

| Ruta en el repo | Symlink | Qué es |
| --- | --- | --- |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Instrucciones globales para todos los proyectos |
| `settings.json` | `~/.claude/settings.json` | Modelo, hooks, statusline, plugins, notificaciones |
| `statusline.pl` | `~/.claude/statusline.pl` | Statusline: carpeta base y contexto usado |
| `commands/` | `~/.claude/commands` | Slash commands propios |
| `skills/` | `~/.claude/skills` | Skills propias |
| `memory/` | `~/.claude/memory` | Memorias globales que escribe Claude |
| `hooks/tasks-brief.py` | `~/.claude/hooks/tasks-brief.py` | Brief de tareas pendientes al arrancar una ventana |

## Qué NO se versiona

- `.credentials.json` — token OAuth. Nunca lo commitees.
- `settings.local.json` — overrides por máquina. Ese es su propósito.
- `skills/synced/` — skills que Claude Code baja de claude.ai. Se regeneran
  solas. Están en `.gitignore`.
- `projects/*/memory/` — memorias por proyecto. Viven con el estado de cada
  proyecto, no son configuración.
- `plugins/` — plugins instalados. `settings.json` ya guarda cuáles van, y
  Claude Code los reinstala solo.
- Estado en tiempo de ejecución: `projects/`, `sessions/`, `history.jsonl`,
  `file-history/`, `shell-snapshots/`, `session-env/`, `tasks/`, `plans/`,
  `cache/`, `debug/`, `daemon/`, `ide/`, `remote/`, `stats-cache.json`,
  `policy-limits.json`.

## Instalar

Lo hace `install.sh` de esta carpeta. Corre solo o desde el de la raíz:

```bash
~/.dotfiles/install.sh          # todas las configs
~/.dotfiles/claude/install.sh   # sólo esta
```

Es idempotente. Si un destino ya existe y no apunta al repo, lo reporta como
conflicto y no lo toca; con `--adopt` lo mueve a `<destino>.pre-dotfiles` y hace
el symlink.

`hooks/` no se symlinkea entera: Claude Code guarda ahí sus propios
`README.md` y `hooks.json`. Se symlinkea archivo por archivo.

Verificar:

```bash
ls -l ~/.claude | grep '\->'
```

## statusline.pl

Imprime una línea: carpeta base y contexto usado de la sesión. Va alineada a la
derecha con la variable `COLUMNS` que exporta Claude Code.

Además alimenta el medidor de tmux. Claude Code le pasa un JSON por stdin en
cada render. Ese JSON trae `rate_limits.five_hour`, el consumo global de la
cuenta. `statusline.pl` lo escribe en `~/.cache/claude-usage/data` y
`tmux/scripts/claude-usage.sh` lo formatea para la barra. Detalles en
[../tmux/README.md](../tmux/README.md).

No confundir los dos porcentajes del mismo JSON:

- `context_window.used_percentage` — contexto de **esa sesión**. Va en la
  statusline.
- `rate_limits.five_hour.used_percentage` — ventana de 5 horas **de la
  cuenta**. Va en la barra de tmux.

Probarlo a mano:

```bash
printf '{"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":41,"total_input_tokens":82000,"context_window_size":200000},"rate_limits":{"five_hour":{"used_percentage":37,"resets_at":1800000000}}}' \
  | COLUMNS=80 ~/.claude/statusline.pl
```

## Brief de tareas al arrancar

Cada ventana nueva muestra las tareas pendientes de Google Tasks del proyecto
del working dir y las globales. El resumen lo escribe un haiku.

Listas y estados en Google Tasks:

- Cada proyecto tiene una lista con el nombre de la carpeta del repo. En un
  worktree, el proyecto es la carpeta que contiene `.bare`.
- `Mis tareas` es la lista general. Tiene las tareas sin proyecto y el brief
  la muestra como Globales.
- Las otras listas no aparecen en el brief. Aparecen con `/pending-tasks <pedido>`.
- Estados de una tarea:
  - Por hacer: pendiente, sin marca.
  - En curso: pendiente, con `▶ ` al principio del título.
  - Hecha: completada.
- El MCP `global-tasks` no crea listas. `tasks-brief.py ensure-list [proyecto]`
  imprime el id de la lista del proyecto y la crea si no existe. Llama directo
  a la API de Google Tasks con las credenciales del MCP. Sin argumento usa el
  proyecto del working dir.

Cómo funciona:

- `settings.json` registra dos hooks `SessionStart` con matcher
  `startup|resume|clear`.
- El hook `show` imprime el brief cacheado. Tarda milisegundos.
- El hook `refresh` corre en background (`async`). Habla con el server MCP
  `global-tasks` por stdio, le pasa las tareas a `claude -p --model haiku` sin
  tools y reescribe el cache.
- El texto que ves sale del cache, así que es el brief que dejó la ventana
  anterior. La ventana siguiente ve lo que deja este refresh.
- El cache es por working dir: `~/.claude/cache/tasks-brief/<dir>-<hash>.txt`.
- `refresh` no hace nada si el cache tiene menos de 30 minutos.
- El script clasifica por lista. Haiku solo escribe el dato clave de cada
  tarea. Si haiku falla, el brief sale igual con título y vencimiento.
- Cualquier error imprime `{}`. El arranque nunca se rompe.
- `/pending-tasks` trae el brief al momento. Corre el modo `now`: MCP y haiku
  sincrónicos (unos 15 s), reescribe el cache e imprime el brief para que
  Claude lo muestre.
- `/pending-tasks <pedido>` (por ejemplo `ordenar por producto` o `kanban`)
  corre el modo `raw`: trae todas las listas con estado y notas, sin haiku ni
  cache (unos 4 s). Claude arma la vista que dice el pedido.

Requisitos:

- `python3`.
- El server MCP `global-tasks` en `~/.claude.json`, clave `mcpServers`, con
  `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` y `GOOGLE_REFRESH_TOKEN`. Ese
  archivo no se versiona: hay que configurarlo en cada máquina.

Probarlo a mano:

```bash
echo "{\"cwd\":\"$PWD\"}" | CLAUDE_TASKS_BRIEF_FORCE=1 python3 ~/.claude/hooks/tasks-brief.py refresh
echo "{\"cwd\":\"$PWD\"}" | python3 ~/.claude/hooks/tasks-brief.py show
python3 ~/.claude/hooks/tasks-brief.py raw
```

Pruebas unitarias:

```bash
python3 -m unittest discover -s claude/hooks -p 'test_*.py'
```

Variables de entorno:

- `CLAUDE_TASKS_BRIEF` — el script la pone en `1` en los procesos hijos. Con
  ese valor `refresh` no hace nada. Corta la recursión: el `claude -p` interno
  también dispara los hooks `SessionStart`.
- `CLAUDE_TASKS_BRIEF_FORCE=1` — fuerza el refresh aunque el cache esté fresco.
- `CLAUDE_TASKS_BRIEF_CACHE` — usa otro directorio de cache. Sirve para probar.

Para apagarlo, saca el bloque `SessionStart` de `settings.json`.

## Memoria global al arrancar

Cada sesión nueva carga `~/.claude/memory/MEMORY.md` como contexto. Es el índice
de las memorias globales: una línea por memoria, con el link al archivo.

- Lo carga un tercer hook `SessionStart` de `settings.json`, con el mismo
  matcher `startup|resume|clear`.
- El hook sólo lee el índice. Claude abre los archivos que necesita.
- Si el archivo no existe o falla la lectura, el hook imprime `{}`. El arranque
  nunca se rompe.
- Las memorias por proyecto viven en `~/.claude/projects/<dir>/memory/` y no se
  versionan.

## Notas

- `settings.json` usa `~/.claude/statusline.pl`, no una ruta absoluta. Claude
  Code corre el comando por shell, así que `~` expande. Así el archivo sirve en
  cualquier máquina, con cualquier usuario.
- Claude Code puede reescribir `settings.json` cuando cambiás algo con
  `/config`. Si la reescritura reemplaza el symlink por un archivo común, tus
  cambios dejan de llegar al repo. Verificá con `ls -l ~/.claude/settings.json`
  y si hace falta rehacé el symlink.
- Antes de commitear, revisá que no haya tokens ni API keys:
  `grep -rinE 'key|token|secret|password' claude/`.
