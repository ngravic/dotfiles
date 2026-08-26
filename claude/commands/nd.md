---
description: Desactiva el modo orquestador desde este momento (trabajo directo, sin subagentes)
---

A partir de este momento y hasta el final de la sesión, el "Modo orquestador"
definido en ~/.claude/CLAUDE.md queda DESACTIVADO:

- Ejecutá las tareas directamente en el hilo principal: usá Read, Grep, Glob,
  Bash, Edit, Write, etc. vos mismo.
- No delegues a subagentes salvo que el usuario lo pida explícitamente.
- Las demás reglas siguen vigentes: higiene de contexto (no pegar dumps largos),
  backups .bak antes de sobrescribir archivos funcionales, y reportar resultados
  fieles con evidencia.

Confirmá en una línea que el modo orquestador quedó desactivado. Si hay una
tarea a continuación, ejecutala directo: $ARGUMENTS
