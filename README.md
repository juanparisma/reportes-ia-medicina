# Reportes — IA en medicina

Informes recurrentes del **Dr. Juan Camilo Paris** (médico general) sobre cómo
se está usando la inteligencia artificial en medicina. Cada informe es un
HTML autocontenido (sin JS pesado, sin tracking, sin paywall) pensado para
leerse en escritorio o celular.

> Hosting: GitHub Pages. Cada `.html` del repo se sirve en
> `https://juanparisma.github.io/reportes-ia-medicina/<slug>.html`.
> El [`index.html`](./index.html) lista los informes publicados.

## Tipos de informe

| Tipo | Frecuencia | Slug |
|---|---|---|
| **¿Cómo se está usando la IA en medicina?** | Semanal (lunes) | `YYYY-MM-DD-ia-medicina.html` |
| **Trabajo diario en Claude Code** | Diario (no listado) | `YYYY-MM-DD-trabajo-claude-<id>.html` |

El informe diario se publica en el repo pero con `SKIP_INDEX` activado:
queda accesible solo por enlace directo, no aparece en el índice público.

## Cómo se genera

Cada informe se construye con un comando del operador (`/informe-ia-medicina`,
`/informe-diario-claude`) ejecutado por una rutina programada de Claude
Desktop. El comando: (a) hace deep-research o recolecta commits del día,
(b) arma un HTML con la identidad visual del operador, (c) lo commitea a este
repo, (d) lo notifica por WhatsApp vía CallMeBot.

El código de los comandos y la lógica vive fuera de este repo (en el OS del
operador). Aquí solo se publican los entregables ya construidos.

## Privacidad

Este repo es **público**. No contiene datos clínicos, casos reales ni
información identificable de pacientes. Solo análisis general sobre IA y
medicina, y resúmenes del propio trabajo del operador en Claude Code (que es
público por naturaleza: commits, sesiones de pair programming, decisiones).

## Autor

Dr. Juan Camilo Paris — médico general, Hospital General de Medellín.
