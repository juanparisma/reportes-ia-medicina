#!/usr/bin/env bash
# ============================================================================
# setup-pc-casa.sh — Fase 0 del "espejo vivo": deja el PC de casa a punto.
#
# Hace de un tirón (idempotente — se puede correr varias veces sin daño):
#   1. Instala Python 3, gh CLI y FFmpeg si faltan (vía winget)
#   2. Login de GitHub (gh auth login) si hace falta
#   3. Clona los 4 repos privados (o los actualiza si ya están)
#   4. Restaura Sinapsis (~/.claude) desde sinapsis-config
#   5. Verifica que el dashboard genera sin error
#
# CÓMO CORRERLO en el PC de casa (Git-Bash):
#   curl -fsSL https://juanparisma.github.io/reportes-ia-medicina/setup-pc-casa.sh -o setup.sh && bash setup.sh
#
# NO hace (a propósito):
#   - NO registra las tareas programadas (eso es Fase 3; siguen en el itinerante)
#   - NO copia secrets (.env.local) — llegan por Syncthing en Fase 2 (decisión 2026-06-10)
# ============================================================================

echo "==================================================================="
echo "  SETUP PC DE CASA — Fase 0 del espejo vivo"
echo "  Fecha: $(date)"
echo "==================================================================="
PASS=0; WARN=0; FAIL=0; REABRIR=0
ok(){   echo "  🟢 $1"; PASS=$((PASS+1)); }
warn(){ echo "  🟡 $1"; WARN=$((WARN+1)); }
bad(){  echo "  🔴 $1"; FAIL=$((FAIL+1)); }

# ── 0. Usuario de Windows ──
echo; echo "── 0. Usuario de Windows ──"
USR="${USERNAME:-$(whoami)}"
case "$(echo "$USR" | tr '[:upper:]' '[:lower:]')" in
  equipo) ok "Usuario: $USR (las rutas de Sinapsis funcionan tal cual)";;
  *) warn "Usuario: $USR ≠ Equipo → habrá que ajustar rutas hardcodeadas (ver RESTORE.md §3)";;
esac

# ── 1. Python 3 ──
echo; echo "── 1. Python 3 ──"
if py -3 --version >/dev/null 2>&1; then
  ok "Python ya está: $(py -3 --version 2>&1)"
else
  echo "  Instalando Python 3.12 con winget (aceptá el aviso si aparece)..."
  winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
  # El launcher 'py' puede quedar fuera del PATH de esta sesión
  export PATH="$PATH:/c/Windows:$LOCALAPPDATA/Programs/Python/Launcher"
  if py -3 --version >/dev/null 2>&1; then
    ok "Python instalado: $(py -3 --version 2>&1)"
  else
    warn "Python instalado pero no visible aún → cerrá Git-Bash, reabrilo y corré este script de nuevo"
    REABRIR=1
  fi
fi

# ── 2. gh CLI (GitHub) ──
echo; echo "── 2. gh CLI ──"
[ -x "/c/Program Files/GitHub CLI/gh.exe" ] && export PATH="$PATH:/c/Program Files/GitHub CLI"
if command -v gh >/dev/null 2>&1; then
  ok "gh CLI ya está: $(gh --version | head -1)"
else
  echo "  Instalando gh CLI con winget (decí SÍ si Windows pide permiso)..."
  winget install -e --id GitHub.cli --accept-package-agreements --accept-source-agreements
  export PATH="$PATH:/c/Program Files/GitHub CLI"
  if command -v gh >/dev/null 2>&1; then
    ok "gh CLI instalado: $(gh --version | head -1)"
  else
    warn "gh instalado pero no visible aún → cerrá Git-Bash, reabrilo y corré este script de nuevo"
    REABRIR=1
  fi
fi

# ── 2b. FFmpeg (casa también edita video — decisión 2026-06-10) ──
echo; echo "── 2b. FFmpeg ──"
if command -v ffmpeg >/dev/null 2>&1; then
  ok "FFmpeg ya está: $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f1-3)"
else
  echo "  Instalando FFmpeg con winget..."
  winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
  if command -v ffmpeg >/dev/null 2>&1; then
    ok "FFmpeg instalado"
  else
    warn "FFmpeg instalado pero no visible aún → reabrí Git-Bash y corré este script de nuevo"
    REABRIR=1
  fi
fi

if [ "$REABRIR" -eq 1 ]; then
  echo
  echo "  ⏸️  PAUSA NECESARIA: reabrí Git-Bash y volvé a correr:  bash setup.sh"
  echo "      (todo lo ya hecho se salta solo; sigue desde donde quedó)"
  exit 0
fi

# ── 3. Login de GitHub ──
echo; echo "── 3. Login de GitHub ──"
if gh auth status >/dev/null 2>&1; then
  ok "gh ya autenticado como: $(gh api user -q .login 2>/dev/null || echo '?')"
else
  echo "  Vas a iniciar sesión en GitHub. Elegí: GitHub.com → HTTPS → Login with web browser."
  echo "  (Te da un código de 8 letras; lo pegás en el navegador con tu cuenta juanparisma.)"
  gh auth login -h github.com -p https -w
  if gh auth status >/dev/null 2>&1; then ok "Login OK"; else bad "Login falló — corré 'gh auth login' a mano y repetí el script"; exit 1; fi
fi
# Que git use las credenciales de gh (para pull/push sin pedir clave)
gh auth setup-git >/dev/null 2>&1 && ok "git configurado con las credenciales de gh"

# ── 4. Clonar los 4 repos ──
echo; echo "── 4. Repos ──"
clone_repo(){ # $1=repo  $2=destino
  if [ -d "$2/.git" ]; then
    if git -C "$2" pull --ff-only >/dev/null 2>&1; then ok "$1: ya estaba → actualizado (git pull)"
    else warn "$1: ya estaba pero el pull falló (¿cambios locales?) — revisar luego"; fi
  else
    if gh repo clone "juanparisma/$1" "$2" -- --quiet 2>/dev/null; then ok "$1 → $2"
    else bad "$1: clon falló (¿permisos del repo?)"; fi
  fi
}
clone_repo sinapsis-config       "$HOME/sinapsis-config"
clone_repo iamasters-os          "$HOME/iamasters-os"
clone_repo segundo-cerebro       "$HOME/Desktop/cerebro"
clone_repo reportes-ia-medicina  "$HOME/reportes-ia-medicina"

# ── 5. Restaurar Sinapsis en ~/.claude ──
echo; echo "── 5. Restaurar Sinapsis ──"
SC="$HOME/sinapsis-config"
if [ -d "$SC/skills" ]; then
  mkdir -p "$HOME/.claude/skills/_sched" "$HOME/.claude/commands" \
           "$HOME/.claude/scheduled-tasks" "$HOME/.claude/homunculus/projects"
  cp -r "$SC/skills/"*          "$HOME/.claude/skills/"
  cp -r "$SC/commands/"*        "$HOME/.claude/commands/"        2>/dev/null
  cp -r "$SC/scheduled-tasks/"* "$HOME/.claude/scheduled-tasks/" 2>/dev/null
  cp    "$SC/settings.json"     "$HOME/.claude/settings.json"    2>/dev/null
  ok "Config de Sinapsis copiada a ~/.claude (skills, commands, tareas, settings)"
  [ -f "$HOME/.claude/skills/_install-state.json" ] \
    && ok "Install-state del OS restaurado (el gate de instalación no va a molestar)" \
    || warn "No vino _install-state.json — el OS puede pedir 'instalación incompleta' al abrir"
else
  bad "No encuentro $SC/skills — ¿falló el clon de sinapsis-config?"
fi

# ── 6. Verificación ──
echo; echo "── 6. Verificación ──"
if py -3 "$HOME/.claude/skills/_generate-dashboard.py" >/dev/null 2>&1; then
  ok "Dashboard de Sinapsis genera sin error"
else
  warn "El dashboard no generó (no es grave hoy; lo vemos al revisar)"
fi
command -v claude >/dev/null 2>&1 && ok "Claude Code CLI visible" || warn "claude no está en PATH de Git-Bash (en PowerShell sí puede estar)"

# ── Resumen ──
echo; echo "==================================================================="
echo "  RESUMEN:  🟢 $PASS    🟡 $WARN    🔴 $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ Fase 0 COMPLETA. Quedan a mano:"
  echo "     1. Energía → Suspender/Hibernar = NUNCA (si no lo hiciste ya)"
  echo "     2. Secrets (.env.local): llegan solos por Syncthing en Fase 2;"
  echo "        si los necesitás antes, copialos a mano desde el otro PC"
  echo "     3. NO actives tareas programadas acá todavía — eso es Fase 3"
  echo "  ➡️  SIGUIENTE: Fase 1 — instalar Tailscale en los DOS PCs."
else
  echo "  ⛔ Hay $FAIL punto(s) 🔴 arriba. Pasá la captura y lo resolvemos."
fi
echo "==================================================================="
