# dotfiles

Configuraciones personales versionadas. Cada una vive en su propia carpeta y se
symlinkea a su ubicación real.

| Carpeta | Se symlinkea a |
| --- | --- |
| [`nvim/`](nvim) | `~/.config/nvim` |
| [`tmux/`](tmux) | `~/.tmux.conf` |
| [`claude/`](claude) | archivos sueltos dentro de `~/.claude` |

## nvim

Config real en `~/.config/nvim`, symlinkeada a `nvim/` de este repo.

### Instalar en una máquina nueva

```bash
git clone <url-del-repo> ~/.dotfiles
ln -s ~/.dotfiles/nvim ~/.config/nvim
nvim   # lazy.nvim instala los plugins automáticamente
```

### Notas

- `lazy-lock.json` está versionado a propósito: fija las versiones de los
  plugins para reproducibilidad. No lo ignores salvo que quieras rolling
  updates.
- No commitear API keys ni tokens (por ejemplo config de copilot/avante). Si
  aparecen, sacarlos a variables de entorno.

## tmux

Config real en `~/.tmux.conf`, symlinkeada a `tmux/tmux.conf` de este repo.
Detalles en [tmux/README.md](tmux/README.md).

Migrado desde el repo standalone `ngravic/tmux` (historia git no preservada;
el repo original queda intacto en GitHub como archivo).

### Instalar en una máquina nueva

```bash
ln -s ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
```

## claude

Configuración de Claude Code: instrucciones globales, settings, statusline,
slash commands y skills. Detalles en [claude/README.md](claude/README.md).

`~/.claude` mezcla configuración con estado en tiempo de ejecución, así que se
symlinkea archivo por archivo, no la carpeta entera.

### Instalar en una máquina nueva

```bash
cd ~/.claude
for f in CLAUDE.md settings.json statusline.pl commands skills; do
  if [ -e "$f" ] && [ ! -L "$f" ]; then mv "$f" "$f.pre-dotfiles"; fi
  ln -sfn ~/.dotfiles/claude/"$f" "$f"
done
```

### Notas

- `.credentials.json` nunca se versiona. Es el token OAuth.
- `settings.local.json` tampoco: son overrides por máquina.
