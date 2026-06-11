#!/usr/bin/env bash
# ============================================================================
# fase2-pc-casa.sh — Fase 2 del "espejo vivo": Syncthing en el PC de casa.
#
# Hace (idempotente — se puede correr varias veces):
#   1. Instala Syncthing (winget) si falta
#   2. Genera la identidad del equipo y arranca el servidor
#   3. Configura las 4 carpetas del espejo + .stignore (exclusiones)
#   4. Empareja con el PC itinerante (desktop-vmcrgk4)
#   5. Crea el autostart (Syncthing arranca con Windows — rol 24/7)
#   6. Imprime el DEVICE ID de casa → pasarlo al otro PC para cerrar el círculo
#
# CÓMO CORRERLO en el PC de casa (Git-Bash):
#   curl -fsSL https://juanparisma.github.io/reportes-ia-medicina/fase2-pc-casa.sh -o fase2.sh && bash fase2.sh
# ============================================================================

ITINERANTE_ID="BMS4TI6-LY6USVC-CIVP22H-3LQASQN-MXJTVGM-C7WGFPZ-DQSVEHM-XJS76QY"

PASS=0; WARN=0; FAIL=0
ok(){   echo "  🟢 $1"; PASS=$((PASS+1)); }
warn(){ echo "  🟡 $1"; WARN=$((WARN+1)); }
bad(){  echo "  🔴 $1"; FAIL=$((FAIL+1)); }

find_syncthing(){
  ls -d "$LOCALAPPDATA/Microsoft/WinGet/Packages/Syncthing.Syncthing"*/syncthing-windows-amd64-*/syncthing.exe 2>/dev/null | sort | tail -1
}

echo "==================================================================="
echo "  FASE 2 PC DE CASA — Syncthing (espejo vivo)"
echo "==================================================================="

# ── 1. Instalar Syncthing ──
echo; echo "── 1. Syncthing ──"
ST="$(find_syncthing)"
if [ -n "$ST" ]; then
  ok "Syncthing ya está: $("$ST" version 2>/dev/null | head -c 40)"
else
  echo "  Instalando con winget..."
  winget install -e --id Syncthing.Syncthing --source winget --accept-package-agreements --accept-source-agreements
  ST="$(find_syncthing)"
  [ -n "$ST" ] && ok "Syncthing instalado" || { bad "No encuentro syncthing.exe tras instalar"; exit 1; }
fi

# ── 2. Identidad + servidor ──
echo; echo "── 2. Identidad y servidor ──"
[ -f "$LOCALAPPDATA/Syncthing/config.xml" ] || "$ST" generate >/dev/null 2>&1
MYID=$("$ST" device-id 2>/dev/null)
[ -n "$MYID" ] && ok "Device ID de casa: $MYID" || { bad "No pude obtener el device ID"; exit 1; }
if ! "$ST" cli show system >/dev/null 2>&1; then
  ("$ST" serve --no-browser --no-console >/dev/null 2>&1 &)
  for i in $(seq 1 15); do sleep 2; "$ST" cli show system >/dev/null 2>&1 && break; done
fi
"$ST" cli show system >/dev/null 2>&1 && ok "Servidor Syncthing corriendo" || { bad "El servidor no responde"; exit 1; }

# ── 3. Carpetas del espejo ──
echo; echo "── 3. Carpetas ──"
mkdir -p "$HOME/editor-pro-max"   # única que no existe aún en casa; el sync la llena
add_folder(){ # $1=id  $2=label  $3=path-windows
  if "$ST" cli config folders list 2>/dev/null | grep -qx "$1"; then
    ok "Carpeta '$1' ya configurada"
  else
    "$ST" cli config folders add --id "$1" --label "$2" --path "$3" && ok "Carpeta '$1' → $3" || bad "No pude agregar '$1'"
  fi
}
add_folder iamasters-os   "iAmasters OS"   'C:\Users\Equipo\iamasters-os'
add_folder cerebro        "Cerebro"        'C:\Users\Equipo\Desktop\cerebro'
add_folder claude-home    "Claude Home"    'C:\Users\Equipo\.claude'
add_folder editor-pro-max "Editor Pro Max" 'C:\Users\Equipo\editor-pro-max'

# Seguridad del primer sync: ~/.claude de casa arranca SOLO-RECIBIR para que
# el estado vivo del itinerante mande. Se pasa a bidireccional al quedar verde.
"$ST" cli config folders claude-home type set receiveonly 2>/dev/null \
  && ok "claude-home en modo solo-recibir (primer sync seguro)" \
  || warn "No pude poner claude-home en receiveonly — revisar a mano"

# ── 4. Exclusiones (.stignore) ──
echo; echo "── 4. Exclusiones ──"
write_ignore(){ printf '%s\n' "$2" > "$1/.stignore" && ok ".stignore en $1"; }
write_ignore "$HOME/iamasters-os" '// Espejo vivo — solo regenerable/volátil (.env.local SÍ viaja)
(?d)node_modules
.next
.turbo
dist
build
out
__pycache__
*.bak-*
_backup_*
_PRE-REINSTALL-BACKUP_*
.sync-conflict-*
~syncthing~*.tmp'
write_ignore "$HOME/Desktop/cerebro" '// Espejo vivo — mínimas: todo el contenido viaja
(?d)node_modules
__pycache__
*.bak-*
_backup_*
.sync-conflict-*
~syncthing~*.tmp'
write_ignore "$HOME/.claude" '// Espejo vivo — homunculus/ y projects/ SÍ viajan
(?d)shell-snapshots
(?d)statsig
(?d)debug
(?d)session-env
(?d)ide
*.lock
*.log
_dashboard.html
skills/_sched
__pycache__
*.bak-*
_backup_*
.sync-conflict-*
~syncthing~*.tmp'
write_ignore "$HOME/editor-pro-max" '// Espejo vivo — regenerables de Remotion/Node
(?d)node_modules
.next
.turbo
dist
build
out
.remotion
__pycache__
.sync-conflict-*
~syncthing~*.tmp'
# que git no vea los .stignore (sin tocar .gitignore del repo)
for r in "$HOME/iamasters-os" "$HOME/Desktop/cerebro"; do
  [ -d "$r/.git" ] && grep -qx ".stignore" "$r/.git/info/exclude" 2>/dev/null || echo ".stignore" >> "$r/.git/info/exclude"
done

# ── 5. Emparejar con el itinerante ──
echo; echo "── 5. Emparejar ──"
if "$ST" cli config devices list 2>/dev/null | grep -q "$ITINERANTE_ID"; then
  ok "Itinerante ya registrado"
else
  "$ST" cli config devices add --device-id "$ITINERANTE_ID" --name pc-itinerante \
    && ok "Itinerante agregado (pc-itinerante)" || bad "No pude agregar el itinerante"
fi
for f in iamasters-os cerebro claude-home editor-pro-max; do
  "$ST" cli config folders "$f" devices add --device-id "$ITINERANTE_ID" >/dev/null 2>&1 \
    && ok "Carpeta '$f' compartida con el itinerante" \
    || warn "Carpeta '$f': ya estaba compartida (o revisar a mano)"
done

# ── 6. Autostart (rol 24/7 — este PC es el ancla del espejo) ──
echo; echo "── 6. Autostart ──"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/syncthing-launch.cmd" <<'EOF'
@echo off
set "ST="
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\Syncthing.Syncthing_Microsoft.Winget.Source_8wekyb3d8bbwe\syncthing-windows-amd64-*") do set "ST=%%D\syncthing.exe"
if not defined ST exit /b 1
start "" /b "%ST%" serve --no-browser --no-console
EOF
STARTUP="$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup"
printf '%s\r\n' 'CreateObject("Wscript.Shell").Run """C:\Users\Equipo\.local\bin\syncthing-launch.cmd""", 0, False' \
  > "$STARTUP/syncthing-autostart.vbs" \
  && ok "Autostart creado (Syncthing arranca con Windows)" \
  || warn "No pude crear el autostart — crear a mano en shell:startup"

# ── Resumen ──
echo; echo "==================================================================="
echo "  RESUMEN:  🟢 $PASS    🟡 $WARN    🔴 $FAIL"
echo ""
echo "  📋 DEVICE ID DE ESTE PC (pasarlo al PC itinerante para cerrar el círculo):"
echo ""
echo "      $MYID"
echo ""
echo "  El espejo queda en 'esperando al otro lado' hasta que el itinerante"
echo "  agregue este ID. La GUI local está en http://127.0.0.1:8384"
echo "==================================================================="
