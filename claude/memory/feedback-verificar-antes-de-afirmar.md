---
name: feedback-verificar-antes-de-afirmar
description: antes de decir qué se hizo o qué no, verificar el estado real; sobre todo después de un comando rechazado o cortado
metadata:
  type: feedback
---

No afirmar "no creé nada" ni "quedó hecho" sin mirar el estado real.

**Por qué:** un loop que creaba listas de Google Tasks se cortó a mitad. Dije
"No creé nada" sin verificar, y la primera lista (`api`) ya estaba creada. El
usuario lo tomó como una mentira.

**Cómo aplicarlo:** si un comando se rechaza o se corta, consultar el estado
(listar, `git status` o lo que corresponda) antes de reportar. Si no se puede
verificar, decir que no se sabe.

Se aplica junto con [[feedback-completo-o-pendiente-nunca-ambos]].
