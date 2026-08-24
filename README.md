# dotfiles

Configuraciones personales versionadas. Cada una vive en su propia carpeta y se
symlinkea a su ubicación real.

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
