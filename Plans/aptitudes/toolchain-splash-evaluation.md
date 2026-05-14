# Toolchain para Evaluación de Splash & Blast Radius — PIDUNTDF Web

> Documenta cómo usar Engram, Semble, agent-browser y GitNexus para evaluar el impacto de reformas de código antes de intervenir.

---

## 1. Flujo General de Evaluación de Impacto

```
[Plan] → [Semble: mapear código] → [Engram: persistir patrones]
       → [agent-browser: diagnóstico visual] → [Blast Radius Report]
       → [Intervención quirúrgica] → [agent-browser: verificación]
```

---

## 2. Semble — Mapeo de Código y Patrones Cross-File

### Qué hace
Búsqueda semántica + léxica sobre el código local. Ideal para encontrar:
- Reglas CSS duplicadas entre archivos
- Patrones de layout repetidos
- Selectores que aparecen en múltiples archivos

### Comandos clave para este proyecto

```bash
# Buscar patrones CSS grid/flex repetidos entre HTMLs
semble_search query="CSS grid layout template columns flex navbar footer shell container" repo="./" mode="hybrid"

# Buscar media queries existentes
semble_search query="media max-width responsive breakpoint mobile" repo="./" mode="hybrid"

# Encontrar código relacionado a un patrón específico
semble_find_related file_path="index.html" line=355 repo="./"
```

### Output esperado
Lista de chunks con `file_path`, `line`, `score` y código. Permite mapear exactamente qué reglas CSS se repiten y en qué archivos.

---

## 3. Engram — Memoria Persistente del Proyecto

### Qué hace
Almacena decisiones, patrones, bugs y descubrimientos entre sesiones. Crítico para no repetir errores ni perder contexto.

### Comandos clave

```bash
# Guardar un patrón detectado
mem_save title="CSS shared nav-bar styles across HTML files" type="pattern" content="..."

# Guardar decisión arquitectónica
mem_save title="Blast radius: section-chapter grid affects 2 files" type="architecture" topic_key="css-blast-radius" content="..."

# Buscar decisiones previas sobre CSS/responsive
mem_search query="CSS responsive layout mobile grid" project="piduntdf-a2-2025-web"

# Al finalizar sesión
mem_session_summary content="..."
```

### Schema de contenido recomendado
```
**What**: [qué se encontró/hizo]
**Why**: [por qué es relevante]
**Where**: [archivos afectados]
**Learned**: [gotchas, edge cases]
```

---

## 4. agent-browser — Diagnóstico Visual Multi-Viewport

### Qué hace
Automatización de navegador para screenshots, snapshots e inspección del DOM en diferentes viewports.

### Setup (ya existe en el proyecto)

El proyecto ya tiene:
- `agent-browser.json` con `{"headed": false}` (headless para CI)
- `start-agent-browser-session.sh` que levanta `python3 -m http.server` en puerto 8000

### Comandos de diagnóstico visual

```bash
# 1. Levantar servidor y sesión
./start-agent-browser-session.sh index.html

# 2. Screenshot desktop (baseline)
agent-browser --session-name piduntdf-web set viewport 1280 800
agent-browser --session-name piduntdf-web screenshot --full --screenshot-dir .temp/ desktop-index.png

# 3. Screenshot tablet
agent-browser --session-name piduntdf-web set viewport 768 1024
agent-browser --session-name piduntdf-web screenshot --full --screenshot-dir .temp/ tablet-index.png

# 4. Screenshot mobile
agent-browser --session-name piduntdf-web set device "iPhone 14"
agent-browser --session-name piduntdf-web screenshot --full --screenshot-dir .temp/ mobile-index.png

# 5. Snapshot interactivo para inspección programática
agent-browser --session-name piduntdf-web snapshot -i --json

# 6. Evaluar CSS computado de elementos problemáticos
agent-browser --session-name piduntdf-web eval '
  JSON.stringify([...document.querySelectorAll(".section-chapter, .metrics-row, .cards-grid")].map(el => ({
    selector: el.className,
    computedWidth: getComputedStyle(el).width,
    gridCols: getComputedStyle(el).gridTemplateColumns,
    overflow: el.scrollWidth > el.clientWidth ? "OVERFLOW" : "ok"
  })))
'
```

### Estrategia de screenshots

| Propósito | Viewport | Comando |
|-----------|----------|---------|
| Baseline desktop | 1280×800 | `set viewport 1280 800` |
| Tablet portrait | 768×1024 | `set viewport 768 1024` |
| Mobile (iPhone) | 390×844 | `set device "iPhone 14"` |
| Mobile pequeño | 375×812 | `set device "iPhone 13"` |

---

## 5. GitNexus — Análisis Estructural (No Disponible)

### Estado actual
El repo `piduntdf-a2-2025-web` **no está indexado** en GitNexus. Solo está indexado `start-session`.

### Si se indexara en el futuro
```bash
# Indexar el repo
gitnexus analyze ./ --name piduntdf-a2-2025-web

# Buscar procesos/ejecución
gitnexus_query query="page layout rendering mobile responsive"

# Análisis de impacto de cambios
gitnexus_impact target=".shell" direction="downstream"

# Detectar cambios antes de commit
gitnexus_detect_changes scope="unstaged"
```

### Alternativa sin GitNexus
Usar `semble_search` + `grep` para el mismo propósito de mapeo de impacto.

---

## 6. Blast Radius Report — Template

Para cada regla CSS que se planea modificar, generar:

```markdown
### Regla: `.section-chapter { grid-template-columns: 280px 1fr }`

| Campo | Valor |
|-------|-------|
| **Archivos afectados** | index.html:159, piduntdf-documentos.html:128 |
| **Elementos HTML impactados** | 3 sections con sidebar en index, 1 en documentos |
| **Breakpoint actual** | 900px (cambia a 1 col) |
| **Cambio propuesto** | Agregar breakpoint 600px para padding lateral |
| **Riesgo** | BAJO - solo se agrega media query, no se altera regla base |
| **Verificación** | Screenshot desktop debe ser idéntico, mobile debe mostrar 1 columna |
```

---

## 7. Orden de Ejecución Recomendado

1. **Semble** → mapear todas las reglas CSS y su duplicación cross-file
2. **Engram** → guardar el mapa de blast radius
3. **agent-browser** → screenshots baseline en 3 viewports × 3 páginas
4. **Análisis** → identificar fallas visuales, priorizar por impacto
5. **Engram** → registrar hallazgos del diagnóstico
6. **Intervención** → editar archivos uno por uno con backup `.old/`
7. **agent-browser** → re-screenshots para verificar
8. **Engram** → `mem_session_summary` con resultados
