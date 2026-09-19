# dotfiles

Configuraciones personales versionadas. Cada una vive en su propia carpeta y se
symlinkea a su ubicación real.

| Carpeta | Se symlinkea a |
| --- | --- |
| [`nvim/`](nvim) | `~/.config/nvim` |
| [`tmux/`](tmux) | `~/.tmux.conf` |
| [`claude/`](claude) | archivos sueltos dentro de `~/.claude` |

## Instalar

```bash
git clone <url-del-repo> ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` crea las carpetas y los symlinks que faltan. Es idempotente: lo que
ya apunta al repo lo deja como está. Corrélo cada vez que pulleás cambios. Esa
es la forma de sincronizar máquinas: pulleás y corrés el script.

Flags:

- `-n`, `--dry-run` — muestra qué haría, no toca nada.
- `--adopt` — si el destino ya existe y no apunta al repo, lo mueve a
  `<destino>.pre-dotfiles` y hace el symlink.

Sin `--adopt`, un destino ocupado se reporta como conflicto y no se toca. El
script termina con código 1 si hubo alguno.

### Cómo está armado

- `install.sh` en la raíz: corre un `install.sh` por carpeta, en orden
  alfabético, e imprime el total.
- `lib.sh`: helpers `link`, `ensure_dir` y `summary`.
- `nvim/install.sh`, `tmux/install.sh`, `claude/install.sh`: cada carpeta
  declara sus propios symlinks. También corren sueltos, para instalar una sola
  config.
- Para sumar una config nueva: carpeta nueva con su `install.sh` adentro. La
  raíz no se toca.

Lo que ya es symlink de carpeta no necesita nada más. Una memoria nueva en
`claude/memory/` aparece con el `git pull`, sin correr el script.

## nvim

Config real en `~/.config/nvim`, symlinkeada archivo por archivo a `nvim/` de
este repo.

La primera vez que abrís `nvim`, lazy.nvim instala los plugins solo.

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

## claude

Configuración de Claude Code: instrucciones globales, settings, statusline,
slash commands, skills y memorias globales. Detalles en
[claude/README.md](claude/README.md).

`~/.claude` mezcla configuración con estado en tiempo de ejecución, así que se
symlinkea archivo por archivo, no la carpeta entera.

### Notas

- `.credentials.json` nunca se versiona. Es el token OAuth.
- `settings.local.json` tampoco: son overrides por máquina.
