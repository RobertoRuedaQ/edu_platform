# edu_platform — Orientaciones de UX/UI (disciplina de diseño FE)

> **Qué es este documento.** La **fuente única de verdad de la disciplina de front-end** de
> `edu_platform`: principios de diseño, arquitectura de tokens, modelo de marca por institución,
> y las reglas durables que gobiernan cómo se ve y se usa la app. Es hermano de `LEAN.md`
> (arquitectura/estado) e `HISTORIA.md` (narrativa). Cuando haya que decidir algo de FE —una vista,
> un color, una tipografía, un componente compartido— **este archivo es la norma**; se lee primero
> y se actualiza al cerrar cada iteración de UI.
>
> **Contrato con los otros archivos:** `LEAN.md` dice *qué existe y qué invariantes de arquitectura
> aplican*; este dice *cómo se presenta y se usa*. Los guardrails de FE que ya vivían en `LEAN.md §11`
> (Propshaft sin Sass, importmap sin build, tokens-only, AA) siguen siendo válidos y aquí se
> desarrollan, no se contradicen. Ante conflicto entre un detalle visual escrito aquí y una invariante
> de arquitectura de `LEAN.md`, **gana la invariante de arquitectura**.
>
> **El repositorio es la fuente de verdad del código.** Ante discrepancia entre esto y el disco, gana
> el disco; se corrige aquí en la siguiente versión.

| Campo | Valor |
|---|---|
| **Versión** | `v0.1.0` (borrador inicial — gradúa a `v1.0.0` cuando cierren las decisiones abiertas de §8) |
| **Fecha** | 2026-07-16 |
| **Estado** | Disciplina de diseño establecida; tokens de marca/suavidad diseñados. Falta ratificar mecanismo de fuentes subidas, validación de contraste y dónde se edita la config de marca. Ningún componente nuevo construido aún por esta iteración. |

**Versionado (igual que los demás docs):** MAJOR = cambia un principio de diseño asentado o la
arquitectura de tokens · MINOR = se cierra una decisión abierta o se añade una orientación durable ·
PATCH = correcciones/redacción/reconciliación con el repo. Historia no se borra: lo revertido se marca
*supersedido*.

---

## 1. Los seis principios (el norte)

Los seis principios del encargo no son independientes; se agrupan en cuatro ejes de diseño:

1. **Una acción obvia por pantalla** (principios 1 + 2). "Que lo use un niño de primaria" y "salvarle
   el tiempo a docentes y padres" convergen en la misma regla: cada vista tiene **un verbo dominante y
   uno solo**. Reduce carga cognitiva y devuelve tiempo. Es coherente con la regla de ≤3 clics, las
   "vistas aburridas y legibles" y el 403 amable que ya están en `LEAN.md §6`.
2. **Aprovechar Rails vanilla** (principio 4). Todo lo visual sale del framework: Propshaft + importmap
   sin build, CSS con `@layer`, Stimulus para comportamiento, SVG server-rendered para gráficos. Cero
   Node, cero librería de charting, cero gema de componentes. No se traiciona el stack bloqueado.
3. **La suavidad vive en los tokens** (principios 5 + 6). "Diseño suave sin sobrecarga" y "colores
   institucionales gestionables" son ambos propiedades de `tokens.css`, no decisiones que se repiten
   por vista. Si la suavidad y la marca viven en tokens, **ninguna vista individual puede
   sobrecargarse ni salirse de la marca sin salirse del sistema** —y eso se nota en revisión.
4. **Representación visual sobre tabular** (principio 3, parte de UI). Cuando un dominio tiene
   estructura espacial o relacional natural, se representa **visualmente antes que tabularmente**. El
   resto del principio 3 (qué dato se calcula y se persiste detrás de esa representación) es del
   **dominio de BI** y no se decide aquí —ver §9.

---

## 2. Orientaciones operativas (derivadas de los principios)

Reglas concretas y verificables en revisión de vista:

- **Nunca ícono solo — siempre ícono + etiqueta en texto.** Como `icon-font` está bloqueado, los
  íconos son **SVG inline** desde un sprite servido por Propshaft, vía un partial `shared/_icon` que
  recibe el símbolo. Boring y greppable.
- **Un verbo por pantalla, en lenguaje llano.** "Registrar asistencia", no "Gestión de novedades". La
  app habla el vocabulario del *usuario* (docente, acudiente, registrador), no el del dominio. El
  acudiente y el registrador no comparten jerga.
- **Perdonar el error.** Confirmación solo para lo destructivo; donde se pueda, **deshacer** en vez de
  "¿está seguro?". Un padre con prisa en el celular no lee diálogos.
- **Defaults inteligentes = tiempo devuelto.** Término activo preseleccionado, institución activa
  recordada, acciones masivas donde haya volumen. Cada campo que el usuario no tiene que llenar es
  tiempo devuelto a cuidar y educar niños.
- **Preferir lo espacial/relacional a lo tabular** cuando el dato lo tiene naturalmente. El **mapa del
  salón** es el caso canónico; aplica igual a horarios, rutas de transporte y ocupación de aulas. Un
  docente reconstruye "quién se sienta dónde" de un vistazo en un plano, nunca desde una lista por
  apellido —esa reconstrucción mental es carga que la UI debe absorber.
- **Móvil primero en las superficies de padres y de captura rápida.** Docente pasando lista, acudiente
  viendo saldo: pantalla chica, una mano, con prisa. Layout fluido, objetivos táctiles amplios.

---

## 3. Arquitectura de tokens (dónde vive la suavidad y la marca)

Todo color, radio, sombra, espaciado y familia tipográfica se define **una vez** en `tokens.css` bajo
`@layer`. Las vistas consumen tokens; **no** definen valores crudos. Dos categorías, con permisos
distintos:

| Categoría | Ejemplos | ¿La institución la toca? |
|---|---|---|
| **Slots de marca** | `--brand-primary`, `--brand-accent` (opcional), `--brand-font-display`, logo | **Sí** (acotado — ver §4) |
| **Fijos del sistema** | neutros/grises, fondos, bordes; **colores semánticos de estado** (éxito/alerta/error/info); fuente de cuerpo/UI; radios, sombras, escala de espaciado | **No** |

**Por qué los semánticos y neutros son fijos:** de ellos depende la accesibilidad AA y el *significado*.
Si un colegio pusiera su rojo corporativo como `--brand-primary` y ese rojo fuera también el "error",
se rompería accesibilidad y semántica a la vez. La marca vive en un subconjunto de identidad
(navegación, acción primaria, acentos); los estados viven en tokens fijos, distinguibles, y **nunca
codifican significado solo por color** (siempre ícono + texto — misma regla que §2, ahora como piso AA).

**Derivación en vez de paleta completa.** La institución define **1–2 colores**; el sistema *deriva* el
resto con CSS nativo: `color-mix()` y relative color syntax (`rgb(from …)`) para tints, shades, fondos
suaves y estados hover. Esto cumple "sin Sass" (la función de aclarar/oscurecer la hace el navegador,
no un preprocesador), no requiere build, y es tokens-only puro.

```css
/* ejemplo conceptual — en tokens.css, @layer */
--brand-primary-soft:  color-mix(in oklch, var(--brand-primary) 12%, white);
--brand-primary-hover: color-mix(in oklch, var(--brand-primary) 85%, black);
```

> **No depender de `contrast-color()`** aún: su soporte no es confiable. El contraste texto/marca se
> garantiza validando el color **al momento de configurarlo** (server-side, ver §4/§8), no con un truco
> de CSS en runtime. Si `contrast-color()` se vuelve confiable, puede *complementar*, nunca reemplazar
> esa validación de entrada.

**La suavidad es token, no decisión por vista:** radios generosos, sombras de bajo contraste,
saturación baja, mucho aire. Definido una vez; imposible sobrecargarse sin salirse del sistema.

---

## 4. Marca por institución

La config de marca vive en el registro de `Core::Institution` (**global, sin RLS**, coherente con la
identidad de `LEAN.md §3.2`) y se resuelve por subdominio con el `Tenant::Resolver` que ya existe.

### 4.1 Inyección
El layout del inquilino renderiza en `<head>` un `<style>` mínimo con las custom properties de esa
institución (`--brand-primary`, `--brand-accent`, `--brand-font-display`, y el `@font-face` si aplica).
Un solo punto de inyección; el resto de tokens ya está en `tokens.css`. Sin build, sin ramificar CSS
por institución.

### 4.2 Color
1–2 colores; el resto derivado (§3). Neutros y semánticos fijos. Contraste validado a la entrada.

### 4.3 Tipografía
- **Fuente de cuerpo/UI: fija.** Una sans altamente legible (buena altura-x). Protege el principio 1
  (legible para un niño) y 5 (suave) —no es negociable por marca.
- **Fuente de display/títulos: brandable.** Es el slot donde una marca imprime carácter sin arriesgar
  legibilidad del cuerpo.
- **Cómo llega la fuente, en dos escalones:**
  - **(a) Allowlist curada** — un conjunto de fuentes ya empaquetadas como assets de Propshaft; la
    institución elige. Es el default seguro y lo primero a construir (sin subida arbitraria, sin
    problema de licencias/rendimiento).
  - **(b) Fuente subida** — vía Active Storage (core de Rails, **no** gema nueva), con `@font-face`
    inyectado apuntando a la URL del asset. Va después y gateado. Arrastra dos cav*eats*: **licencia**
    (la institución debe tener derechos) y **rendimiento** (usar `font-display: swap`, preload; el
    subsetting queda como paso manual/opcional, no se construye pipeline). Escalón (b) es **decisión
    abierta** —ver §8.

### 4.4 Logo
- Adjunto vía Active Storage sobre `Core::Institution`. Dos slots: **logo principal** (login, header de
  nav) y **marca compacta** para espacios estrechos. Partial `shared/_brand_logo`.
- **Fallback a nombre de la institución en texto** si no hay logo cargado.
- **Alt text obligatorio** (AA). Dimensiones/aspecto controlados por el contenedor de despliegue, nunca
  confiando en el archivo subido.

---

## 5. Representación visual sobre tabular (mapa del salón como caso canónico)

El principio que sobrevive como norma de UI: **cuando el dominio tiene estructura espacial o relacional
natural, represéntala visualmente antes que tabularmente.**

Se construye en **dos tiempos**, respetando el orden de dependencias del proyecto:

1. **La superficie (construible ya).** El mapa del salón como plano —quién se sienta dónde— solo
   necesita el dato de *asiento*: espacial, poco sensible, el colegio ya lo tiene. Alertas suaves
   encima (alérgenos, acomodaciones, cumpleaños) que ya son datos existentes. **Sin** grafo de
   interacciones entre menores en este tiempo.
2. **La capa de interacciones/analítica (espera al dominio de BI).** Cualquier dato *inferido* sobre
   relaciones, carácter o interacción entre estudiantes es del dominio de BI, y cuando llegue, el
   cuidado de datos de NNA (Habeas Data, Ley 1581, minimización, "nunca exponer directorios ni
   autocompletar por nombre" de `LEAN.md §7.1`) **viaja con ella**. No se acumula ese dato antes de que
   ese dominio decida cómo tratarlo.

Aplicaciones de la misma orientación fuera del salón: horarios (rejilla temporal), transporte (mapa de
ruta/paradas), aulas (ocupación). En todas, **visual antes que lista**.

---

## 6. Cómo se construye (vanilla, sin traicionar el stack)

- **Gráficos = SVG renderizado en el servidor**, en partials de `shared/` (p. ej.
  `shared/_classroom_map`). ERB que escupe SVG. Cero librería de charting, cero build, greppable.
- **Stimulus solo para el comportamiento encima** (hover, tooltip, selección) —no para dibujar.
- **Componentes compartidos**: reutilizar antes de crear local; **promover a `shared/` al usarse en ≥2
  dominios** (misma regla que `LEAN.md §3.4`, ya aplicada con `_timeline`, `_audit_entry_row`).
- **Íconos**: sprite SVG + `shared/_icon` (§2). Sin icon-font.
- **Nada de estado en el navegador** para persistencia de UI que deba sobrevivir: sigue las
  convenciones de Rails (params, sesión, DB), no `localStorage` como sustituto de servidor.

---

## 7. Accesibilidad (AA como piso, no como extra)

- **AA de contraste** en todo texto; validado a la entrada para los slots de marca (§4.2).
- **El color nunca es el único portador de significado** — siempre acompañado de ícono + texto
  (converge con §2 y §3).
- **Objetivos táctiles amplios** en superficies móviles (padres, captura rápida).
- **Foco visible** y navegación por teclado en todo control.
- **Fuente de cuerpo legible fija** (§4.3) — la marca no puede degradar la legibilidad del contenido.

---

## 8. Decisiones abiertas (bloquean la graduación a v1.0.0)

| # | Decisión | Recomendación / lean |
|---|---|---|
| **U1** | **Fuente subida (escalón b) vs. solo allowlist** | Empezar con allowlist (a). Habilitar subida vía Active Storage solo si una marca real lo exige; entonces resolver licencia + `font-display` + preload. No construir pipeline de subsetting. |
| **U2** | **Mecanismo de validación de contraste** de `--brand-primary` contra neutros | Validación **server-side al configurar la marca** (rechaza/advierte si falla AA). No depender de `contrast-color()`. Falta decidir dónde corre esa validación (ver U3). |
| **U3** | **Dónde se edita la config de marca** | Lean: **plano de control / provisioning** (encaja con "provisioning de instituciones" del backlog de `LEAN.md §9`), con auto-servicio del `institution_admin` como fase posterior. La marca es identidad, rara, de nivel admin. |
| **U4** | **Set inicial de la allowlist de fuentes de display** | Curar 3–5 caras legibles y de licencia libre (p. ej. open source), empaquetadas como assets. Pendiente elegirlas. |

---

## 9. Ideas parqueadas para el dominio BI (NO son norma de UI)

> El principio 3 en su versión ambiciosa —fichas de estudiante tipo RPG/MMO con dimensiones humanas,
> fortalezas, gustos, "mapa de calor" de interacciones del aula— es material del **dominio de BI**, que
> se desarrollará en **otro chat del proyecto** para darle rienda suelta. Aquí solo se deja el pin, no
> la norma.

Al construir ese dominio, dos recordatorios que nacieron en esta conversación y deben viajar con él:

- **Cuidado de datos de NNA es no-negociable**: cuantificar/persistir carácter, relaciones o
  interacciones entre menores toca directamente Habeas Data (Ley 1581) y la postura de minimización de
  `LEAN.md §7.1`. Se diseña con ese cuidado desde el dato, no se añade después.
- **Orientación pedagógica sugerida** (a discutir en ese chat, no cerrada): fortalezas cualitativas y de
  autoría docente sobre métricas automáticas de personalidad; el estudiante contra sí mismo, nunca
  ranking entre niños; lo que ve el acudiente, digno (crecimiento y fortalezas, no un "score" que suene
  a etiqueta).

La parte de UI de esas fichas (SVG server-rendered, tokens suaves, `--brand-primary`) ya está cubierta
por §5/§6 cuando llegue el momento —lo que espera es el *dato*, no la *forma de mostrarlo*.

---

## 10. Changelog

### v0.1.0 — 2026-07-16
- Creación del documento de disciplina de UX/UI como hermano de `LEAN.md`/`HISTORIA.md`.
- Se fijan: los seis principios agrupados en cuatro ejes; las orientaciones operativas (ícono+etiqueta,
  un verbo por pantalla, perdonar el error, defaults inteligentes, visual sobre tabular, móvil primero);
  la arquitectura de tokens (slots de marca vs. fijos del sistema, derivación con `color-mix()`,
  contraste validado a la entrada); el modelo de marca por institución (color 1–2 + derivación,
  tipografía de cuerpo fija / display brandable con allowlist y subida opcional, logo por Active
  Storage con fallback y alt); la orientación de dos tiempos para representación espacial (superficie ya
  / interacciones al dominio BI); el cómo vanilla (SVG server-rendered en `shared/`, Stimulus encima);
  y AA como piso.
- Se abren las decisiones U1–U4 que bloquean la graduación a `v1.0.0`.
- Se parquean las ideas de BI (fichas tipo RPG, mapa de calor de interacciones) explícitamente **fuera**
  de la norma de UI, para desarrollarse en otro chat, con el cuidado de datos de NNA anexado.
