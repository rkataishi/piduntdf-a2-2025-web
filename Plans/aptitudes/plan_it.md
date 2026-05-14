# Plan: Fix Responsive Mobile/Tablet — PIDUNTDF Web

> **Branch:** `fix/responsive-mobile-tablet` (creado 2026-05-14)
> **Objetivo:** Ajustar tamaños de página y distribución para que se vea bien en celulares y tablets, sin alterar el diseño desktop actual.
> **Restricción:** No afectar la distribución que está actualmente diseñada para desktop.

---

## Fase 1 — Setup de Herramientas y Directorios

### 1.1 Crear directorios operativos
- [ ] `mkdir -p .old/` (si no existe)
- [ ] `mkdir -p .temp/` y limpiar contenido previo
- [ ] `mkdir -p .logs/`
- [ ] `mkdir -p Plans/aptitudes/`

### 1.2 Configurar gitignore y .opencode
- [ ] Agregar `.opencode` al `.gitignore`
- [ ] Verificar `agent-browser.json` actual (`headed: false` → OK para CI, cambiar a `true` para screenshots)

**Verify:** `.gitignore` contiene `.opencode`, directorios existen.

---

## Fase 2 — Indexación del Código para Blast Radius

### 2.1 Indexar con Semble
El repo actual no está indexado en GitNexus. Semble permite indexación local on-demand.

- [ ] `semble_search` sobre los 3 archivos HTML para detectar **patrones CSS repetidos** entre `index.html`, `piduntdf-integrantes.html`, `piduntdf-documentos.html`
- [ ] `semble_find_related` para cada bloque CSS repetido y rastrear cross-file impact

**Query objetivo:** "CSS grid layout template columns flex rules repeated between HTML files"

### 2.2 Evaluar Blast Radius con Semble
Cada regla CSS que se modifique debe ser evaluada:

| Archivo | Regla CSS | Afecta qué elementos | Cross-file? |
|---------|-----------|---------------------|-------------|
| index.html | `.shell { padding: 0 40px }` | Todo el layout container | Sí, duplicado en los 3 HTML |
| index.html | `.logo-block { gap: 200px }` | Header logo + título | index.html + documentos |
| index.html | `.section-chapter { grid-template-columns: 280px 1fr }` | Todas las secciones con sidebar | index.html + documentos |
| index.html | `.metrics-row { grid-template-columns: repeat(4, 1fr) }` | Tarjetas de métricas | Solo index.html |
| index.html | `.cards-grid { grid-template-columns: repeat(3, 1fr) }` | Cards del equipo | Solo index.html |
| integrantes.html | `.member-card { grid-template-columns: 240px 1fr }` | Cards de investigadores | Solo integrantes |
| integrantes.html | `.team-grid { grid-template-columns: repeat(2, 1fr) }` | Grid de miembros | Solo integrantes |

### 2.3 Guardar en Engram
- [ ] `mem_save` con las reglas CSS compartidas entre archivos (type: `pattern`, topic_key: `css-shared-styles`)
- [ ] `mem_save` con el mapa de blast radius (type: `architecture`, topic_key: `css-blast-radius`)

**Verify:** Engram contiene el mapa de impacto cross-file, Semble confirma patrones duplicados.

---

## Fase 3 — Diagnóstico Visual con agent-browser

### 3.1 Preparar servidor local
Usar el script existente `start-agent-browser-session.sh` que:
- Levanta `python3 -m http.server` en puerto 8000
- Abre agent-browser apuntando al HTML

### 3.2 Capturar screenshots en 3 viewports por página

**Páginas a testear:** `index.html`, `piduntdf-integrantes.html`, `piduntdf-documentos.html`

**Viewports a capturar:**

| Dispositivo | Ancho | Alto | Comando |
|-------------|-------|------|---------|
| Desktop (baseline) | 1280 | 800 | `agent-browser set viewport 1280 800` |
| Tablet (iPad) | 768 | 1024 | `agent-browser set viewport 768 1024` |
| Mobile (iPhone 14) | 390 | 844 | `agent-browser set device "iPhone 14"` |

**Comandos por página y viewport:**
```bash
agent-browser --session-name piduntdf-web open http://127.0.0.1:8000/index.html
agent-browser --session-name piduntdf-web set viewport 1280 800
agent-browser --session-name piduntdf-web wait --load networkidle
agent-browser --session-name piduntdf-web screenshot --full --screenshot-dir .temp/desktop-index.png
```

### 3.3 Identificar fallas visuales
Comparar cada screenshot mobile/tablet contra baseline desktop. Documentar:

| Página | Viewport | Problema | Elemento afectado |
|--------|----------|----------|-------------------|
| index | tablet | ... | ... |
| index | mobile | ... | ... |
| integrantes | tablet | ... | ... |
| integrantes | mobile | ... | ... |
| documentos | tablet | ... | ... |
| documentos | mobile | ... | ... |

**Verify:** 9 screenshots capturados (3 páginas × 3 viewports), fallas documentadas.

---

## Fase 4 — Mapeo de Estilos Compartidos con Semble + Engram

### 4.1 Detectar duplicación CSS
Usar `semble_search` con queries específicas:
- "nav-bar nav-links nav-docs-btn shared navigation styles"
- "section-chapter side-label grid layout sidebar"
- "shell max-width padding container"
- "footer-row border-top padding"

### 4.2 Registrar hallazgos en Engram
- [ ] Cada patrón duplicado → `mem_save` con type: `pattern`, scope: `project`
- [ ] Decisiones de refactor (si aplica) → `mem_save` con type: `decision`

**Verify:** Semble confirma los archivos que comparten cada regla, Engram tiene registro.

---

## Fase 5 — Intervención Quirúrgica

### 5.1 Reglas de intervención
- **NO modificar reglas base desktop** — solo agregar/quitar dentro de `@media` queries
- **No refactorizar** CSS no relacionado con responsive
- **No tocar** estructura HTML
- Cada archivo se edita de a uno, con backup en `.old/` antes de editar

### 5.2 Breakpoints planificados
```
/* Ya existe */  @media (max-width: 900px) { ... }   ← tablet landscape
/* Ya existe */  @media (max-width: 800px) { ... }   ← integrantes.html
/* AGREGAR */    @media (max-width: 768px) { ... }   ← tablet portrait
/* AGREGAR */    @media (max-width: 600px) { ... }   ← mobile landscape
/* AGREGAR */    @media (max-width: 480px) { ... }   ← mobile portrait
```

### 5.3 Ajustes específicos por archivo

#### index.html
- [ ] `.shell` padding: `40px` → `24px` en tablet, `16px` en mobile
- [ ] `.logo-block` gap: `200px` → responsive (ya tiene ajuste en media query 900px)
- [ ] `.subtitle` `padding-left: 176px` y `white-space: nowrap` → ajustar en mobile (ya tiene ajuste parcial)
- [ ] `.section-chapter` grid 2 cols → 1 col (ya existe en 900px, verificar)
- [ ] `.metrics-row` 4 cols → 2 cols → 1 col
- [ ] `.cards-grid` 3 cols → 2 cols → 1 col
- [ ] `.impact-item` grid `200px 1fr` → 1 col
- [ ] `.nav-bar` flex-wrap y gap en mobile
- [ ] `.nav-links` gap: `32px` → reducir en mobile
- [ ] `body` font-size: `15px` → `14px` en mobile

#### piduntdf-integrantes.html
- [ ] `.shell` padding (mismo que index)
- [ ] `.member-card` grid `240px 1fr` → 1 col (ya existe en 800px)
- [ ] `.team-grid` 2 cols → 1 col (ya existe en 800px)
- [ ] `.section-header h1` font-size: `36px` → reducir en mobile
- [ ] `.category-label` flex-wrap para mobile
- [ ] `.nav-bar` padding y gap

#### piduntdf-documentos.html
- [ ] `.shell` padding (mismo que index)
- [ ] `.logo-block` y `.subtitle` (mismo fix que index)
- [ ] `.section-chapter` grid (mismo fix que index)
- [ ] `.notice` padding ajustar en mobile
- [ ] `.nav-bar` padding y gap

### 5.4 Orden de edición
1. `index.html` → es el más complejo, sirve de referencia
2. `piduntdf-documentos.html` → comparte estilos con index
3. `piduntdf-integrantes.html` → estilos independientes

**Verify:** Desktop visualmente idéntico después de cada cambio (comparar screenshot baseline).

---

## Fase 6 — Verificación

### 6.1 Re-capturar screenshots
Mismos 9 screenshots de la Fase 3, post-cambios.

### 6.2 Verificar regresiones
- [ ] Screenshot desktop 1280×800 idéntico al baseline
- [ ] Screenshots mobile/tablet sin elementos cortados, solapados o invisibles
- [ ] Navegación funcional en todos los viewports
- [ ] `git diff` solo muestra cambios en media queries y reglas responsive

### 6.3 Engram session close
- [ ] `mem_session_summary` con hallazgos y decisiones

**Verify:** 9 screenshots clean, desktop sin cambios, mobile/tablet funcional.

---

## Herramientas Activadas

| Herramienta | Rol en este plan | Fase |
|-------------|-----------------|------|
| **Semble** | Buscar patrones CSS duplicados, cross-file impact | 2, 4 |
| **Engram** | Persistir decisiones, mapa de blast radius, patrones | 2, 4, 6 |
| **agent-browser** | Screenshots multi-viewport, diagnóstico visual | 3, 6 |
| **Git (bash)** | Branch, backups `.old/`, diff verification | 1, 5, 6 |
| **GitNexus** | No disponible para este repo (no indexado) | — |

---

## Criterios de Éxito

1. Las 3 páginas se ven correctas en viewport 390×844 (iPhone 14)
2. Las 3 páginas se ven correctas en viewport 768×1024 (iPad)
3. El layout desktop (1280×800) es **idéntico** al estado pre-intervención
4. No hay scroll horizontal en ningún viewport
5. Los textos no se cortan ni solapan
6. Las grillas colapsan correctamente a single-column en mobile
