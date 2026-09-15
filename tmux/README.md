# .tmux

Configuración personal de tmux: reloj en la barra de estado (UTC-3 fijo),
medidor de consumo de Claude, alertas visuales de actividad/bell, ventanas y
paneles numerados desde 1, y layouts custom para ventanas nuevas
(`bind-key C`, ver `scripts/new-window-layout.sh`).

## Layouts para ventanas nuevas

`Ctrl+b` + `C` abre un popup con dos pasos: el layout y el directorio de
trabajo. Todos los paneles de la ventana nueva comparten ese directorio y la
ventana toma su nombre.

`Ctrl+b` + `c` sigue siendo el `new-window` normal de tmux.

### Paso 1: el layout

Una lista de radio buttons (`whiptail --radiolist`). El default ya viene
marcado, así que Enter alcanza.

| Layout | Paneles |
|--------|---------|
| `nvim + claude + shell` (default) | `nvim` a la izquierda, `claude` arriba a la derecha, shell abajo a la derecha |
| `3x claude + shell (2x2)` | grilla 2x2: `claude` en tres paneles, shell abajo a la derecha |

En los dos casos el shell queda enfocado.

Teclas:

- Flechas mueven el cursor, pero **no** cambian la marca.
- Espacio marca la opción donde está el cursor.
- Enter confirma la opción marcada.
- Esc, o Tab Tab Enter para llegar a `<Cancel>`, sale sin crear la ventana.

Ojo con la primera: si bajás con la flecha y apretás Enter sin pasar por
Espacio, arranca el layout que seguía marcado. Es cómo funciona un radiolist.
Si preferís que el cursor sea la selección, cambiá `--radiolist` por `--menu`
en el script y saltea el tercer campo (`on`/`off`) de cada fila.

### Paso 2: el directorio

Un prompt de readline con el directorio actual ya escrito. Completa con Tab,
como un prompt de shell normal. Enter acepta el que viene.

### Agregar un layout

En `scripts/new-window-layout.sh`:

1. Escribí una función que corra los `tmux split-window`. Usá `$wd` para el
   directorio y `$name` para el nombre de la ventana.
2. Agregá una línea al array `LAYOUTS` con el formato
   `"<key>|<etiqueta>|<función>"`. La `key` es interna; en el popup se ve solo
   la etiqueta.

La lista se arma sola desde ese array. Cada layout nuevo agrega una fila al
diálogo, así que si deja de entrar subí el `-h` del `display-popup` en
`tmux.conf`.

Para armar grillas, seleccioná los paneles por posición (`{top-left}`,
`{bottom-right}`) y no por índice: los índices se corren a medida que agregás
paneles.

## Medidor de consumo de Claude

`scripts/claude-usage.sh` muestra la ventana corta (5 horas) **de la cuenta**
en la barra: porcentaje consumido y tiempo hasta el reset. Por ejemplo
`58% 3h` o `98% 21m`. Imprime texto crudo, sin tags de estilo, así toma el
formato de la barra.

### De dónde salen los datos

El script **no toca la red**. La fuente es `~/.claude/statusline.pl`.

Claude Code le pasa a la statusline un JSON por stdin en cada render. Ese JSON
trae `rate_limits.five_hour`, que es el consumo global de la cuenta, no el de
la sesión. Es el mismo dato de `GET /api/oauth/usage`, que Claude Code ya
consultó. `statusline.pl` lo escribe en el cache y `claude-usage.sh` solo lo
formatea.

No confundir con `context_window.used_percentage` del mismo JSON: ese sí es
por sesión, y es lo que la statusline muestra dentro de Claude Code.

Antes el script consultaba `/api/oauth/usage` cada 60 segundos. Ese endpoint
tiene un rate limit por cuenta bastante estricto, y cada sesión de Claude Code
también lo consulta. El resultado eran respuestas 429 casi siempre y la barra
en blanco. Leer el dato de la statusline sale gratis y no puede fallar por
rate limit.

### Cache

Un solo archivo: `${XDG_CACHE_HOME:-~/.cache}/claude-usage/data`. Guarda el par
crudo `porcentaje + epoch del reset`, separados por tab, no el texto ya armado.
Así la cuenta regresiva es exacta en cada tick de la barra, que corre 1 vez por
segundo. `statusline.pl` lo escribe de forma atómica: archivo temporal más
`rename`.

### Qué imprime

- `58% 3h` — lectura al día.
- `58% 3h*` — lectura vieja. Pasa si la ventana ya se reseteó, o si ninguna
  sesión de Claude Code refrescó el cache en `CLAUDE_USAGE_MAX_AGE` segundos
  (default 3600).
- `-` — todavía no hay cache. Abrí una sesión de Claude Code para poblarlo.

Sin ninguna sesión de Claude Code abierta el porcentaje queda congelado. La
cuenta regresiva igual sigue corriendo bien, porque se calcula del epoch.

### Flags

- `--status` — estado del cache: valor, antigüedad y texto renderizado.
- `--clear` — borra el cache.

### Instalación de la fuente

`statusline.pl` necesita este bloque, justo después de decodificar el JSON:

```perl
eval {
    my $rl = ($d->{rate_limits} || {})->{five_hour} || {};
    if (defined $rl->{used_percentage}) {
        my $dir = ($ENV{XDG_CACHE_HOME} || "$ENV{HOME}/.cache") . '/claude-usage';
        mkdir $dir unless -d $dir;
        my $tmp = "$dir/data.$$";
        open my $fh, '>', $tmp or die "open: $!";
        printf {$fh} "%d\t%s", $rl->{used_percentage} + 0.5, $rl->{resets_at} // '';
        close $fh or die "close: $!";
        rename $tmp, "$dir/data" or do { unlink $tmp; die "rename: $!" };
    }
    1;
};
```

Va dentro de un `eval` a propósito: un problema con el cache nunca debe tirar
abajo la statusline.

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
