# Estilo de comunicación

Aplicá los principios de ASD-STE100 (Simplified Technical English) adaptados
al español en todo texto dirigido al usuario: respuestas, resúmenes y
documentación que escribas.

- Una sola idea o instrucción por oración.
- Voz activa y tiempos verbales simples. Evitá pasivas y gerundios
  encadenados.
- Palabras comunes y precisas. Nada de lenguaje rebuscado, adornos ni
  relleno.
- Un término = un significado: usá siempre la misma palabra para el mismo
  concepto; no alternes sinónimos.
- Términos técnicos (comandos, APIs, identificadores de código) van en su
  forma original; no los traduzcas.
- Pasos y enumeraciones van en listas verticales, no en párrafos ni tablas
- Respondé primero el resultado o la conclusión; el detalle va después y
  solo si aporta.
- Si el usuario pregunta (literal con pregunta o se infiere tono de pregunta)
  no se toma ninguna accion de edición, únicamente se limita a responder la 
  pregunta
- Sé breve: la respuesta más corta que resuelve, gana. No repitas lo que el
  usuario ya sabe, no recapitules lo que acabás de decir, no cierres con
  resúmenes ni tablas comparativas que no pidió. Esto rige también para lo que
  escribas en archivos: reglas, memorias y docs van al grano.
- Para describir algo no seas rebuscado: el dato conciso alcanza. Nada de
  justificar cada punto con citas, medidas ni la historia de cómo se llegó.

# Worktrees

- Un worktree nuevo va como hermano de los que ya existen, en la raíz del
  proyecto, con el nombre de la rama y `/` cambiado por `-` (`probe/x` →
  `probe-x`). Nunca dentro del `.bare` ni en la ruta por defecto de
  `isolation: "worktree"` del tool Agent: creálo a mano con
  `git worktree add ../<nombre> -b <rama>` y pasale la ruta al agente.

# Git: commit y push

- No hagas `git commit` ni `git push` sin consentimiento expreso del usuario en
  ese momento.
- Cada consentimiento vale por una sola operación. Un permiso dado antes en la
  conversación no habilita un commit ni un push posterior: pedí autorización de
  nuevo cada vez.

# Plan antes que código

- Mientras se debate o diseña un plan, no escribas código, no toques archivos
  del proyecto ni corras builds. Sólo se responde y se ajusta el plan.
- Dentro de esa discusión, "agreguemos X" significa agregar X **al plan**, no
  implementarlo.
- El paso de plan a implementación lo autoriza el usuario de forma expresa en
  ese momento ("implementá", "codeá", "arrancá el build"). Si hay duda,
  preguntá antes de escribir.
- La regla también cubre los pasos previos: instalar dependencias, exportar
  paquetes al cache o compilar en otro repo también es implementar.

# Google Tasks

- Cada proyecto tiene una lista con el nombre de la carpeta del repo. En un
  worktree, la carpeta del repo es la que contiene `.bare`.
- Una tarea nueva va a la lista del proyecto actual, sin marca. El id de la
  lista sale de `python3 ~/.claude/hooks/tasks-brief.py ensure-list`, que
  crea la lista si no existe. El MCP `global-tasks` no crea listas.
- Una tarea sin proyecto va a `Mis tareas`.
- El título no lleva prefijo de proyecto: la lista ya dice el proyecto.
- Estados:
  - Por hacer: pendiente, sin marca.
  - En curso: pendiente, con `▶ ` al principio del título.
  - Hecha: completada.
