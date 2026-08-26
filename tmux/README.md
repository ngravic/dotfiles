# .tmux

Configuración personal de tmux: reloj en la barra de estado (UTC-3 fijo),
medidor de consumo de Claude, alertas visuales de actividad/bell, ventanas y
paneles numerados desde 1, y un layout custom para ventanas nuevas
(`bind-key C`, ver `scripts/new-window-layout.sh`).

## Medidor de consumo de Claude

`scripts/claude-usage.sh` muestra la ventana corta (5 horas) en la barra:
porcentaje consumido y tiempo hasta el reset. Por ejemplo `58% 3h` o `98% 21m`.
Imprime texto crudo, sin tags de estilo, así toma el formato de la barra.

La barra se refresca 1 vez por segundo, pero el script **no consulta la API en
línea**. Imprime un cache y, si venció el TTL, lanza un refresh en segundo
plano. Un `flock` deja pasar un solo refresh a la vez. Ante un error conserva
el último valor y espera más tiempo antes de reintentar.

Lee el token OAuth de `~/.claude/.credentials.json`. Si no hay token o la API
falla, el segmento queda vacío.

Variables de entorno:

- `CLAUDE_USAGE_TTL` — segundos entre refreshes exitosos (default 60).
- `CLAUDE_USAGE_ERR_TTL` — backoff tras un error (default 180).

Flags para probar a mano:

- `--raw` — respuesta cruda de la API.
- `--refresh` — refresh sincrónico e imprime el resultado.
- `--clear` — borra el cache.

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
