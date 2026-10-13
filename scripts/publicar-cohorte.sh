#!/usr/bin/env bash
# Publica las ramas del curso en los repos de un cohorte, en su cadencia.
# Gobierna CINCO repos por cohorte, uno por proyecto del curso:
#   flowsync-ai4devs-<cohorte>       Módulos 1-5 y 8-14 (cadena sN/start = s(N-1)/end)
#   blog-legacy-ai4devs-<cohorte>    Módulo 6  (auditar lo que ya existe)
#   blog-api-ai4devs-<cohorte>       Módulo 7  (polirepo: tres repos hermanos)
#   blog-web-ai4devs-<cohorte>       Módulo 7
#   blog-ai-ai4devs-<cohorte>        Módulo 7
# Cada uno se deriva de su repo canónico `<proyecto>-fundacional` (privado, plantilla).
#
# POR QUÉ EXISTE, y no es comodidad:
#   En FlowSync, `s(N+1)/start` ES la solución de la sesión N. Verificado contra
#   los SHA del repo del curso: s2/start = s1/end, s3/start = s2/end,
#   s5/start = s4/end (s4/start desciende de s3/end y trae commits propios).
#   Por eso un repo de cohorte NO puede nacer con todas las ramas: sería repartir
#   el curso resuelto el primer día. Y tampoco puede nacer sin ninguna, porque
#   entonces el prework del alumno no tiene de dónde partir.
#   (`gh repo create --include-all-branches` es opt-in: sin él, una copia de
#   plantilla se lleva SOLO la rama por defecto. Aquí se usa eso a propósito.)
#   En los repos del blog no hay cadena: sN/start no destapa nada y se publica
#   al crear; sN/end es la solución del módulo y espera a que se imparta.
#
# TIPOS DE RAMA: `start`, `end` y las variantes `start-<x>` (hoy, `s8/start-setup`: la
#   partida más la preparación del mentor). Una variante NUNCA publica una `end` ni la
#   partida siguiente: publica `s(N-1)/end` (su base, que ya entrega esa solución),
#   `sN/start` y la variante. Todo idempotente: lo ya publicado no se toca.
#
# LÍMITE: solo existen los módulos del mapa de abajo (s1..s14), y de ellos solo
#   se publica lo que exista como rama en su canónico. `s19` no se intenta.
#
# Uso:
#   ./publicar-cohorte.sh crear    202610-seniors            # SOLO FlowSync; los del blog los crea `publicar` cuando toca
#   ./publicar-cohorte.sh crear    202610-seniors todos      # los cinco a la vez (flowsync|blog-legacy|blog-api|blog-web|blog-ai|blog|todos)
#   ./publicar-cohorte.sh publicar 202610-seniors s2 start   # FlowSync: s1/end + s2/start
#   ./publicar-cohorte.sh publicar 202610-seniors s1 end     # lo mismo
#   ./publicar-cohorte.sh publicar 202610-seniors s8 start-setup  # una rama de VARIANTE: sN/start-<x> (con sN/start, su base)
#   ./publicar-cohorte.sh publicar 202610-seniors s6 end     # blog-legacy: la solución del Módulo 6
#   ./publicar-cohorte.sh publicar 202610-seniors s7 start   # los TRES repos del polirepo a la vez
#   ./publicar-cohorte.sh publicar 202610-seniors s9 end     # DOS proyectos: FlowSync s9/end y blog-ai s9/end
#
# REPOS DEL BLOG BAJO DEMANDA: `crear` deja al cohorte solo con FlowSync (o con los cinco, si
#   se pide `todos`). Si al publicar el Módulo 6 o el 7 el cohorte aún no tiene el repo de ese proyecto,
#   `publicar` LO CREA (con su rama de partida) y al terminar imprime la URL de cada repo de la
#   sesión y dice cuál es. Solo si el cohorte existe: un typo en la etiqueta no crea un cohorte.
#   ./publicar-cohorte.sh estado   202610-seniors            # ramas de los cinco repos
#   ./publicar-cohorte.sh fundar   blog-legacy               # crea blog-legacy-ai4devs-fundacional desde el repo público de hoy
#   SIMULAR=1 ./publicar-cohorte.sh crear 202610-seniors     # enseña lo que haría sin crear ni publicar nada
#
#   ./publicar-cohorte.sh reparar  202608-x                  # reescribe las instrucciones de lo YA publicado (fast-forward, sin --force)
#
# INSTRUCCIONES DE CADA RAMA: en el canónico, el README de cada sN/start apunta a
# `flowsync-ai4devs` (el repo público de hoy, cohorte 202608). Al publicar en un
# cohorte, este script reescribe esos nombres a `<repo>-<cohorte>` en los `.md` de
# la rama y empuja UN commit derivado encima (determinista: misma rama, mismo SHA).
# Solo toca `.md`; si otro tipo de archivo nombra un repo, lo AVISA y no lo toca.
#
# VERSIÓN: si tu copia es más vieja que la del canónico, se descarga sola y sigue.
# Con la cuenta oficial de los TA (ai4devs@lidr.es, usuario LIDR-AI4Devs).
VERSION_SCRIPT="2026-09-25.4"   # se SUBE en cada cambio: es lo que decide quién está viejo
set -euo pipefail

ORG=LIDR-academy
# El canónico de FlowSync es además la casa de este script (comprobar_version).
FUENTE="$ORG/flowsync-ai4devs-fundacional"
SIMULAR="${SIMULAR:-}"

# ---------------------------------------------------------------------------
# El mapa: proyecto → repo base, y módulo → proyecto(s). Es la única lista que
# hay que tocar cuando entre un módulo nuevo; lo que no esté aquí no se intenta.
PROYECTOS="flowsync blog-legacy blog-api blog-web blog-ai"
base_de () {   # nombre base del repo (sin sufijo de cohorte ni -fundacional)
  case "$1" in
    flowsync)    echo "flowsync-ai4devs" ;;
    blog-legacy) echo "blog-legacy-ai4devs" ;;
    blog-api)    echo "blog-api-ai4devs" ;;
    blog-web)    echo "blog-web-ai4devs" ;;
    blog-ai)     echo "blog-ai-ai4devs" ;;
    *) echo "✗ Proyecto desconocido: «$1» ($PROYECTOS)" >&2; exit 1 ;;
  esac
}
fuente_de () { echo "$ORG/$(base_de "$1")-fundacional"; }
repo_de   () { echo "$ORG/$(base_de "$1")-$2"; }         # repo_de flowsync 202610-seniors
proyectos_de_modulo () {   # módulo → proyectos, separados por espacio; vacío si no existe
  case "$1" in
    s1|s2|s3|s4|s5|s8|s10|s11|s12|s13|s14) echo "flowsync" ;;
    s6) echo "blog-legacy" ;;
    s7) echo "blog-api blog-web blog-ai" ;;
    s9) echo "flowsync blog-ai" ;;   # el Bloque 5 del mentor trabaja también sobre blog-ai (sin lección propia)
    *)  echo "" ;;
  esac
}
# De qué proyectos habla LA LECCIÓN de un módulo (README de sN/start, nombres que el TA sustituye).
# Casi siempre son todos los del módulo; en el 9, blog-ai es del mentor y la lección solo nombra FlowSync.
proyectos_de_leccion () { case "$1" in s9) echo "flowsync" ;; *) proyectos_de_modulo "$1" ;; esac; }
rama_inicial_de () {   # con qué rama nace el repo del cohorte, además de main
  case "$1" in flowsync) echo "s1/start" ;; blog-legacy) echo "s6/start" ;; blog-*) echo "s7/start" ;; esac
}
descripcion_de () {
  local et="$2"
  case "$1" in
    flowsync)    echo "FlowSync — cohorte $et. Forkea este repo, trabaja en tu rama y abre un PR. NO es el repo canónico." ;;
    blog-legacy) echo "Blog legacy (Módulo 6) — cohorte $et. Forkea este repo y trae s6/start de upstream. NO es el repo canónico." ;;
    blog-api)    echo "Blog polirepo, API (Módulo 7) — cohorte $et. Forkea los tres repos blog-*. NO es el repo canónico." ;;
    blog-web)    echo "Blog polirepo, web (Módulo 7) — cohorte $et. Forkea los tres repos blog-*. NO es el repo canónico." ;;
    blog-ai)     echo "Blog polirepo, ai (Módulo 7) — cohorte $et. Forkea los tres repos blog-*. NO es el repo canónico." ;;
  esac
}
# `SIMULAR=1`: cada acción que escribe en GitHub se imprime en vez de ejecutarse.
hacer () { if [ -n "$SIMULAR" ]; then echo "  [simulado] $*"; else "$@" >/dev/null; fi; }

# git con la MISMA cuenta que gh. Sin esto, `gh repo create` usa la cuenta de gh
# y el `git clone` de justo después usa la que haya en el llavero del sistema (el
# git de Apple trae `credential.helper=osxkeychain` de fábrica). Con varias
# cuentas de GitHub en la máquina son distintas, y como el fundacional es
# privado, GitHub responde «Repository not found» en vez de «sin permiso»: el
# repo del cohorte queda creado y sin s1/start. El `credential.helper=` vacío
# anula los helpers anteriores; `gh auth git-credential` da el token de la
# cuenta ACTIVA de gh (o de GH_TOKEN si está definido), sin tocar tu config.
git_gh () { git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"; }

# REGLA: los TA crean y publican con la cuenta oficial. Una cuenta de fuera de
# la organización no pasa; una de dentro que no sea la oficial pasa si lo
# confirma. Así una excepción a la regla es un SI, no un parche al script.
# Se compara el USUARIO y no el email porque gh no puede leer el email: el
# token de un `gh auth login` normal no trae el scope `user`, y el email
# público de la cuenta está vacío.
CUENTA_OFICIAL=LIDR-AI4Devs
EMAIL_OFICIAL=ai4devs@lidr.es

como_usar_la_oficial () {
  if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    echo "  Tienes GH_TOKEN o GITHUB_TOKEN definido, y gana sobre la cuenta activa: quítalo o cámbialo."
  fi
  echo "  Los cohortes se crean y publican con la cuenta $EMAIL_OFICIAL (usuario $CUENTA_OFICIAL)."
  echo "    gh auth switch -u $CUENTA_OFICIAL      # si ya la tienes en gh (gh auth status las lista)"
  echo "    gh auth login                         # si no, y entra con $EMAIL_OFICIAL"
}

# Falla pronto y diciendo con qué cuenta, en vez de a medio crear.
CUENTA=""
comprobar_cuenta () {
  local accion="$1"
  if ! CUENTA=$(gh api user --jq .login 2>/dev/null); then
    if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
      echo "✗ Tienes GH_TOKEN o GITHUB_TOKEN definido y GitHub no lo acepta. Quítalo o cámbialo."
    else
      echo "✗ gh no está autenticado. Corre: gh auth login   (y entra con $EMAIL_OFICIAL)"
    fi
    exit 1
  fi

  # 1. ¿Es de la organización? Este endpoint pregunta por la cuenta autenticada,
  #    así que no depende de que su membresía sea pública. 404 = no es miembro.
  local membresia; membresia=$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null || true)
  if [ "$membresia" != "active" ]; then
    if [ "$membresia" = "pending" ]; then
      echo "✗ La cuenta activa de gh, «${CUENTA}», tiene una invitación PENDIENTE a $ORG: acéptala en github.com/orgs/$ORG/invitation"
    else
      echo "✗ La cuenta activa de gh, «${CUENTA}», no pertenece a la organización $ORG."
    fi
    como_usar_la_oficial
    exit 1
  fi

  # 2. ¿Es la oficial? Solo se pregunta en lo que escribe; `estado` solo lee.
  local cuenta_min oficial_min
  cuenta_min=$(printf '%s' "$CUENTA" | tr '[:upper:]' '[:lower:]')
  oficial_min=$(printf '%s' "$CUENTA_OFICIAL" | tr '[:upper:]' '[:lower:]')
  if [ "$accion" != "estado" ] && [ "$cuenta_min" != "$oficial_min" ]; then
    echo "⚠️  Estás usando «${CUENTA}», que es de $ORG pero NO es la cuenta oficial de los TA."
    echo "    La regla es crear y publicar con $EMAIL_OFICIAL (usuario $CUENTA_OFICIAL):"
    echo "      gh auth switch -u $CUENTA_OFICIAL"
    local resp; read -r -p "    ¿Seguro que quieres seguir con «${CUENTA}»? (escribe SI): " resp
    [ "$resp" = "SI" ] || { echo "  Cancelado."; exit 1; }
  fi

  if ! gh api "repos/$FUENTE" >/dev/null 2>&1; then
    echo "✗ La cuenta activa de gh, «${CUENTA}», no ve $FUENTE."
    como_usar_la_oficial
    exit 1
  fi
  echo "Usando la cuenta de gh «${CUENTA}»."
}


etiqueta_valida () {
  # fecha + al menos un segmento de track. Sin track, los cohortes colisionan.
  [[ "$1" =~ ^[0-9]{6}(-[A-Za-z0-9]+)+$ ]] || {
    echo "✗ Etiqueta inválida: «$1»"
    echo "  Formato: AAAAMM-track   (p. ej. 202610-seniors, 202610-seniors-II)"
    echo "  El track NO es opcional: sin él, dos cohortes del mismo mes chocan."
    exit 1; }
}

# Un clon bare del canónico de un proyecto, una sola vez por ejecución. El
# directorio temporal se crea AQUÍ, fuera de toda subshell: creado dentro de un
# `$(…)`, su trap lo borraba al salir de la sustitución y el clon desaparecía.
TMP=$(mktemp -d); trap 'rm -rf "${TMP:-}"' EXIT
clon_de () {   # imprime la ruta del clon bare; falla si el canónico no existe
  local p="$1" src; src=$(fuente_de "$p")
  if [ ! -d "$TMP/$p" ]; then
    if ! gh api "repos/$src" >/dev/null 2>&1; then
      echo "✗ No existe el canónico $src (o la cuenta «${CUENTA}» no lo ve)." >&2
      echo "  Si de verdad no existe, créalo desde el repo público de hoy:  $0 fundar $p" >&2
      exit 1
    fi
    git_gh clone -q --bare "https://github.com/$src.git" "$TMP/$p"
  fi
  echo "$TMP/$p"
}
existe_en () { git -C "$1" rev-parse --verify -q "refs/heads/$2" >/dev/null; }
existe_repo () { gh api "repos/$1" >/dev/null 2>&1; }   # ¿existe ese repo en GitHub y lo ve la cuenta activa?
ramas_sN_de () { git -C "$1" for-each-ref --format='%(refname:short)' refs/heads/ | grep -E '^s[0-9]+/' | sort -V | tr '\n' ' '; }

# Las instrucciones de cada rama nombran los repos del curso por su nombre público
# (`flowsync-ai4devs`, `blog-api-ai4devs`…). En un cohorte esos nombres son
# `<repo>-<cohorte>`: un alumno que siguiera el README de la rama forkearía el repo
# de OTRO cohorte. Lookarounds para no tocar `-fundacional`, `-lab` ni lo ya sufijado.
NOMBRES_REPO () { local p s=""; for p in $PROYECTOS; do s="$s${s:+|}$(base_de "$p")"; done; echo "$s"; }

# Imprime en stdout el SHA que hay que empujar para la rama `r`: el original si nada
# cambia, o un commit derivado encima con los nombres reescritos. DETERMINISTA (autor,
# fecha = la del commit base): republicar la misma rama da el mismo SHA, así que
# `empujar` sigue siendo idempotente.
#   base      punta sobre la que se deriva (por defecto, la de la rama en el canónico)
#   readme_de commit del que se COPIA el README.md antes de reescribir (solo `reparar`
#             sobre un cohorte con historia distinta: ahí el commit va sobre SU punta)
preparar_rama () {
  local clon="$1" r="$2" et="$3" base="${4:-}" readme_de="${5:-}" wt f
  [ -n "$base" ] || base=$(git -C "$clon" rev-parse "refs/heads/$r")
  wt="$TMP/wt-${r//\//-}-${base:0:7}"
  git -C "$clon" worktree add --detach -q "$wt" "$base" >&2
  [ -z "$readme_de" ] || git -C "$clon" show "$readme_de:README.md" > "$wt/README.md" 2>/dev/null || true
  local nombres; nombres=$(NOMBRES_REPO)
  local patron="(?<![A-Za-z0-9-])($nombres)(?![A-Za-z0-9_-])"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if perl -ne "if (/$patron/) { \$hay = 1; last } END { exit(\$hay ? 0 : 1) }" "$wt/$f" 2>/dev/null; then
      perl -pi -e "s/$patron/\$1-$et/g" "$wt/$f"
    fi
  done < <(git -C "$wt" ls-files '*.md')
  # Los que NO son .md y nombran un repo: se avisan, no se tocan (un workflow o un
  # script cambiado en silencio es peor que un README sin cambiar).
  local otros="" g
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    case "$g" in *.md) continue ;; esac
    grep -Iq . "$wt/$g" 2>/dev/null || continue                # binarios fuera
    perl -ne "if (/$patron/) { \$hay = 1; last } END { exit(\$hay ? 0 : 1) }" "$wt/$g" 2>/dev/null && otros="$otros $g"
  done < <(git -C "$wt" ls-files)
  [ -z "$otros" ] || echo "  ⚠️  $r: hay archivos que no son .md y nombran un repo del curso, y NO se reescriben: $otros" >&2
  if git -C "$wt" diff --quiet; then
    git -C "$clon" worktree remove --force "$wt" >&2; echo "$base"; return 0
  fi
  local cambiados; cambiados=$(git -C "$wt" diff --name-only | tr '\n' ' ')
  local fecha; fecha=$(git -C "$clon" log -1 --format=%cI "$base")
  GIT_AUTHOR_DATE="$fecha" GIT_COMMITTER_DATE="$fecha" \
    git -C "$wt" -c user.name="$CUENTA_OFICIAL" -c user.email="$EMAIL_OFICIAL" \
      commit -q -am "docs: las instrucciones apuntan a los repos del cohorte $et" >&2
  echo "  ✎ $r: instrucciones reescritas para $et en: $cambiados" >&2
  local nuevo; nuevo=$(git -C "$wt" rev-parse HEAD)
  git -C "$clon" worktree remove --force "$wt" >&2
  echo "$nuevo"
}

# Lo que el TA tiene que hacer en la PLATAFORMA (Mighty Networks) cuando una rama
# `start` sale. Desde el 2026-09-23 el README de cada rama ES la lección de ejercicio,
# generada (make readme-rama en el repo de diseño), y este script ya le puso los nombres
# del cohorte: el TA solo tiene que abrirlo y copiarlo. Se distingue por su marca de
# «Generado desde la lección»; una rama con un README anterior (más corto que la lección)
# recibe el aviso de siempre, sin decir que se copie.
readme_generado () {   # ¿el README de esa rama del canónico es el generado?
  git -C "$1" show "refs/heads/$2:README.md" 2>/dev/null | head -1 | grep -q "Generado desde la lección"
}
aviso_para_la_plataforma () {
  local et="$1" mod="$2" generado="${3:-0}" p repo
  # Módulo 7: son tres repos, pero la entrega vive en UNO (blog-api, D12/M7): solo su README.
  local con_readme; con_readme=$(proyectos_de_leccion "$mod"); [ "$mod" != "s7" ] || con_readme="blog-api"
  echo
  echo "📋 Plataforma: lección de ejercicio del Módulo ${mod#s}"
  if [ "$generado" = 1 ]; then
    for p in $con_readme; do
      repo=$(repo_de "$p" "$et")
      echo "   1. Abre el README de la rama (ya es la lección, con los nombres de este cohorte):"
      echo "        https://github.com/$repo/blob/$mod/start/README.md"
    done
    echo "   2. Cópialo entero y pégalo en la lección, debajo del título."
    echo "   3. En la cabecera de la lección pon la fecha límite y «Repositorio:» con el enlace del repo del cohorte."
    echo "      (El README no lleva título, fecha ni «Repositorio:»: son de la plataforma.)"
  else
    echo "   ⚠️  Esta rama trae un README ANTERIOR, más corto que la lección: NO lo pegues en su lugar."
    echo "   Sustituye en la lección TODAS las apariciones de:"
    for p in $(proyectos_de_leccion "$mod"); do echo "     $(base_de "$p")  →  $(base_de "$p")-$et"; done
    echo "   y rellena la fecha límite y «Repositorio:» de la cabecera."
    for p in $con_readme; do echo "   Para comparar: https://github.com/$(repo_de "$p" "$et")/blob/$mod/start/README.md"; done
  fi
}

# Empuja una rama del clon del canónico al repo del cohorte, con sus instrucciones
# ya reescritas. Nunca --force: si ya está publicada con otro contenido y alguien
# trabajó encima, falla en vez de pisarlo.
empujar () {
  local clon="$1" repo="$2" r="$3" et="$4" sha
  sha=$(preparar_rama "$clon" "$r" "$et" "${5:-}" "${6:-}")
  if [ -n "$SIMULAR" ]; then echo "  [simulado] push $r ($sha) → $repo"; return 0; fi
  if git_gh -C "$clon" push -q "${REMOTO_BASE:-https://github.com}/$repo.git" "$sha:refs/heads/$r" 2>/dev/null; then
    echo "  ✓ $r publicada en $repo"
  else
    local remoto; remoto=$(gh api "repos/$repo/branches/${r/\//%2F}" --jq .commit.sha 2>/dev/null || true)
    if [ "$remoto" = "$sha" ]; then
      echo "  = $r ya estaba publicada y no ha cambiado. Nada que hacer."
    elif [ -n "$remoto" ]; then
      echo "✗ $r ya existe en $repo con OTRO contenido y no se sobrescribe (sin --force)."
      echo "  Si el canónico cambió después de publicarla, decide a mano qué hacer: puede haber forks encima."; exit 1
    else
      echo "✗ No se pudo publicar $r con la cuenta «${CUENTA}». ¿Tiene permiso de escritura en $repo?"; exit 1
    fi
  fi
}

proyectos_pedidos () {   # «todos», «blog» (los cuatro del blog) o uno concreto; `crear` pide «flowsync» por defecto
  case "${1:-todos}" in
    todos) echo "$PROYECTOS" ;;
    blog)  echo "blog-legacy blog-api blog-web blog-ai" ;;
    *)     base_de "$1" >/dev/null && echo "$1" ;;
  esac
}

# Crea el repo de un proyecto para un cohorte (con su rama de partida) si no existe.
#   $3 = 1 → sin el aviso de plataforma (lo da después el `publicar` que lo ha provocado)
crear_uno () {
  local p="$1" et="$2" sin_aviso="${3:-}" src repo ini clon
  src=$(fuente_de "$p"); repo=$(repo_de "$p" "$et"); ini=$(rama_inicial_de "$p"); clon=$(clon_de "$p")
  if existe_repo "$repo"; then
    echo "= $repo ya existe: no se toca. ($0 estado $et para ver sus ramas.)"; return 0
  fi
  existe_en "$clon" "$ini" || { echo "✗ «${ini}» no existe en $src: el cohorte nacería sin rama de partida. No se crea $repo."; exit 1; }
  echo "Creando $repo desde ${src}…"
  hacer gh repo create "$repo" --template "$src" --public --description "$(descripcion_de "$p" "$et")"
  # SIN --include-all-branches: solo viene `main`. Es deliberado (ver cabecera).
  echo "  ✓ repo creado (solo main)"
  [ -n "$SIMULAR" ] || sleep 3   # GitHub tarda un instante en dejar el repo utilizable
  empujar "$clon" "$repo" "$ini" "$et"
  if [ -z "$sin_aviso" ]; then
    local g=0; readme_generado "$clon" "$ini" && g=1
    aviso_para_la_plataforma "$et" "${ini%%/*}" "$g"
  fi
}

cmd_crear () {
  local et="$1"; etiqueta_valida "$et"
  local lista; lista=$(proyectos_pedidos "${2:-flowsync}")
  # Primero se comprueba que TODOS los canónicos existen: mejor no crear ninguno
  # que dejar un cohorte a medias.
  local p; for p in $lista; do clon_de "$p" >/dev/null; done
  for p in $lista; do crear_uno "$p" "$et"; done
  echo
  echo "✓ Listo. Cada repo arranca con main + su rama de partida (FlowSync s1/start; blog-legacy s6/start; blog-* s7/start)."
  echo "  Tras impartir cada módulo, un solo comando publica su solución (y en FlowSync la partida del siguiente):"
  echo "    $0 publicar $et s2 start   # FlowSync: s1/end + s2/start  (s1 end hace lo mismo)"
  echo "    $0 publicar $et s6 end     # blog-legacy: la solución del Módulo 6"
  echo
  for p in $lista; do echo "  https://github.com/$(repo_de "$p" "$et")"; done
  case "$lista" in flowsync) echo
    echo "  Los repos del blog (Módulos 6 y 7) no se crean ahora: los crea \`publicar\` la primera vez que publiques esos módulos,"
    echo "  y te da entonces su URL. Si prefieres tenerlos ya:  $0 crear $et blog" ;; esac
}

# FlowSync: tras impartir el Módulo K se publican JUNTAS sK/end y s(K+1)/start.
publicar_flowsync () {
  local et="$1" mod="$2" tipo="$3" rama="$2/$3" n="${2#s}"
  local repo clon; repo=$(repo_de flowsync "$et"); clon=$(clon_de flowsync)
  existe_en "$clon" "$rama" || { echo "✗ «${rama}» no existe en $(fuente_de flowsync). Ramas que hay: $(ramas_sN_de "$clon")"; exit 1; }
  # Se llega al par por cualquiera de sus dos ramas:
  #   publicar s2 start  → s1/end + s2/start
  #   publicar s1 end    → s1/end + s2/start   (lo mismo)
  # Si la otra mitad no existe en el canónico, sale sola la pedida: s1/start (no
  # hay Módulo 0) y la última end (no hay start siguiente todavía).
  #   publicar s8 start-setup → s7/end (si existe) + s8/start + s8/start-setup
  #     (una variante trae su base: la partida y la solución anterior que esa partida entrega)
  local fin ini extra=""
  case "$tipo" in
    end)   fin="$rama"; ini="s$((n+1))/start" ;;
    start) fin="s$((n-1))/end"; ini="$rama" ;;
    *)     fin="s$((n-1))/end"; ini="$mod/start"; extra="$rama" ;;
  esac
  local ramas=() b
  for b in "$fin" "$ini" $extra; do
    if existe_en "$clon" "$b"; then ramas+=("$b")
    elif [ "$b" != "s0/end" ]; then echo "  (No hay «${b}» en el canónico: se sigue sin ella.)"; fi
  done
  # GUARDARRAÍL: lo que reparte una solución no se ve en el nombre de la rama.
  #   sN/end         → la solución del Módulo N
  #   sN/start, N>1  → la solución del Módulo N-1, que es su base
  local modulo=""
  if [ "$tipo" = "end" ]; then modulo="$n"
  elif [ "$n" -gt 1 ]; then modulo=$((n-1)); fi
  if [ -n "$modulo" ]; then
    local lista=""; for b in "${ramas[@]}"; do lista="${lista:+$lista, }«${b}»"; done
    echo "⚠️  ATENCIÓN: vas a publicar $lista en $repo."
    if [ "$tipo" != "end" ] && ! existe_en "$clon" "$fin"; then
      # Sin «s(N-1)/end» en FlowSync (el Módulo N-1 no es de FlowSync: s8/start parte de s5/end),
      # decir «Módulo N-1» sería falso. Se avisa igual, sin inventar cuál.
      echo "    Esta rama parte de la solución de un módulo anterior (no hay «${fin}» en este proyecto). Hazlo solo si ese módulo ya se impartió."
    else
      echo "    Eso entrega la SOLUCIÓN del Módulo $modulo. Hazlo solo si el Módulo $modulo ya se impartió."
    fi
    if existe_en "$clon" "$fin" && existe_en "$clon" "$ini"; then
      local propios; propios=$(git -C "$clon" rev-list --count "refs/heads/$fin..refs/heads/$ini")
      if ! git -C "$clon" merge-base --is-ancestor "refs/heads/$fin" "refs/heads/$ini"; then
        echo "    ⚠️  «${ini}» NO desciende de «${fin}»: no es la cadena habitual del curso, revísala."
      elif [ "$propios" -gt 0 ]; then
        local sig_mod="${ini%%/*}"
        echo "    «${ini}» trae además $propios commit(s) propios: el punto de partida del Módulo ${sig_mod#s}."
      fi
    fi
    # Una variante sale de su partida pero PUEDE haberse quedado atrás (a `s8/start` se le
    # regeneró el README después de sacar `s8/start-setup`, y con razón: la variante lleva
    # el suyo). Por eso se pide historia compartida, no que `start` sea su antecesora.
    if [ -n "$extra" ] && existe_en "$clon" "$extra" && existe_en "$clon" "$ini"; then
      local base; base=$(git -C "$clon" merge-base "refs/heads/$ini" "refs/heads/$extra" 2>/dev/null || true)
      if [ -z "$base" ]; then
        echo "    ⚠️  «${extra}» no comparte historia con «${ini}»: una variante se construye a partir de su partida, revísala."
      else
        echo "    «${extra}» sale de «${ini}» (base ${base:0:7}) y trae $(git -C "$clon" rev-list --count "$base..refs/heads/$extra") commit(s) propios de preparación."
      fi
    fi
    confirmar
  fi
  local r; for r in "${ramas[@]}"; do empujar "$clon" "$repo" "$r" "$et"; done
  # El aviso es de la lección del módulo cuya `start` sale, no de la `end` que la acompaña.
  for r in "${ramas[@]}"; do case "$r" in */start)
    local g=0; readme_generado "$clon" "$r" && g=1
    aviso_para_la_plataforma "$et" "${r%%/*}" "$g" ;; esac; done
}

# Blog (Módulos 6 y 7): sin cadena. La start no destapa nada; la end es la solución.
publicar_blog () {
  local et="$1" mod="$2" tipo="$3" rama="$2/$3" n="${2#s}"; shift 3
  local lista="$*" p
  for p in $lista; do
    local clon; clon=$(clon_de "$p")
    existe_en "$clon" "$rama" || { echo "✗ «${rama}» no existe en $(fuente_de "$p"). Ramas que hay: $(ramas_sN_de "$clon")"; exit 1; }
  done
  if [ "$tipo" = "end" ]; then
    echo "⚠️  ATENCIÓN: vas a publicar «${rama}» en $(for p in $lista; do printf '%s ' "$(repo_de "$p" "$et")"; done)."
    echo "    Eso entrega la SOLUCIÓN del Módulo $n. Hazlo solo si el Módulo $n ya se impartió."
    confirmar
  fi
  for p in $lista; do empujar "$(clon_de "$p")" "$(repo_de "$p" "$et")" "$rama" "$et"; done
  # Módulo mixto (el 9): la lección y su aviso de plataforma son de FlowSync, ya salieron arriba.
  if [ "$tipo" = "start" ] && [ -z "${SIN_AVISO_PLATAFORMA:-}" ]; then
    local g=0 pr; pr=$(echo "$lista" | awk '{print $1}')
    # M7: su README de entrega es el de blog-api, que es el primero de la lista.
    readme_generado "$(clon_de "$pr")" "$rama" && g=1
    aviso_para_la_plataforma "$et" "$mod" "$g"
  fi
}

confirmar () {
  # Un módulo con dos proyectos (el 9) es UNA orden y se confirma UNA vez, no una por proyecto.
  [ -z "${YA_CONFIRMADO:-}" ] || { echo "    (ya confirmado arriba)"; return 0; }
  if [ -n "$SIMULAR" ]; then echo "    [simulado] aquí se pediría escribir SI"; YA_CONFIRMADO=1; return 0; fi
  local resp; read -r -p "    ¿Seguir? (escribe SI): " resp
  [ "$resp" = "SI" ] || { echo "  Cancelado."; exit 1; }
  YA_CONFIRMADO=1
}

cmd_publicar () {
  local et="$1" mod="${2:-}" tipo="${3:-}"; etiqueta_valida "$et"
  [[ "$mod"  =~ ^s[0-9]+$      ]] || { echo "✗ Módulo inválido: «${mod}» (sN)"; exit 1; }
  [[ "$tipo" =~ ^(start|end|start(-[a-z0-9]+)+)$ ]] || { echo "✗ Tipo inválido: «${tipo}» (start | end | start-<variante>, p. ej. start-setup)"; exit 1; }
  local proys; proys=$(proyectos_de_modulo "$mod")
  [ -n "$proys" ] || { echo "✗ El módulo «${mod}» no existe en el curso (hay s1..s14). No se intenta."; exit 1; }
  # FlowSync va por su cadena (sK/end + s(K+1)/start); los proyectos del blog, sin cadena. Un módulo
  # puede llevar los dos (el 9): primero FlowSync, después el blog, con UNA confirmación.
  local blog=" " p
  for p in $proys; do [ "$p" = flowsync ] || blog="$blog$p "; done
  # ANTES de publicar nada: si a un proyecto le falta el canónico o la rama, no se deja el módulo a medias
  # (FlowSync publicado y el blog sin publicar).
  for p in $proys; do clon_de "$p" >/dev/null; done
  # El COHORTE tiene que existir (su repo de FlowSync): un typo en la etiqueta no puede crear
  # un cohorte por accidente. Los repos del blog que falten SÍ se crean, más abajo.
  existe_repo "$(repo_de flowsync "$et")" || {
    echo "✗ El cohorte $et no existe (no tiene $(repo_de flowsync "$et")). ¿La etiqueta está bien escrita?"
    echo "  Si es un cohorte nuevo:  $0 crear $et"; exit 1; }
  for p in $blog; do
    existe_en "$(clon_de "$p")" "$mod/$tipo" || { echo "✗ «${mod}/${tipo}» no existe en $(fuente_de "$p"). Ramas que hay: $(ramas_sN_de "$(clon_de "$p")")"; exit 1; }
  done
  # Los repos que este módulo necesita y el cohorte aún no tiene se crean AHORA, con su rama de
  # partida (que no destapa nada): el TA no tiene que saber que existía un paso previo.
  local nuevos=" "
  for p in $proys; do
    existe_repo "$(repo_de "$p" "$et")" && continue
    echo "🆕 El cohorte $et aún no tiene el repo de «$(base_de "$p")» y el Módulo ${mod#s} lo necesita: se crea ahora."
    crear_uno "$p" "$et" 1
    nuevos="$nuevos$p "
  done
  if [[ " $proys " == *" flowsync "* ]]; then
    publicar_flowsync "$et" "$mod" "$tipo"
    [ "$blog" = " " ] || echo "  → y ahora el resto de los proyectos del Módulo ${mod#s}:"
  fi
  if [ "$blog" != " " ]; then
    if [[ " $proys " == *" flowsync "* ]]; then SIN_AVISO_PLATAFORMA=1 publicar_blog "$et" "$mod" "$tipo" $blog
    else publicar_blog "$et" "$mod" "$tipo" $blog; fi
  fi
  resumen_repos "$et" "$mod" "$proys" "$nuevos"
}

# Al terminar: qué repos son los de ESTA sesión, con su URL, y cuáles se han creado ahora.
resumen_repos () {
  local et="$1" mod="$2" proys="$3" nuevos="$4" p url marca
  echo
  echo "🔗 Repos de esta sesión (Módulo ${mod#s}, cohorte $et):"
  for p in $proys; do
    url="https://github.com/$(repo_de "$p" "$et")"; marca=""
    [[ "$nuevos" == *" $p "* ]] && marca="   🆕 creado ahora"
    echo "   $(base_de "$p"): $url$marca"
  done
  case "$mod" in
    s6) echo "   → Este es el repo de la sesión del Módulo 6: los alumnos forkean este." ;;
    s7) echo "   → Son los tres repos del polirepo del Módulo 7: los alumnos forkean los tres. La ENTREGA vive en $(base_de blog-api)-$et (el único con prompts.md); los otros dos solo se levantan." ;;
    s9) echo "   → El repo de los alumnos es el de FlowSync. El de blog-ai es del mentor (Bloque 5): no se comparte con los alumnos ni va en la lección." ;;
    *)  echo "   → Este es el repo de la sesión: los alumnos forkean este." ;;
  esac
}

# Una rama de un cohorte que YA está publicada. Dos casos, y se distinguen por la historia:
#   · la punta del cohorte es ANTECESORA de la del canónico → el commit derivado sale del
#     canónico y avanza en fast-forward (trae además su README generado);
#   · historia DISTINTA (el canónico se reescribió después de publicar el cohorte, p. ej.
#     el 2026-09-11) → el commit va sobre la punta del COHORTE, con el README copiado de la
#     misma rama del canónico y los nombres reescritos. Sigue siendo un fast-forward, y
#     no toca nada más de la rama.
reparar_rama () {
  local clon="$1" repo="$2" r="$3" et="$4" tip="$5" canon
  canon=$(git -C "$clon" rev-parse "refs/heads/$r")
  git_gh -C "$clon" fetch -q "${REMOTO_BASE:-https://github.com}/$repo.git" "refs/heads/$r:refs/cohorte/$r" 2>/dev/null \
    || { echo "  ✗ $r: no pude traer la rama de $repo"; return 1; }
  tip=$(git -C "$clon" rev-parse "refs/cohorte/$r")
  if git -C "$clon" merge-base --is-ancestor "$tip" "$canon"; then
    empujar "$clon" "$repo" "$r" "$et"
  else
    echo "  ↪ $r: historia distinta a la del canónico; el commit va sobre la punta del cohorte"
    empujar "$clon" "$repo" "$r" "$et" "$tip" "$canon"
  fi
}

# Reescribe las instrucciones de lo que un cohorte YA tiene publicado. Cada rama se empuja
# como fast-forward, así que no hay --force ni se pierde nada de los forks. No pide
# confirmación de «solución»: lo que se toca ya es público.
cmd_reparar () {
  local et="$1"; etiqueta_valida "$et"
  local p repo clon r
  for p in $PROYECTOS; do
    repo=$(repo_de "$p" "$et")
    gh api "repos/$repo" >/dev/null 2>&1 || { echo "= $repo no existe: nada que reparar."; continue; }
    clon=$(clon_de "$p")
    echo "$repo:"
    for r in $(gh api "repos/$repo/branches" --paginate --jq '.[].name' | grep -E '^s[0-9]+/'); do
      existe_en "$clon" "$r" || { echo "  ? $r está en el cohorte y no en el canónico: no se toca."; continue; }
      reparar_rama "$clon" "$repo" "$r" "$et" "" || true
    done
  done
}

cmd_estado () {
  local et="$1"; etiqueta_valida "$et"
  local p repo
  for p in $PROYECTOS; do
    repo=$(repo_de "$p" "$et")
    if lineas=$(gh api "repos/$repo/branches" --paginate --jq '.[].name' 2>/dev/null); then
      echo "$repo:"; echo "$lineas" | sort -V | sed 's/^/  /'
    else
      echo "$repo:  ✗ no existe"
    fi
  done
}

# Crea el canónico de un proyecto del blog a partir de su repo público de hoy
# (que pasa a ser, de hecho, el cohorte 202608: igual que flowsync-ai4devs).
# Privado y marcado como plantilla, con TODAS las ramas, como el de FlowSync.
cmd_fundar () {
  local p="${1:-}"; base_de "$p" >/dev/null
  local src dst; src="$ORG/$(base_de "$p")"; dst=$(fuente_de "$p")
  if gh api "repos/$dst" >/dev/null 2>&1; then echo "= $dst ya existe. Nada que hacer."; exit 0; fi
  gh api "repos/$src" >/dev/null 2>&1 || { echo "✗ No existe el repo público $src del que fundar."; exit 1; }
  echo "Vas a crear $dst (PRIVADO, plantilla) como espejo de TODAS las ramas de $src:"
  gh api "repos/$src/branches" --paginate --jq '.[].name' | sort -V | sed 's/^/    /'
  echo "  A partir de aquí, $src queda como el cohorte que ya corre, y los cohortes nuevos salen de $dst."
  confirmar
  git_gh clone -q --bare "https://github.com/$src.git" "$TMP/fundar-$p"
  hacer gh repo create "$dst" --private --description "Canónico de $(base_de "$p"): se edita aquí; los cohortes se derivan con publicar-cohorte.sh"
  [ -n "$SIMULAR" ] || sleep 3
  if [ -n "$SIMULAR" ]; then echo "  [simulado] push --all $src → $dst"; else
    git_gh -C "$TMP/fundar-$p" push -q "https://github.com/$dst.git" --all
  fi
  hacer gh api -X PATCH "repos/$dst" -F is_template=true
  echo "  ✓ $dst creado, con sus ramas y marcado como plantilla."
}

# ---------------------------------------------------------------------------
# Este script vive en la máquina del TA, así que PUEDE QUEDARSE VIEJO. Y lo que
# se queda viejo es el guardarraíl: una copia de antes del aviso de "esto
# destapa la solución del módulo anterior" publica sin preguntar y nadie se
# entera. Antes de actuar se compara con la copia del canónico y, si la tuya es
# MÁS VIEJA, se descarga la última y se relanza el mismo comando con ella.
#
# Quién manda lo decide `VERSION_SCRIPT`, no los bytes: así una copia MÁS NUEVA que
# la del canónico (la del repo de diseño, aún sin sincronizar) no se «actualiza»
# hacia atrás. Mismo número con bytes distintos es una edición sin subir versión
# y se rechaza, porque es justo el caso que este control existe para cazar.
version_de () { sed -n 's/^VERSION_SCRIPT="\([^"]*\)".*/\1/p' "$1" | head -1; }
# «2026-09-23.10» > «2026-09-23.9»: se compara por partes, no como texto.
mas_nueva () { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1 -k2,2n | tail -1)" = "$1" ] && [ "$1" != "$2" ]; }

comprobar_version () {
  local nuevo="$TMP/publicar-cohorte.nuevo"
  if ! gh api "repos/$FUENTE/contents/scripts/publicar-cohorte.sh" --jq '.content' 2>/dev/null | base64 -d > "$nuevo" 2>/dev/null || [ ! -s "$nuevo" ]; then
    echo "⚠️  No pude comprobar si este script está al día (sin acceso a $FUENTE). Sigo, pero puede ser una copia vieja."
    return 0
  fi
  cmp -s "$nuevo" "$0" && return 0
  if ! { bash -n "$nuevo" 2>/dev/null && head -1 "$nuevo" | grep -q '^#!'; }; then
    echo "✗ La copia del canónico no parece un script válido (¿descarga cortada o archivo roto?). No sigo."; exit 1
  fi
  local vlocal vremota; vlocal=$(version_de "$0"); vremota=$(version_de "$nuevo")
  vlocal="${vlocal:-0}"; vremota="${vremota:-0}"
  if [ "$vlocal" = "$vremota" ]; then
    echo "✗ Este script y el del canónico dicen ser la versión $vlocal pero NO son iguales."
    echo "  Alguien editó uno sin subir VERSION_SCRIPT. No sigo: la diferencia puede estar en los avisos de seguridad."
    exit 1
  fi
  if mas_nueva "$vlocal" "$vremota"; then
    echo "⚠️  Tu copia ($vlocal) es MÁS NUEVA que la del canónico ($vremota): falta sincronizarla allí. Sigo con la tuya."
    return 0
  fi
  echo "↻ Tu copia del script es la $vlocal y la última es la $vremota: la descargo."
  if [ -w "$0" ]; then
    cp "$0" "$0.anterior" && cp "$nuevo" "$0" && chmod +x "$0"
    echo "  ✓ Actualizado (la anterior queda en $0.anterior). Relanzo con la nueva."
    rm -rf "$TMP"; SIN_COMPROBAR_VERSION=1 exec bash "$0" "$@"
  fi
  echo "✗ No puedo escribir en $0. Actualízalo a mano:"
  echo "    gh api repos/$FUENTE/contents/scripts/publicar-cohorte.sh --jq .content | base64 -d > \"$0\""
  exit 1
}
if [ -z "${PUBLICAR_COHORTE_SOLO_FUNCIONES:-}" ]; then
  [ -n "${SIN_COMPROBAR_VERSION:-}" ] || comprobar_version "$@"
fi

if [ -z "${PUBLICAR_COHORTE_SOLO_FUNCIONES:-}" ]; then
case "${1:-}" in crear|publicar|estado|fundar|reparar) comprobar_cuenta "$1" ;; esac

case "${1:-}" in
  crear)    shift; cmd_crear "$@" ;;
  publicar) shift; cmd_publicar "$@" ;;
  estado)   shift; cmd_estado "$@" ;;
  fundar)   shift; cmd_fundar "$@" ;;
  reparar)  shift; cmd_reparar "$@" ;;
  *) sed -n '2,/^set -euo/{/^#/p;}' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
fi
