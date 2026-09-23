---
name: feedback-sin-jerga-en-ingles
description: No usar jerga en inglés como "seam"; nombrar las cosas con palabras comunes o con el identificador real del código
metadata:
  type: feedback
---

No uses palabras raras ni jerga en inglés en el texto dirigido al usuario. "Seam",
"trampoline", "harness" y similares no se entienden fuera del documento que las
acuñó. Nombrá la cosa con palabras comunes ("las funciones nuevas de logging") o
con su identificador real del código (`cq::setLogSink`).

**Why:** el usuario frenó una pregunta entera con "no se de que me hablas con
seam". La palabra venía de una skill del repo escrita en inglés; el usuario no la
usa y la pregunta quedó sin poder contestarse.

**How to apply:** los términos técnicos que van en su forma original son los
identificadores de código, comandos y APIs, no el vocabulario de diseño. Si una
skill o un doc del repo está en inglés, traducí sus conceptos antes de usarlos en
una pregunta o un resumen. Ver [[feedback-responder-lo-que-se-pregunta]].
