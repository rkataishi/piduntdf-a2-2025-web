Sí: para que un LLM te ayude a editar tu webapp con `agent-browser`, conviene **no pedirle que razone sobre HTML crudo solamente**, sino darle una capa de referencia estable del DOM: `@eN` refs del snapshot para interactuar y, cuando necesites precisión de implementación, **CSS selectors semánticos y estables** (`data-testid`, `data-role`, `id` de zonas clave). `agent-browser` recomienda justamente trabajar con snapshots y refs `@eN` porque son determinísticos y más confiables para agentes que reconsultar el DOM libremente en cada paso. [github](https://github.com/vercel-labs/agent-skills)

## Qué es útil de agent-browser

agent-browser es un CLI de automatización de navegador para agentes que trabaja sobre Chrome/Chromium vía CDP y expone snapshots del árbol de accesibilidad con referencias como `@e1`, `@e2`, etc., pensadas para que un LLM pueda ubicar e interactuar con elementos de forma compacta y estable. [github](https://github.com/vercel-labs)
El flujo recomendado por el propio proyecto es: abrir página, sacar snapshot, interactuar usando refs, y volver a sacar snapshot después de cada cambio relevante del DOM o navegación. [agent-browser](https://agent-browser.dev)

## Cómo piensa el LLM

Para un LLM, hay tres niveles de selección que conviene combinar en este orden: **refs del snapshot**, **locators semánticos** y **CSS selectors/XPath**. `agent-browser` prioriza refs `@eN`; también soporta `find role`, `find label`, `find placeholder`, `find testid`; y además acepta selectores CSS tradicionales como `#id`, `.class`, `div > button` o `[data-testid='submit']`. [github](https://github.com/vercel-labs)

| Nivel | Cuándo usarlo | Ejemplo |
|---|---|---|
| Refs `@eN` | Para operar rápido sobre la UI actual visible | `agent-browser click @e2`  [github](https://github.com/vercel-labs/agent-skills) |
| Semantic locators | Cuando querés describir intención de producto, no estructura | `agent-browser find role button click --name "Save"`  [github](https://github.com/vercel-labs) |
| CSS selector | Cuando necesitás precisión DOM/HTML para una zona o componente específico | `agent-browser click "[data-testid='hero-cta']"`  [github](https://github.com/vercel-labs) |

## Lo que vos necesitás

Si querés decirle al LLM “cambiá este bloque”, “mové este botón”, “editá este formulario” o “ajustá este componente”, **no alcanza con una clase visual tipo `.mt-4.text-sm`** porque eso suele ser frágil y ambiguo. Lo mejor es exponer en tu HTML selectores estables como `data-testid`, `data-component`, `data-section`, `aria-label`, y ids para landmarks estructurales. `agent-browser` trae soporte explícito para buscar por `data-testid`, además de rol, label y placeholder. [github](https://github.com/vercel-labs/agent-skills)

## Selector DOM recomendado

Te conviene instrumentar tu app con una convención así:

```html
<header id="site-header" data-section="header">
  <nav data-component="main-nav">
    <button data-testid="nav-login">Ingresar</button>
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

Con eso, el LLM puede referirse a elementos de forma robusta con selectores como `[data-testid="hero-title"]` o `[data-component="pricing-card"][data-plan="pro"]`, y `agent-browser` además puede encontrarlos semánticamente con `find testid`. [github](https://github.com/vercel-labs)

## Prompt que sí sirve

Una buena instrucción al LLM sería decirle que **primero inspeccione**, luego proponga, y recién después edite. El patrón más alineado con `agent-browser` sería algo así: “abrí la webapp, sacá `snapshot -i`, identificá los elementos clave del hero y del pricing, devolveme los refs visibles y sus selectores DOM estables, y recién después aplicá cambios”. Ese uso encaja con el workflow oficial de snapshot → refs → interacción → resnapshot. [github](https://github.com/vercel-labs/agent-browser/blob/main/skills/agent-browser/SKILL.md)

Podés pasarle un prompt base como este:

```txt
Quiero que edites mi webapp usando agent-browser.

Reglas:
1. Abrí la app.
2. Ejecutá un snapshot interactivo.
3. Identificá los elementos relevantes de la pantalla actual.
4. Para cada elemento importante, devolvé:
   - ref de agent-browser (@eN)
   - texto visible
   - rol accesible si existe
   - selector CSS estable sugerido
5. Priorizá data-testid, data-section, data-component, id y aria-label.
6. No uses clases utilitarias frágiles como selector principal salvo que no exista otra opción.
7. Antes de modificar algo, describí exactamente qué nodo vas a tocar.
8. Después de cada cambio, volvé a sacar snapshot y verificá el resultado.
```

Ese tipo de instrucción aprovecha que `agent-browser` puede sacar snapshots, obtener texto, HTML, atributos y estilos, además de usar refs y selectores CSS. [github](https://github.com/vercel-labs/agent-skills)

## Comandos concretos

Para inspección de una pantalla de tu app, esta secuencia es buena:

```bash
agent-browser open http://localhost:3000
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser screenshot --annotate
```

`snapshot -i` devuelve solo elementos interactivos con refs y `screenshot --annotate` agrega etiquetas numeradas que corresponden a los mismos refs `@eN`, lo que ayuda mucho si el LLM también necesita entender layout visual. [github](https://github.com/vercel-labs)
Si querés enfocarte en una zona, `agent-browser snapshot -s "#app-main"` o sobre un selector más específico reduce ruido y contexto. [github](https://github.com/vercel-labs/agent-browser/blob/main/skills/agent-browser/SKILL.md)

## Cómo pedir el selector

Si tu objetivo es “necesito un selector DOM sobre mi HTML”, entonces la instrucción correcta al LLM no es solo “decime cuál es el selector”, sino:

- Identificá el elemento visible.
- Leé atributos.
- Proponé el selector más estable disponible.
- Indicá un fallback.

Ejemplo de formato de salida que le podés exigir:

```txt
Elemento: botón principal del hero
Ref: @e7
Texto: "Comenzar"
Selector estable: [data-testid="hero-primary-cta"]
Fallback 1: section[data-section="hero"] button
Fallback 2: text=Comenzar
```

Eso está alineado con las capacidades del CLI de obtener attrs, HTML y trabajar con CSS/text/semantic locators. [github](https://github.com/vercel-labs/agent-skills)

## Estrategia robusta

La mejor práctica para edición asistida por LLM sería esta:

- En tu código fuente, agregá atributos estables: `data-testid`, `data-section`, `data-component`, `data-slot`.
- En ejecución, usá `agent-browser snapshot -i` para generar refs temporales `@eN`.
- Pedile al LLM que siempre relacione cada `@eN` con un selector estable del HTML.
- Después, si además edita código, usá ese selector estable como puente entre navegador y fuente. [agent-browser](https://agent-browser.dev)

## Qué evitar

No conviene apoyarte principalmente en:

- Clases de Tailwind extensas o generadas, porque cambian fácil y no expresan intención.  
- XPath salvo casos límite, porque es más verboso y frágil que `data-testid` o locators semánticos, aunque `agent-browser` lo soporte. [github](https://github.com/vercel-labs/agent-skills)
- Refs `@eN` como persistencia entre pantallas, porque sirven para el snapshot actual y el propio workflow recomienda volver a tomar snapshot después de cambios del DOM o navegación. [agent-browser](https://agent-browser.dev)

## Mi recomendación práctica

Si querés que el LLM te ayude en serio a editar una webapp, armá esta convención mínima en tu HTML:

- `data-section` para zonas grandes, por ejemplo `hero`, `sidebar`, `pricing`, `checkout`.
- `data-component` para componentes reutilizables, por ejemplo `pricing-card`, `modal`, `navbar`.
- `data-testid` para nodos editables o accionables concretos, por ejemplo `hero-title`, `hero-primary-cta`, `checkout-submit`.
- `aria-label` y labels reales en formularios, para que también funcionen los locators semánticos. [github](https://github.com/vercel-labs)

Con eso, el LLM puede trabajar en dos planos al mismo tiempo:
- “qué ve” en navegador vía `@eN`;  
- “qué toca” en tu HTML vía selector estable. [agent-browser](https://agent-browser.dev)


---

PERO **hay una forma programática pura**. Los snapshots no son obligatorios; son la capa “AI-friendly” recomendada para agentes, pero `agent-browser` también soporta **selectores CSS**, **semantic locators**, **`eval` para ejecutar JS**, y comandos de inspección como `get html`, `get attr`, `get styles`, `get count` y `get box`. [github](https://github.com/vercel-labs)

## Respuesta corta

Si tu objetivo es “quiero obtener/selectores DOM de manera determinística para que un LLM edite mi webapp”, podés hacerlo sin snapshots usando una combinación de:

- `agent-browser eval` para inspeccionar el DOM y construir selectores. [github](https://github.com/vercel-labs/agent-skills)
- `agent-browser click/fill/... "<css selector>"` para operar directo sobre CSS selectors. [github](https://github.com/vercel-labs/agent-skills)
- `agent-browser find testid`, `find role`, `find label` para locators semánticos programáticos. [github](https://github.com/vercel-labs)

## Por qué aparecen snapshots

Los snapshots existen porque `agent-browser` está optimizado para agentes, y sus refs `@eN` son la forma recomendada y más determinística para interacción inmediata sobre la UI actual. La docs igual aclara que los **traditional selectors are also supported**, incluyendo CSS, texto y XPath. [agent-browser](https://agent-browser.dev)

## La vía programática pura

La vía más “ingenieril” para tu caso sería:

1. Abrís la app.
2. Ejecutás JS sobre `document`.
3. Detectás elementos candidatos.
4. Generás un selector estable para cada nodo.
5. Le devolvés eso al LLM en JSON.
6. El LLM usa después esos selectores para inspeccionar o interactuar. [github](https://github.com/vercel-labs)

Esto encaja perfecto con `agent-browser eval`, que permite correr JavaScript en la página, y con `--json`/batch para integrarlo a scripts. [github](https://github.com/vercel-labs/agent-skills)

## Qué usar en vez de snapshot

Podés apoyarte en estos comandos:

- `agent-browser eval "<js>"` para recorrer el DOM. [github](https://github.com/vercel-labs)
- `agent-browser get html "<selector>"` para leer `innerHTML`. [github](https://github.com/vercel-labs)
- `agent-browser get attr "<selector>" data-testid` para leer atributos estables. [github](https://github.com/vercel-labs)
- `agent-browser get styles "<selector>"` para identificar visualmente un nodo. [github](https://github.com/vercel-labs)
- `agent-browser get count "<selector>"` para validar unicidad. [github](https://github.com/vercel-labs)
- `agent-browser click "<selector>"` / `fill "<selector>"` para actuar sobre ese nodo. [github](https://github.com/vercel-labs/agent-skills)

## Estrategia que te recomiendo

Lo ideal es que el LLM **no invente selectores**, sino que vos le des una función utilitaria que construya selectores estables a partir del DOM real. Eso es más robusto que depender de texto o de clases utilitarias. `agent-browser` soporta muy bien ese enfoque porque acepta CSS selectors y también `find testid` cuando instrumentás el HTML con `data-testid`. [github](https://github.com/vercel-labs/agent-skills)

## Criterio de selector estable

Orden sugerido para construir un selector único:

1. `data-testid`
2. `id`
3. `aria-label`
4. `name`
5. `data-section` / `data-component` / `data-slot`
6. combinación de tag + atributos
7. texto visible como fallback
8. XPath solo si no queda otra. [github](https://github.com/vercel-labs/agent-skills)

## Ejemplo práctico

Podés hacer algo así con `eval`:

```bash
agent-browser open http://localhost:3000
agent-browser wait --load networkidle
agent-browser eval '
(() => {
  function cssEscape(v) {
    return CSS.escape(String(v));
  }

  function unique(sel) {
    try { return document.querySelectorAll(sel).length === 1; }
    catch { return false; }
  }

  function buildSelector(el) {
    if (!el || el.nodeType !== 1) return null;

    const testid = el.getAttribute("data-testid");
    if (testid) {
      const s = `[data-testid="${cssEscape(testid)}"]`;
      if (unique(s)) return s;
    }

    if (el.id) {
      const s = `#${cssEscape(el.id)}`;
      if (unique(s)) return s;
    }

    const aria = el.getAttribute("aria-label");
    if (aria) {
      const s = `${el.tagName.toLowerCase()}[aria-label="${cssEscape(aria)}"]`;
      if (unique(s)) return s;
    }

    const name = el.getAttribute("name");
    if (name) {
      const s = `${el.tagName.toLowerCase()}[name="${cssEscape(name)}"]`;
      if (unique(s)) return s;
    }

    for (const attr of ["data-section", "data-component", "data-slot"]) {
      const val = el.getAttribute(attr);
      if (val) {
        const s = `${el.tagName.toLowerCase()}[${attr}="${cssEscape(val)}"]`;
        if (unique(s)) return s;
      }
    }

    let current = el;
    const path = [];
    while (current && current.nodeType === 1 && current !== document.body) {
      let part = current.tagName.toLowerCase();
      const parent = current.parentElement;
      if (!parent) break;
      const siblings = [...parent.children].filter(
        x => x.tagName === current.tagName
      );
      if (siblings.length > 1) {
        part += `:nth-of-type(${siblings.indexOf(current) + 1})`;
      }
      path.unshift(part);
      const s = path.join(" > ");
      if (unique(s)) return s;
      current = parent;
    }

    return path.join(" > ");
  }

  const nodes = [...document.querySelectorAll(
    'button, a, input, textarea, select, [role="button"], [data-testid], [data-component], [data-section]'
  )];

  return nodes.slice(0, 200).map(el => ({
    tag: el.tagName.toLowerCase(),
    text: (el.innerText || el.value || el.getAttribute("aria-label") || "").trim().slice(0, 120),
    selector: buildSelector(el),
    testid: el.getAttribute("data-testid"),
    id: el.id || null,
    role: el.getAttribute("role"),
    section: el.getAttribute("data-section"),
    component: el.getAttribute("data-component")
  }));
})()
'
```

Eso te devuelve una lista programática de nodos con un **selector sugerido** por cada uno, sin usar snapshots. `agent-browser` permite exactamente este patrón porque expone `eval` y acepta luego esos selectores en comandos de acción. [github](https://github.com/vercel-labs/agent-skills)

## Mejor todavía en React

Si tu webapp es React, `agent-browser` tiene introspección nativa del árbol de React con `react tree` y `react inspect`, siempre que abras con `--enable react-devtools`. Eso te puede servir más que el DOM si querés mapear “qué componente cambiar” en vez de solo “qué nodo tocar”. [github](https://github.com/vercel-labs/agent-skills)

Ejemplo:

```bash
agent-browser open --enable react-devtools http://localhost:3000
agent-browser react tree
agent-browser react inspect "<selector o componente>"
```

La docs indica que `react inspect` expone props, hooks, state y source, lo que es especialmente útil si querés conectar una acción del LLM con el componente fuente real. [github](https://github.com/vercel-labs/agent-skills)

## Cuándo usar snapshots y cuándo no

Usá **snapshots** si querés que el agente navegue la UI como un usuario y resuelva “qué botón es este” rápidamente. [github](https://github.com/vercel-labs/agent-skills)
Usá **`eval` + CSS selectors + data-testid** si querés una capa programática pura y estable para inspección, mapeo DOM→selector y edición reproducible. [github](https://github.com/vercel-labs)

## Mi respuesta concreta

Sí, para tu caso **yo iría por una arquitectura programática pura**:

- instrumentar la app con `data-testid` y `data-component`;
- usar `agent-browser eval` para extraer un mapa DOM en JSON;
- pasarle ese JSON al LLM;
- hacer que el LLM siempre responda en términos de `selector estable + cambio propuesto`;
- opcionalmente usar `react tree/react inspect` si la app es React. [github](https://github.com/vercel-labs)

## Patrón recomendado al LLM

Podés instruirlo así:

```txt
No uses refs de snapshot salvo para debugging visual.
Trabajá de forma programática:
1. Ejecutá JS sobre el DOM para listar elementos relevantes.
2. Para cada elemento, generá el selector CSS estable más corto y único posible.
3. Priorizá data-testid, id, aria-label, name, data-section, data-component.
4. Validá unicidad con document.querySelectorAll(selector).length === 1.
5. Devolvé un JSON con {selector, tag, text, role, attrs}.
6. Basá toda sugerencia de edición en esos selectores.
```

Eso encaja mucho más con lo que querés: una capa de direccionamiento DOM reproducible, sin depender del modo “snapshot-centric” del agente. [github](https://github.com/vercel-labs)

Si querés, te puedo armar ahora mismo una de estas dos cosas:

- un **script `inspect-dom.js`** listo para correr con `agent-browser eval` y que devuelva `selector -> texto -> atributos -> xpath fallback`; o
- un **prompt/sistema para tu LLM** para que use ese mapa DOM y te proponga cambios concretos sobre una webapp React/Next en Mac M3 Max.