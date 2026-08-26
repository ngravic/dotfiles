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

## Qué NO se versiona

- `.credentials.json` — token OAuth. Nunca lo commitees.
- `settings.local.json` — overrides por máquina. Ese es su propósito.
- `plugins/` — plugins instalados. `settings.json` ya guarda cuáles van, y
  Claude Code los reinstala solo.
- Estado en tiempo de ejecución: `projects/`, `sessions/`, `history.jsonl`,
  `file-history/`, `shell-snapshots/`, `session-env/`, `tasks/`, `plans/`,
  `cache/`, `debug/`, `daemon/`, `ide/`, `remote/`, `stats-cache.json`,
  `policy-limits.json`.

## Instalar en una máquina nueva

```bash
cd ~/.claude
for f in CLAUDE.md settings.json statusline.pl commands skills; do
  if [ -e "$f" ] && [ ! -L "$f" ]; then mv "$f" "$f.pre-dotfiles"; fi
  ln -sfn ~/.dotfiles/claude/"$f" "$f"
done
```

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
