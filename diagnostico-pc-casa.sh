#!/usr/bin/env bash
# ============================================================================
# diagnostico-pc-casa.sh — ¿Sirve el PC de casa como anfitrión 24/7 + estación
# secundaria del "espejo vivo" de Sinapsis?
#
# CÓMO CORRERLO en el PC de casa (Windows + Git-Bash):
#   1. Copiá este archivo al PC de casa (USB, WhatsApp, o git).
#   2. Abrí Git-Bash y ejecutá:   bash diagnostico-pc-casa.sh
#   (No instala ni cambia nada — solo mira y reporta 🟢🟡🔴.)
# ============================================================================

echo "==================================================================="
echo "  DIAGNÓSTICO PC DE CASA — espejo vivo Sinapsis"
echo "  Fecha: $(date)"
echo "==================================================================="
PASS=0; WARN=0; FAIL=0
ok(){   echo "  🟢 $1"; PASS=$((PASS+1)); }
warn(){ echo "  🟡 $1"; WARN=$((WARN+1)); }
bad(){  echo "  🔴 $1"; FAIL=$((FAIL+1)); }
ps1(){ powershell -NoProfile -Command "$1" 2>/dev/null | tr -d '\r'; }

echo; echo "── 1. Sistema operativo ──"
SO=$(ps1 "(Get-CimInstance Win32_OperatingSystem).Caption")
echo "  SO: ${SO:-desconocido}"
case "$SO" in *Windows*1[01]*|*Windows*Server*) ok "Windows compatible";; *Windows*) warn "Windows viejo: actualizá si podés";; *) warn "No detecté Windows 10/11";; esac

echo; echo "── 2. Memoria RAM ──"
ramB=$(ps1 "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory")
if [[ "$ramB" =~ ^[0-9]+$ ]]; then
  ramGB=$(( ramB / 1024 / 1024 / 1024 ))
  if   [ "$ramGB" -ge 16 ]; then ok   "RAM: ${ramGB} GB (cómodo para todo)"
  elif [ "$ramGB" -ge 8  ]; then warn "RAM: ${ramGB} GB (OK como anfitrión; justo para apps Next.js pesadas)"
  else bad "RAM: ${ramGB} GB (poco; <8 GB va a sufrir)"; fi
else warn "RAM: no pude leerla"; fi

echo; echo "── 3. CPU ──"
cores=${NUMBER_OF_PROCESSORS:-$(nproc 2>/dev/null)}
if [[ "$cores" =~ ^[0-9]+$ ]]; then
  [ "$cores" -ge 4 ] && ok "CPU: $cores núcleos lógicos" || warn "CPU: $cores núcleos (justo, pero el host es liviano)"
else warn "CPU: desconocido"; fi

echo; echo "── 4. Disco (C:) ──"
freeKB=$(df -k /c 2>/dev/null | awk 'NR==2{print $4}')
if [[ "$freeKB" =~ ^[0-9]+$ ]]; then
  freeGB=$(( freeKB / 1024 / 1024 ))
  if   [ "$freeGB" -ge 80 ]; then ok   "Libre en C:: ${freeGB} GB"
  elif [ "$freeGB" -ge 40 ]; then warn "Libre en C:: ${freeGB} GB (alcanza; vigilá node_modules y videos)"
  else bad "Libre en C:: ${freeGB} GB (poco para varios proyectos)"; fi
else warn "No pude medir el disco"; fi
mediaType=$(ps1 "(Get-PhysicalDisk | Select-Object -First 1 -ExpandProperty MediaType)")
case "$mediaType" in *SSD*) ok "Disco tipo: SSD (rápido)";; *HDD*) warn "Disco tipo: HDD (mecánico, más lento; SSD recomendado)";; *) echo "  ·  Tipo de disco: ${mediaType:-no detectado}";; esac

echo; echo "── 5. Software requerido ──"
if command -v git >/dev/null 2>&1; then ok "Git: $(git --version)"; else bad "Git: NO instalado (REQUERIDO)"; fi
if command -v node >/dev/null 2>&1; then
  nv=$(node --version); maj=$(echo "$nv" | sed 's/v\([0-9]*\).*/\1/')
  [ "${maj:-0}" -ge 18 ] && ok "Node.js: $nv" || warn "Node.js: $nv (viejo; usá v20+)"
else bad "Node.js: NO instalado (REQUERIDO para los hooks)"; fi
if py -3 --version >/dev/null 2>&1; then ok "Python: $(py -3 --version 2>&1) (vía 'py -3')"
elif command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q "Python 3"; then ok "Python: $(python --version 2>&1)"
else warn "Python 3: NO detectado (sin él se desactiva la observación y el dashboard)"; fi
if command -v claude >/dev/null 2>&1; then ok "Claude Code CLI: presente"; else warn "Claude Code: no está en PATH (verificá la instalación)"; fi
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh CLI: instalado y AUTENTICADO"; else warn "gh CLI: instalado pero SIN login (corré: gh auth login)"; fi
else warn "gh CLI: no instalado (recomendado para clonar tus repos privados)"; fi
if [ -x "/c/Program Files/Google/Chrome/Application/chrome.exe" ] || [ -x "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" ]; then ok "Chrome: presente (para PDF/MCP)"; else warn "Chrome: no encontrado"; fi
command -v ffmpeg >/dev/null 2>&1 && ok "FFmpeg: presente" || warn "FFmpeg: no instalado (solo si vas a renderizar video)"

echo; echo "── 6. Red y energía (rol 24/7) ──"
ping -n 2 github.com >/dev/null 2>&1 && ok "Internet: OK (GitHub alcanzable)" || bad "Internet: sin conexión a GitHub"
echo "  ⚠️  CONFIGURAR A MANO (no se mide acá):"
echo "      Panel de Energía → Suspender / Hibernar = NUNCA, Apagar pantalla = a gusto."
echo "      Sin esto, el PC se duerme y deja de ser 24/7 (las automatizaciones no corren)."

echo; echo "==================================================================="
echo "  RESUMEN:  🟢 $PASS    🟡 $WARN    🔴 $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "  VEREDICTO: ✅ SIRVE. Resolvé los 🟡 (opcionales/recomendados) y seguimos con la Fase 0."
else
  echo "  VEREDICTO: ⛔ Hay $FAIL punto(s) 🔴 que resolver antes (mirá arriba)."
fi
echo "==================================================================="
echo "Pasá este resumen (texto o captura) y te digo el siguiente paso exacto."
