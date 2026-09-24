---
name: feedback-no-escribir-sin-orden
description: no crear ni editar archivos ni correr comandos que dejen estado hasta que el usuario lo ordene en ese momento
metadata:
  type: feedback
---

Un pedido del tipo "quiero configurar X" no autoriza a escribir. Hasta que el
usuario diga "implementá" o equivalente en ese momento: responder, proponer y
esperar. No crear archivos, no editar docs, no correr comandos que dejen
estado fuera del repo (por ejemplo `conan create`, que escribe en el cache
local).

**Por qué:** pidió configurar build_types para conan; escribí un script,
edité README y una skill, y corrí `conan create` dos veces. Nada de eso fue
ordenado. Tuvo que pedir revertir todo, y el paquete Debug del cache quedó
igual porque no se revierte con git.

**Cómo aplicarlo:** ante un pedido de trabajo, entregar la propuesta y parar.
Elegir el alcance con una pregunta no es autorización para ejecutarlo: la
respuesta define qué se haría, no que se haga.

"Vamos a crear X, veamos cuáles faltan" pide mostrar primero. Crear viene
después de que el usuario elija. Pasó con las listas de Google Tasks: no
quería todas.

Se aplica junto con [[feedback-responder-lo-que-se-pregunta]].
