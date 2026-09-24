---
description: Trae las tareas de Google Tasks en este momento. Con un pedido arma esa vista (ej. "ordenar por producto", "kanban")
argument-hint: [pedido, ej. ordenar por producto | kanban]
allowed-tools: Bash(python3 ~/.claude/hooks/tasks-brief.py now:*)
---

Tareas recién traídas:

!`python3 ~/.claude/hooks/tasks-brief.py now "$ARGUMENTS"`

Pedido: "$ARGUMENTS"

Si la salida de arriba empieza con "Tareas por lista", armá con esas tareas la
vista que dice el pedido:

- Cada lista es un proyecto, o sea un repo. "Producto" también quiere decir
  proyecto.
- "Mis tareas" es la lista de Globales: tareas sin proyecto.
- Cada tarea tiene uno de tres estados: Por hacer, En curso o Hecha.
- "kanban" son tres columnas por proyecto: Por hacer, En curso y Hecha.
- No inventes tareas ni datos que no estén en la salida.
- Mostrá solo la vista. No agregues comentarios, resúmenes ni preguntas.

Si no, la salida es el brief. Mostralo sin cambiar el texto:

- "Tareas — …" y "Globales" van como encabezado `##`.
- "En curso" y "Por hacer" van como encabezado `###`.
- Cada tarea va como ítem de lista.
- No agregues comentarios, resúmenes ni preguntas.
