# .tmux

Configuración personal de tmux: reloj en la barra de estado (UTC-3 fijo),
alertas visuales de actividad/bell, ventanas y paneles numerados desde 1, y un
layout custom para ventanas nuevas (`bind-key C`, ver `scripts/new-window-layout.sh`).

## Instalación

Con el repo ~/.dotfiles ya clonado, symlinkear `tmux.conf`:

```sh
ln -s ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
```

## Autostartup

Opcional: arrancar tmux automáticamente al abrir una sesión de bash.
Agregar al final de `~/.bashrc`:

```sh
[ -z "$TMUX" ] && exec tmux
```
