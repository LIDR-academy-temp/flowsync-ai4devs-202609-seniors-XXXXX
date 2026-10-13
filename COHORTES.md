# Cómo se crea y se alimenta el repo de un cohorte

Este repositorio es el **canónico**. No es de ningún alumno: cada cohorte tiene el suyo, derivado de aquí.

## Qué necesitas, y qué NO

**No necesitas una copia sincronizada de este repositorio.** El script se descarga las ramas él solo, en un temporal, cada vez que lo ejecutas. Así que da igual lo vieja que sea tu carpeta local: **siempre publica lo que hay hoy en el remoto**.

Necesitas tres cosas:

1. **El archivo del script.** Bájalo así, y vuelve a hacerlo cuando te avise:
   ```bash
   gh api repos/LIDR-academy/flowsync-ai4devs-fundacional/contents/scripts/publicar-cohorte.sh \
     --jq .content | base64 -d > publicar-cohorte.sh && chmod +x publicar-cohorte.sh
   ```
   Lo deja en la carpeta donde estás, y los ejemplos de abajo se corren **desde esa carpeta**.
2. **`gh` autenticado con la cuenta oficial de los TA: `ai4devs@lidr.es`** (usuario de GitHub `LIDR-AI4Devs`). Si ya la tienes en `gh`, `gh auth switch -u LIDR-AI4Devs`; si no, `gh auth login` y entra con ese email. **Todo lo hace con la cuenta activa de `gh`, también el `git`**: da igual qué cuenta tengas guardada en el llavero del sistema. El script te dice al empezar con cuál corre.
3. **`git`.**

> 👤 **El script comprueba la cuenta antes de hacer nada:**
> - **Si no es de la organización `LIDR-academy`**, se para y te dice cómo cambiar a la oficial.
> - **Si es de la organización pero no es la oficial**, te avisa y te pregunta si estás seguro. Esa es la vía para una **excepción a la regla**: se confirma con un `SI`, no hace falta tocar el script.
> - `estado` solo lee, así que no pregunta por la cuenta oficial.

> 🔒 **El script se mantiene al día solo.** Cada vez que arranca compara su versión con la de este repositorio: si la tuya es **más vieja**, descarga la última (deja la anterior en `publicar-cohorte.sh.anterior`) y **relanza tu mismo comando** con ella. No es celo: una copia vieja se queda sin los avisos que impiden repartir una solución antes de tiempo, y eso no se nota hasta que ya pasó. Solo se niega a seguir si la copia de este repo es ilegible, o si dos copias dicen ser la misma versión con contenido distinto. **Una copia anterior a esta versión no sabe actualizarse**: la primera vez, bájala a mano con el comando de arriba.

> ✎ **Las instrucciones de cada rama se reescriben al publicar.** El README de `sN/start` nombra `flowsync-ai4devs` (el repo público de hoy); en un cohorte tiene que nombrar `flowsync-ai4devs-<cohorte>`. El script lo cambia en los `.md` de cada rama que publica, como **un commit encima** (nunca reescribe historia), y no toca `-fundacional`, `-lab` ni archivos que no sean `.md` (esos los avisa). Al terminar cada `start` te dice **qué tienes que hacer en la plataforma**: abrir el README de la rama, copiarlo entero a la lección y rellenar la fecha límite y `Repositorio:`.

## Los repos de un cohorte, y por qué pueden ser cinco

Un cohorte no tiene un solo repo: tiene **uno por proyecto del curso**, y cada uno se deriva de su canónico `<proyecto>-fundacional` (privado, plantilla). Los canónicos **no los crea un TA**: los fundó el director con `fundar`, y ese comando no se usa en el día a día.

| Repo del cohorte | Módulos | Cuándo se crea |
|---|---|---|
| `flowsync-ai4devs-<cohorte>` | 1 a 5 y 8 a 14 | con `crear` |
| `blog-legacy-ai4devs-<cohorte>` | 6 (auditar un sistema que ya existe) | **la primera vez que publicas el Módulo 6** |
| `blog-api-ai4devs-<cohorte>` · `blog-web-ai4devs-<cohorte>` · `blog-ai-ai4devs-<cohorte>` | 7 (polirepo: tres repos hermanos) | **la primera vez que publicas el Módulo 7**, los tres a la vez |

`blog-ai` sale además en el **Módulo 9**, pero ahí es **del mentor** (su Bloque 5): el alumno no lo forkea ni aparece en la lección.

### Los repos del blog se crean solos al publicar, y el script te dice cuáles son

`crear` deja el cohorte **solo con FlowSync**. Cuando publicas el Módulo 6 o el 7 y el cohorte aún no tiene el repo de ese proyecto, **el script lo crea** (con `main` y su rama de partida, nada más) y, al terminar, te da lo que necesitas para la plataforma:

```
🆕 El cohorte 202610-seniors aún no tiene el repo de «blog-legacy-ai4devs» y el Módulo 6 lo necesita: se crea ahora.
…
🔗 Repos de esta sesión (Módulo 6, cohorte 202610-seniors):
   blog-legacy-ai4devs: https://github.com/LIDR-academy/blog-legacy-ai4devs-202610-seniors   🆕 creado ahora
   → Este es el repo de la sesión del Módulo 6: los alumnos forkean este.
```

- **Módulo 6:** un repo. Esa URL es la del `Repositorio:` de la lección.
- **Módulo 7:** **tres** repos, con sus tres URL. Los alumnos forkean los tres, pero **la entrega vive solo en `blog-api-<cohorte>`** (es el único con `prompts.md` y el pull request): los otros dos solo se levantan.
- Si el repo ya existía, no lo toca ni lo marca como nuevo, pero **te da su URL igual**.

**Por qué así y no todos con `crear`.** En FlowSync la solución de un módulo es la partida del siguiente, y por eso hay que publicar con cuidado. En el blog **no hay cadena**: `s6/start` y `s7/start` no destapan nada, así que crear el repo la primera vez que hace falta no reparte ninguna solución. Y crear los cinco de golpe deja repos vacíos meses antes de que nadie los use. Si aun así los quieres desde el principio: `./publicar-cohorte.sh crear 202610-seniors blog` (o `todos`).

**Solo si el cohorte existe.** Al publicar, el script comprueba primero que existe el repo de FlowSync de ese cohorte. Si no, se para y te pregunta si la etiqueta está bien escrita: **un typo no puede crear un cohorte por accidente**.

## Reparar un cohorte que ya existe

```bash
./publicar-cohorte.sh reparar 202610-seniors
```

Aplica lo mismo a las ramas `sN/...` que el cohorte **ya tiene publicadas**, sin pedir confirmación de «solución» (ya son públicas). Es siempre un avance simple, sin `--force`. Si el cohorte se publicó antes de una reescritura del canónico y su historia es distinta, el commit va sobre **su** punta, con el README de la misma rama de aquí.

## Crear el cohorte

```bash
./publicar-cohorte.sh crear 202610-seniors
```

Crea `LIDR-academy/flowsync-ai4devs-202610-seniors` (público) con **`main` y `s1/start`, nada más**, y eso es deliberado.

**La etiqueta lleva fecha y track, y el track no es opcional.** `202610-seniors`, `202610-seniors-II`. Sin track, dos cohortes del mismo mes chocan, así que el script rechaza `202610` a secas.

Al terminar imprime la URL del repo nuevo. **No crea los repos del blog**: los crea `publicar` cuando toque (ver arriba).

## Publicar cuando toque: un comando por módulo impartido

```bash
./publicar-cohorte.sh publicar 202610-seniors s2 start   # tras impartir el Módulo 1: s1/end + s2/start
./publicar-cohorte.sh publicar 202610-seniors s1 end     # lo mismo, pedido desde la otra rama
./publicar-cohorte.sh estado   202610-seniors            # qué hay publicado
```

**Tras impartir un módulo se publican dos ramas juntas: su `end` y la `start` del siguiente.** El alumno necesita las dos: la solución del módulo que acaba de ver y la rama de partida del siguiente, que es de donde sale su prework. Por separado, una de las dos se olvidaba.

**Se puede pedir por cualquiera de las dos ramas, y el resultado es el mismo.** `publicar … s2 start` y `publicar … s1 end` suben `s1/end` y `s2/start`. Usa la que te resulte más natural.

- Pide **una sola confirmación**, que nombra las dos ramas.
- Si la `start` trae commits propios además de la solución, te dice cuántos. Hoy pasa con `s4/start`.
- Si la otra rama del par no existe en este repositorio, se publica solo la que pediste y el script lo avisa. Pasa en los extremos: `s1/start` sale sola porque no hay Módulo 0 (es la que usa `crear`, y la que recupera un `crear` a medias, ver *Si algo falla*), y `s5/end` sale sola porque no hay `s6/start`.

## Las excepciones que el script conoce, y por qué

El comando es siempre el mismo, pero **no todos los módulos se comportan igual**, y el script lo sabe para que tú no tengas que acordarte. Estas son las excepciones y su motivo:

**1. Los Módulos 6 y 7 (blog) no tienen cadena.** No hay `s7/start` que sea la solución del 6. Publicar la `start` no destapa nada y no pide confirmación; publicar la `end` sí (es la solución del módulo). Un módulo con varios repos (el 7) los publica **todos a la vez**.

**2. `s8/start-setup`: una rama que no es `start` ni `end`.** Es `s8/start` más la suite de evals ya montada: **el mentor da la sesión desde ella** y el alumno la usa después, pero **el ejercicio se hace en `s8/start`**. El script la trata como una **variante**: cualquier rama `sN/start-<algo>` se publica igual.

```bash
./publicar-cohorte.sh publicar 202610-seniors s8 start-setup
```

Publica `s8/start` y `s8/start-setup` (y `s(N-1)/end` si existe), **nunca** la `end` ni la partida siguiente. Avisa de cuántos commits propios trae la variante. **Si te dice que no comparte historia con `s8/start`, para y avisa**; que la variante se haya quedado atrás de `s8/start` (a esta se le regeneró el README después) es normal y no es un aviso.

**3. `s8/start` no parte de `s7/end`.** El Módulo 7 es del blog, otro proyecto: `s8/start` parte de `s5/end`. Por eso, en lugar de «esto entrega la solución del Módulo 7», el script dice que la rama parte de la solución de un módulo anterior. La confirmación te la pide igual.

**4. `s9/start` es `s8/end` más el README de la sesión 9.** Son el mismo contenido: `s9/start` se construyó como una fusión de `s8/end`. Consecuencia que conviene saber: **no hace falta (ni sirve) publicar `s8/end` "primero"**. Publicar `s9/start` ya reparte la solución del Módulo 8, y por eso el script publica las dos juntas y te pide confirmación. Tras impartir el Módulo 8, `publicar … s8 end` sube `s8/end` y `s9/start`.

**5. El Módulo 9 toca dos proyectos.**

```bash
./publicar-cohorte.sh publicar 202610-seniors s9 end     # FlowSync s9/end + blog-ai s9/end
```

Publica FlowSync (por su cadena) y **después** `blog-ai` (sin cadena), con **una sola confirmación**. Y **no deja nada a medias**: antes de publicar comprueba que existen los canónicos y la rama en cada proyecto, para no dejar FlowSync publicado y el blog sin publicar. El aviso de la plataforma sale una vez y solo habla de FlowSync: `blog-ai` del Módulo 9 es del mentor y no va en la lección.

**6. Un cohorte que no existe no se crea al publicar.** Ya explicado arriba; es un freno contra los typos.

## Por qué no se publican todas de golpe

**`s(N+1)/start` ES la solución de la sesión N.** No es una convención: son el mismo commit.

```
s1/end == s2/start        s2/end == s3/start        s4/end == s5/start
```

Y más adelante, la misma idea con un matiz: `s8/start` parte de `s5/end`, `s8/start-setup` es `s8/start` más la suite, y `s9/start` es `s8/end` más el README de la sesión 9. Las excepciones de arriba existen porque la cadena ya no es una línea recta.

Así que un cohorte que naciera con todas las ramas tendría el curso resuelto el primer día, y uno que naciera sin ninguna dejaría al alumno sin rama de partida para su prework. Por eso hay una herramienta y no una instrucción.

**El script avisa** cuando lo que vas a publicar destapa una solución, y pide confirmación escrita. Ese aviso es la razón de que exista: publicar `s3/start` reparte `s2/end`, y **eso no se ve en el nombre de la rama**. Por eso pregunta igual por los dos caminos: `publicar … s3 start` y `publicar … s2 end` reparten la solución del Módulo 2.

> ⚠️ **No publiques ramas a mano con `git push`.** Te saltas el aviso, y es justo el caso en que hace falta.

## Si algo falla

**«no pertenece a la organización» o «no ve …».** Tienes varias cuentas de GitHub y la activa no es la oficial. `gh auth status` las lista y `gh auth switch -u LIDR-AI4Devs` cambia a la oficial. Si tienes `GH_TOKEN` definido, ese token gana sobre cualquier cuenta.

**«tiene una invitación PENDIENTE».** La cuenta está invitada a la organización pero no ha aceptado. El script da el enlace para aceptarla.

**«El cohorte … no existe».** Escribiste mal la etiqueta (`202610-senoirs`). El script se para en vez de crear un cohorte nuevo: corrige la etiqueta, o, si de verdad es nuevo, `crear` primero.

**«No existe el canónico … (o la cuenta no lo ve)».** O no estás con la cuenta oficial, o falta el repo canónico de ese proyecto. Los canónicos los funda el director (`fundar`): **no lo hagas tú**, avísale.

**Te dice «ya estaba publicada y no ha cambiado».** No es un error: publicar es idempotente. Puedes repetir un comando sin miedo.

**`crear` creó el repo pero no publicó `s1/start`.** No vuelvas a correr `crear`: el repo ya existe y fallaría. Publica lo que faltó:

```bash
./publicar-cohorte.sh publicar 202610-seniors s1 start
```

**`remote: Repository not found` justo después de «✓ repo creado».** Es el síntoma de una copia del script **anterior a esta sección**, en la que `git` usaba la cuenta del llavero en vez de la de `gh`. El canónico es privado, así que GitHub contesta «not found» en lugar de «sin permiso». Vuelve a bajar el script.
