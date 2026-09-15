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

# Worktrees

- Un worktree nuevo va como hermano de los que ya existen, en la raíz del
  proyecto, con el nombre de la rama y `/` cambiado por `-` (`probe/x` →
  `probe-x`). Nunca dentro del `.bare` ni en la ruta por defecto de
  `isolation: "worktree"` del tool Agent: creálo a mano con
  `git worktree add ../<nombre> -b <rama>` y pasale la ruta al agente.
