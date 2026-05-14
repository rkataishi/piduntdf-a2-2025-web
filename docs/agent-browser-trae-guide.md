# agent-browser en Trae IDE — Guía de Uso para Selección DOM

> Workflow para inspeccionar una web en desarrollo, seleccionar elementos del DOM y marcarlos como contexto directo en el chat de Trae.

---

## 1. Arquitectura del flujo

```
┌─────────────────────────────────────────────────────────────┐
│  Trae IDE (chat)                                            │
│                                                             │
│  1. LLM ejecuta agent-browser commands via bash tool        │
│  2. Obtiene snapshot / annotated screenshot / eval JSON     │
│  3. Marca elementos con refs @eN + selectores estables      │
│  4. Devuelve contexto estructurado al usuario en el chat    │
│  5. Usuario confirma → LLM edita el código fuente           │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌───────────────────┐        ┌──────────────────────┐
│  agent-browser    │        │  Proyecto web        │
│  CLI (Rust)       │        │  (localhost:XXXX)    │
│  Chrome CDP       │        │  HTML/CSS/JS/React   │
└───────────────────┘        └──────────────────────┘
```

---

## 2. Instalación verificada

| Componente | Estado | Ubicación |
|---|---|---|
| CLI global | ✅ `0.27.0` | `npm install -g agent-browser` |
| Chrome for Testing | ✅ `148.0.7778.167` | `~/.agent-browser/browsers/` |
| Skill Trae (proyecto) | ✅ | `.trae/skills/agent-browser/SKILL.md` |
| Config proyecto | ✅ | `agent-browser.json` (`headed: false`) |

---

## 3. Tres modos de selección DOM

### Modo A: Snapshot + refs `@eN` (recomendado para interacción rápida)

El más simple. Ideal para que el LLM "vea" la página como un usuario.

```bash
# 1. Abrir la web en desarrollo
agent-browser open http://localhost:3000

# 2. Esperar carga completa
agent-browser wait --load networkidle

# 3. Obtener árbol de accesibilidad con refs
agent-browser snapshot -i

# 4. (Opcional) Screenshot anotado con etiquetas numeradas
agent-browser screenshot --annotate ./page.png
```

**Output del snapshot** (ejemplo):
```
- heading "Bienvenido" [ref=e1] [level=1]
- button "Ingresar" [ref=e2]
- textbox "Email" [ref=e3]
- textbox "Contraseña" [ref=e4]
- button "Crear cuenta" [ref=e5]
- link "Olvidé mi contraseña" [ref=e6]
```

**El LLM marca contexto así:**

| Elemento | Ref `@eN` | Texto | Rol | Selector estable sugerido |
|---|---|---|---|---|
| Título principal | `@e1` | "Bienvenido" | heading | `[data-testid="hero-title"]` |
| Botón login | `@e2` | "Ingresar" | button | `[data-testid="login-submit"]` |
| Campo email | `@e3` | "Email" | textbox | `[data-testid="email-input"]` |

**Para interactuar:**
```bash
agent-browser click @e2              # Click en "Ingresar"
agent-browser fill @e3 "user@mail"   # Llenar email
agent-browser get text @e1           # Leer título
```

**Cuándo usar:** Navegación exploratoria, QA visual, identificar elementos sin conocer el HTML.

---

### Modo B: `eval` + JS programático (para mapeo DOM → selector estable)

El más robusto. Genera un JSON con selectores estables que el LLM puede usar como referencia permanente.

```bash
agent-browser open http://localhost:3000
agent-browser wait --load networkidle
agent-browser eval '
(() => {
  function cssEscape(v) { return CSS.escape(String(v)); }
  function unique(sel) {
    try { return document.querySelectorAll(sel).length === 1; }
    catch { return false; }
  }
  function buildSelector(el) {
    if (!el || el.nodeType !== 1) return null;
    const testid = el.getAttribute("data-testid");
    if (testid) { const s = `[data-testid="${cssEscape(testid)}"]`; if (unique(s)) return s; }
    if (el.id) { const s = `#${cssEscape(el.id)}`; if (unique(s)) return s; }
    const aria = el.getAttribute("aria-label");
    if (aria) { const s = `${el.tagName.toLowerCase()}[aria-label="${cssEscape(aria)}"]`; if (unique(s)) return s; }
    for (const attr of ["data-section", "data-component", "data-slot"]) {
      const val = el.getAttribute(attr);
      if (val) { const s = `${el.tagName.toLowerCase()}[${attr}="${cssEscape(val)}"]`; if (unique(s)) return s; }
    }
    let current = el; const path = [];
    while (current && current.nodeType === 1 && current !== document.body) {
      let part = current.tagName.toLowerCase();
      const parent = current.parentElement;
      if (!parent) break;
      const siblings = [...parent.children].filter(x => x.tagName === current.tagName);
      if (siblings.length > 1) part += `:nth-of-type(${siblings.indexOf(current) + 1})`;
      path.unshift(part);
      if (unique(path.join(" > "))) return path.join(" > ");
      current = parent;
    }
    return path.join(" > ");
  }
  const nodes = [...document.querySelectorAll(
    "button, a, input, textarea, select, [role=\"button\"], [data-testid], [data-component], [data-section], h1, h2, h3, h4, h5, h6, img, section, article, main, header, footer, nav"
  )];
  return nodes.slice(0, 200).map(el => ({
    tag: el.tagName.toLowerCase(),
    text: (el.innerText || el.value || el.getAttribute("aria-label") || "").trim().slice(0, 120),
    selector: buildSelector(el),
    testid: el.getAttribute("data-testid"),
    id: el.id || null,
    role: el.getAttribute("role"),
    section: el.getAttribute("data-section"),
    component: el.getAttribute("data-component"),
    classes: el.className ? String(el.className).split(" ").filter(c => !c.startsWith("tw-") && !c.startsWith("css-")).slice(0, 5) : []
  }));
})()
' --json
```

**Output JSON** (ejemplo):
```json
[
  {
    "tag": "h1",
    "text": "Bienvenido a la plataforma",
    "selector": "[data-testid=\"hero-title\"]",
    "testid": "hero-title",
    "id": null,
    "role": null,
    "section": "hero",
    "component": null,
    "classes": ["text-4xl", "font-bold"]
  },
  {
    "tag": "button",
    "text": "Comenzar",
    "selector": "[data-testid=\"hero-cta\"]",
    "testid": "hero-cta",
    "id": null,
    "role": null,
    "section": "hero",
    "component": "cta-button",
    "classes": ["bg-blue-600", "px-6", "py-3"]
  }
]
```

**El LLM marca contexto así en el chat:**

````
## Mapa DOM — Hero Section

| # | Elemento | Selector estable | Texto visible | Sección |
|---|---|---|---|---|
| 1 | `h1` | `[data-testid="hero-title"]` | "Bienvenido a la plataforma" | hero |
| 2 | `button` | `[data-testid="hero-cta"]` | "Comenzar" | hero |
| 3 | `input` | `[data-testid="email-input"]` | "Email" | hero |

### Cambios propuestos
- **Elemento #1** (`[data-testid="hero-title"]`): Cambiar texto a "Tu nueva experiencia comienza aquí"
- **Elemento #2** (`[data-testid="hero-cta"]`): Cambiar color de fondo a `bg-indigo-600`
````

**Cuándo usar:** Edición de código fuente, mapeo permanente entre UI y HTML, cuando necesitas selectores que sobreviven cambios de DOM.

---

### Modo C: Locators semánticos (para intención de producto)

Describe qué buscar sin conocer la estructura.

```bash
# Buscar por rol accesible
agent-browser find role button click --name "Ingresar"
agent-browser find role textbox fill --name "Email" "user@mail.com"

# Buscar por texto visible
agent-browser find text "Comenzar" click

# Buscar por label de formulario
agent-browser find label "Email" fill "user@mail.com"

# Buscar por data-testid
agent-browser find testid "hero-cta" click
```

**Cuándo usar:** Cuando conocés la intención ("click en el botón de login") pero no la estructura exacta.

---

## 4. Workflow completo en Trae

### Paso 1: Abrir y explorar

```bash
agent-browser open http://localhost:3000 && agent-browser wait --load networkidle && agent-browser snapshot -i
```

### Paso 2: Identificar zona de interés

```bash
# Scopear a una sección específica para reducir ruido
agent-browser snapshot -i -s "#app-main"
# o
agent-browser snapshot -i -s "[data-section=\"pricing\"]"
```

### Paso 3: Generar mapa de selectores

```bash
agent-browser eval '<script-del-modo-B-arriba>' --json > /tmp/dom-map.json
```

### Paso 4: El LLM presenta contexto al usuario

El LLM devuelve una tabla como la del Modo B, con:
- Ref `@eN` del snapshot actual
- Selector estable del `eval`
- Texto visible
- Rol/función
- Cambio propuesto

### Paso 5: Confirmar y editar

El usuario confirma → el LLM edita el archivo fuente usando los selectores estables como referencia.

### Paso 6: Verificar

```bash
agent-browser reload && agent-browser snapshot -i -s "#app-main"
agent-browser screenshot --annotate ./after.png
```

---

## 5. Comandos esenciales para selección DOM

| Comando | Uso | Ejemplo |
|---|---|---|
| `snapshot -i` | Elementos interactivos con refs | `agent-browser snapshot -i` |
| `snapshot -i -s <sel>` | Scopear a zona | `agent-browser snapshot -i -s "#hero"` |
| `snapshot -i -c` | Compacto (sin vacíos) | `agent-browser snapshot -i -c` |
| `snapshot -i -d 3` | Profundidad limitada | `agent-browser snapshot -i -d 3` |
| `screenshot --annotate` | Imagen con etiquetas | `agent-browser screenshot --annotate ./out.png` |
| `eval '<js>'` | Ejecutar JS en la página | `agent-browser eval 'document.title'` |
| `get html <sel>` | innerHTML de un elemento | `agent-browser get html "#hero"` |
| `get attr <sel> <attr>` | Leer atributo | `agent-browser get attr "#btn" data-testid` |
| `get styles <sel>` | Computed styles | `agent-browser get styles "#btn"` |
| `get text <sel>` | Text content | `agent-browser get text "h1"` |
| `get count <sel>` | Cantidad de matches | `agent-browser get count "button"` |
| `get box <sel>` | Bounding box | `agent-browser get box "#btn"` |
| `find testid <id>` | Buscar por data-testid | `agent-browser find testid "login-btn" click` |
| `find role <role>` | Buscar por rol ARIA | `agent-browser find role button click --name "Save"` |
| `find text <text>` | Buscar por texto | `agent-browser find text "Submit" click` |
| `highlight <sel>` | Resaltar elemento | `agent-browser highlight "#btn"` |

---

## 6. Convención de atributos estables (para tu HTML)

Para que el LLM pueda seleccionar elementos de forma robusta, instrumentá tu HTML así:

```html
<header id="site-header" data-section="header">
  <nav data-component="main-nav" aria-label="Navegación principal">
    <button data-testid="nav-login" aria-label="Ingresar">Ingresar</button>
  </nav>
</header>

<main id="app-main">
  <section data-section="hero" data-testid="hero">
    <h1 data-testid="hero-title">Tu título</h1>
    <p data-testid="hero-subtitle">Tu subtítulo</p>
    <button data-testid="hero-primary-cta">Comenzar</button>
  </section>

  <section data-section="pricing" data-testid="pricing-section">
    <div data-component="pricing-card" data-plan="pro">
      <h2 data-testid="plan-pro-title">Pro</h2>
      <button data-testid="plan-pro-cta">Elegir Pro</button>
    </div>
  </section>
</main>
```

### Jerarquía de selectores (prioridad)

| Prioridad | Atributo | Ejemplo | Cuándo |
|---|---|---|---|
| 1 | `data-testid` | `[data-testid="hero-cta"]` | Elementos accionables/editables |
| 2 | `id` | `#app-main` | Landmarks estructurales únicos |
| 3 | `aria-label` | `button[aria-label="Ingresar"]` | Formularios, botones icono |
| 4 | `data-section` | `section[data-section="hero"]` | Zonas grandes |
| 5 | `data-component` | `div[data-component="pricing-card"]` | Componentes reutilizables |
| 6 | `data-slot` | `div[data-slot="card-body"]` | Slots internos de componentes |
| 7 | CSS path | `main > section > button:nth-of-type(2)` | Fallback |
| 8 | `text=` | `text=Comenzar` | Último recurso |

**Evitar:** Clases de Tailwind extensas (`mt-4 text-sm font-bold bg-blue-600...`) como selector principal.

---

## 7. Prompt para el LLM en Trae

Copiá esto en el chat de Trae como instrucción inicial:

```
Quiero que uses agent-browser para inspeccionar mi webapp en desarrollo y marcarme los elementos del DOM como contexto directo.

Reglas:
1. Abrí la app en http://localhost:3000 (o el puerto que corresponda).
2. Ejecutá `agent-browser wait --load networkidle`.
3. Si te digo una zona (ej: "el hero", "el pricing"), scopeá con `snapshot -i -s "<selector>"`.
4. Si no, ejecutá el script de eval programático para generar un mapa DOM en JSON.
5. Para cada elemento relevante, devolvé:
   - Ref @eN del snapshot actual
   - Selector CSS estable (priorizá data-testid, id, aria-label)
   - Texto visible
   - Rol/función
   - Sección o componente
6. Presentá el contexto en formato tabla markdown.
7. Si te pido cambiar algo, usá el selector estable para identificar el archivo y nodo en el código fuente.
8. Después de cada cambio, recargá y verificá con `snapshot -i` o `screenshot --annotate`.
9. No uses clases utilitarias (Tailwind) como selector principal.
10. Si no hay data-testid, sugerí cuál agregar en el HTML.
```

---

## 8. Casos de uso específicos

### 8.1 "Marcame todos los botones de esta página"

```bash
agent-browser open http://localhost:3000 && agent-browser wait --load networkidle
agent-browser eval '
[...document.querySelectorAll("button, [role=\"button\"], a.btn, input[type=\"submit\"]")].map(el => ({
  tag: el.tagName.toLowerCase(),
  text: (el.innerText || el.value || el.getAttribute("aria-label") || "").trim().slice(0, 80),
  selector: el.getAttribute("data-testid") ? `[data-testid="${el.getAttribute("data-testid")}"]` :
            el.id ? `#${el.id}` :
            null,
  needs_testid: !el.getAttribute("data-testid") && !el.id
}))
' --json
```

### 8.2 "Qué hay en el header?"

```bash
agent-browser open http://localhost:3000 && agent-browser wait --load networkidle
agent-browser snapshot -i -s "header, [data-section=\"header\"], nav, #site-header"
```

### 8.3 "Marcame el formulario de login completo"

```bash
agent-browser open http://localhost:3000/login
agent-browser wait --load networkidle
agent-browser eval '
(() => {
  const form = document.querySelector("form") || document.querySelector("[data-section=\"login\"]");
  if (!form) return { error: "No se encontró formulario" };
  const fields = [...form.querySelectorAll("input, textarea, select, button")];
  return {
    action: form.action,
    method: form.method,
    fields: fields.map(el => ({
      tag: el.tagName.toLowerCase(),
      type: el.type || null,
      name: el.name || null,
      testid: el.getAttribute("data-testid") || null,
      placeholder: el.placeholder || null,
      label: form.querySelector(`label[for="${el.id}"]`)?.innerText || el.getAttribute("aria-label") || null,
      selector: el.getAttribute("data-testid") ? `[data-testid="${el.getAttribute("data-testid")}"]` :
                el.id ? `#${el.id}` :
                el.name ? `${el.tagName.toLowerCase()}[name="${el.name}"]` : null
    }))
  };
})()
' --json
```

### 8.4 "Compará antes y después de un cambio"

```bash
# Antes
agent-browser open http://localhost:3000 && agent-browser wait --load networkidle
agent-browser snapshot -i > /tmp/before.txt
agent-browser screenshot --annotate ./before.png

# ... el LLM edita el código ...

# Después
agent-browser reload && agent-browser wait --load networkidle
agent-browser snapshot -i > /tmp/after.txt
agent-browser screenshot --annotate ./after.png

# Diff
agent-browser diff snapshot --baseline /tmp/before.txt
```

### 8.5 App React: inspeccionar componentes

```bash
agent-browser open --enable react-devtools http://localhost:3000
agent-browser wait --load networkidle
agent-browser react tree
agent-browser react inspect <fiberId>
```

---

## 9. Formato de salida esperado del LLM

Cuando el LLM marca elementos como contexto, debe usar este formato:

```
## Contexto DOM — [Nombre de la sección]

| # | Ref | Elemento | Selector estable | Texto | Sección | Acción propuesta |
|---|---|---|---|---|---|---|
| 1 | @e3 | `h1` | `[data-testid="hero-title"]` | "Bienvenido" | hero | Cambiar texto |
| 2 | @e7 | `button` | `[data-testid="hero-cta"]` | "Comenzar" | hero | Cambiar color |

### Detalle por elemento

**Elemento #1 — `[data-testid="hero-title"]`**
- Archivo: `src/components/Hero.tsx` línea 12
- HTML actual: `<h1 data-testid="hero-title" className="text-4xl">Bienvenido</h1>`
- Cambio propuesto: Texto → "Tu nueva experiencia comienza aquí"

**Elemento #2 — `[data-testid="hero-cta"]`**
- Archivo: `src/components/Hero.tsx` línea 18
- HTML actual: `<button data-testid="hero-cta" className="bg-blue-600">Comenzar</button>`
- Cambio propuesto: `bg-blue-600` → `bg-indigo-600`
```

---

## 10. Troubleshooting

| Problema | Solución |
|---|---|
| `agent-browser` no encuentra Chrome | `agent-browser install` |
| Puerto ya en uso | `agent-browser close --all` |
| Elemento no encontrado con ref | El DOM cambió; ejecutá `snapshot` de nuevo |
| Snapshot muy largo | Usá `-c` (compacto), `-d 3` (profundidad), o `-s` (scope) |
| Página no carga | `agent-browser wait --load networkidle` o `--timeout 60000` |
| Headless no muestra browser | Usá `--headed` para debug visual |
| React devtools no funciona | Requiré `--enable react-devtools` en el `open` |

---

## 11. Referencia rápida de comandos

```bash
# Abrir
agent-browser open http://localhost:3000

# Esperar
agent-browser wait --load networkidle

# Inspeccionar
agent-browser snapshot -i                    # Todo
agent-browser snapshot -i -s "#hero"         # Solo hero
agent-browser snapshot -i -c -d 3            # Compacto, 3 niveles
agent-browser screenshot --annotate ./out.png # Imagen etiquetada

# Eval programático
agent-browser eval '<js>' --json

# Info de elemento
agent-browser get text "#btn"
agent-browser get attr "#btn" data-testid
agent-browser get styles "#btn"
agent-browser get html "#hero"

# Interactuar
agent-browser click @e2
agent-browser fill @e3 "texto"
agent-browser hover @e4

# Verificar
agent-browser reload
agent-browser snapshot -i

# Cerrar
agent-browser close
```

---

## 12. Integración con impeccable

Si también tenés el skill `impeccable` instalado, podés combinar ambos:

1. Usá `agent-browser` para inspeccionar y seleccionar elementos
2. Usá `impeccable` para mejorar el diseño de los elementos identificados
3. El selector estable (`data-testid`) sirve de puente entre ambos workflows

```
1. agent-browser → identificá elementos
2. impeccable → mejorá diseño/UX
3. agent-browser → verificá cambios
```
