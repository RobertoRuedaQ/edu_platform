# edu_platform — Documento maestro del dominio `analytics_bi` (HPS / BI Empático)

> **Qué es este documento.** La **fuente única de verdad del dominio `analytics_bi`**: la filosofía,
> la arquitectura de datos, el modelo de acceso, las guardas de confidencialidad y la segmentación en
> slices del *Sistema de Posicionamiento Humano* (HPS). Es hermano de `PROJECT_STATE.md`
> (arquitectura/estado global), `UX_UI.md` (disciplina de FE), `LINEAMIENTOS_MVP.md` (alcance del
> MVP), `OPEN_PROCESS.md` (backlog/guardrails) e `HISTORIA.md` (narrativa). Se lee/pega al iniciar
> cualquier slice de este dominio.
>
> **Regla de precedencia (importante).** Para todo lo relativo a `analytics_bi`, **este documento
> manda sobre `LINEAMIENTOS_MVP.md`** cuando haya contradicción (el MVP trata BI como "dashboards";
> aquí se redefine como el HPS). **NO manda sobre los invariantes de arquitectura de
> `PROJECT_STATE.md`** (tenancy/RLS, roles de PG, Zeitwerk colapsado, RBAC rol+scope, sin gemas
> nuevas salvo bottleneck): esos se respetan siempre. Ante contradicción con un invariante de
> arquitectura, gana el invariante. **El repositorio es la fuente de verdad del código**: ante
> discrepancia entre esto y el disco, gana el disco y se corrige aquí en la siguiente versión.

| Campo | Valor |
|---|---|
| **Versión** | `v0.9.0` |
| **Fecha** | 2026-07-21 |
| **Estado global de referencia** | `PROJECT_STATE.md v1.43.0` — **LAS 8 LENTES/SLICES DEL ROADMAP ORIGINAL ESTÁN CERRADAS.** `analytics_bi` AMBAS mitades reales (`InstitutionDashboard`/`CrossTenantReportRoster`) + Lentes 1/2/3/5 reales + temporalidad año-a-año real + instrumento de carácter (T2) real + **Lente 4 (Núcleo Familiar) real**. |
| **Estado del dominio** | Filosofía, tiers de confidencialidad, ERD conceptual, modelo de acceso de las 5 lentes, guardas de RLS/clínicas, estrategia de procesamiento y slicing — **fijados**. **Slice 1 (cross-tenant) cerrado** (primera conexión BYPASSRLS real). **Slice 2 (Lente 1, mapa espacial + heat) cerrado (v1.36.0)** — geometría de aula (`classroom_layouts`/`seat_assignments`) net-new en `group_management` (decisión A2), heat derivado in-memory de T1 (notas/asistencia). **Slice 3 (Lente 5, "Auras de Cuidado") cerrado (v1.37.0)** — proyección `care_auras` net-new en `analytics_bi`, escrita SOLO por `AnalyticsBi::Aura::Projector` invocado desde `counseling` (cero PII clínica, cero acoplamiento inverso), leída por el docente como un ícono abstracto sobre la Lente 1 (`hps.aura.view`); aislamiento clínico probado a nivel de MODELO (SQL tap + estructura de asociaciones). **Slice 4 (temporalidad año-a-año) cerrado (v1.38.0)** — `student_placements` net-new en `group_management` (decisión A1 resuelta) efectivo-fechado/append-only vía `GroupManagement::SectionReassigner`, el ÚNICO seam que mueve un estudiante de sección; `hps_term_snapshots` net-new en `analytics_bi` (§7), congelado por `AnalyticsBi::Hps::Snapshotter` vía el fan-out `HpsTermSnapshotJob`/`HpsTermSnapshotAllJob`. **Slice 5 (instrumento de carácter, T2) cerrado (v1.39.0)** — el instrumento staff-autoría (`character_frameworks`→`evaluations`→`dimension_scores`, molde rúbrica con `framework_snapshot` congelado) y, SEPARADO, el camino de pares/acudientes (`peer_appreciations`, catálogo cerrado `peer_appreciation_tags`, umbral de agregación, moderación append-only) gateado por el **primer consentimiento del codebase** (`character_program_consents`). **Slice 6 (Lente 2, "Ficha de Personaje") cerrado (v1.40.0)** — la primera lente de AUTOSERVICIO: radar/brújula/medallas/crecimiento consumidos en solo-lectura de las tablas del Slice 5 (cero tablas nuevas), la UI de consentimiento del acudiente y la superficie de dar un aporte de par (ambas deferidas del Slice 5), gateadas por identidad (`GuardianScope`/`StudentSelfScope`), nunca RBAC. **Slice 7 (Lente 3, "Constelación de Afinidades") cerrado (v1.42.0)** — `affinity_taxonomy`/`student_affinities` net-new (T2), scope institución-wide o `department_id` (especialista, reusando el `:department` scope reader existente), relajación acotada de §10.3 con Cytoscape.js (importmap, progressive enhancement — fallback accesible siempre real). **Slice 8 (Lente 4, "Núcleo Familiar") cerrado (v1.43.0)** — `households`/`guardian_relationships` net-new (T2, extienden `core.guardian_students` 1:1, nunca lo duplican); grafo orbital con Cytoscape.js REUSADO (segunda librería, cero librerías nuevas); detección de hermanos vía query (cero tabla nueva); "tensión del vínculo" computada en vivo de señales T1 reales; alerta de lazos fraternales (read-model, auditada); `custody_kind` segregado por construcción (nunca en el grafo). **Con esto, las 8 lentes/slices del roadmap original de este documento (§11) están todas cerradas.** Trabajo futuro del dominio (Lente 6 "alertas tempranas" del `guidelines/CLOSURE_PLAN.md`, autoría real de frameworks/taxonomías, portal de afinidades/aportes-de-acudiente) es backlog nuevo, no deuda de este roadmap. |

**Versionado (igual que los demás docs):** MAJOR = cambia una decisión de diseño asentada del dominio
o su modelo de tiers · MINOR = se cierra un slice o una decisión abierta · PATCH =
correcciones/redacción/reconciliación con el repo. Historia no se borra: lo revertido se marca
*supersedido*.

---

## 1. Filosofía: BI Empático / Sistema de Posicionamiento Humano (HPS)

`analytics_bi` **no es un módulo de reportes tabulares**. Es un traductor: convierte datos de la vida
escolar (asistencia, calificaciones, dinámicas familiares, carácter, afinidades, señales
psicopedagógicas) en **metáforas visuales que despiertan empatía** en el observador humano (docente,
acudiente, orientador, directivo) para **gatillar una intervención humana inmediata**. La métrica de
éxito no es "cuántos gráficos se vieron", es "cuántas conversaciones de cuidado se activaron".

### 1.1 Los no-negociables (restricción de esquema, no capa posterior)

Estos principios **se diseñan desde el dato**, no se añaden después. Nacen de `UX_UI.md §9` y de la
postura de Habeas Data de `PROJECT_STATE.md §9.2`, y son vinculantes para todo slice:

1. **Cuidado de datos de NNA es primero.** Cuantificar/persistir carácter, relaciones o interacciones
   entre menores toca Habeas Data (Ley 1581 + decreto de datos de NNA). Cada tabla de este dominio se
   diseña con minimización, consentimiento del acudiente donde aplique, y trazabilidad de tratamiento.
2. **Cualitativo y de autoría humana sobre "score algorítmico".** El carácter se evalúa con un
   **instrumento estructurado tipo rúbrica** (autoría docente + aporte de pares/acudientes con
   resguardos), **nunca** con un modelo automático que "puntúe la personalidad" de un menor. El sistema
   describe fortalezas observadas, no emite un veredicto de personalidad.
3. **El estudiante contra sí mismo, nunca ranking entre niños.** Ninguna lente ordena, compara ni
   percentila a un menor contra otro. Las tendencias son **intra-estudiante en el tiempo**.
4. **La vista del acudiente es digna.** Crecimiento y fortalezas, jamás un "score" que suene a
   etiqueta. Se elimina la toxicidad del boletín tradicional, no se le pone piel de videojuego.
5. **Aislamiento clínico estricto.** El diagnóstico psicopedagógico vive en `counseling` y **nunca**
   se filtra por serializadores, logs ni queries casuales. El docente recibe una **proyección
   abstracta** ("aura de cuidado"), nunca el diagnóstico.
6. **Sin buscador de personas, nunca.** Ninguna lente introduce autocompletar por nombre/documento ni
   directorios navegables de menores (regla vigente de `GuardianScope`).

### 1.2 Las cinco lentes (resumen)

| # | Lente | Observador | Metáfora |
|---|---|---|---|
| 1 | **Mapa de Empatía Espacial** | Docente / director de grupo | Plano IRL del aula; *dimming* de estables + heat de quien necesita atención |
| 2 | **Ficha de Personaje** | Acudiente (y estudiante) | Radar de fortalezas, brújula de carácter, medallas, feedback constructivo |
| 3 | **Constelación de Afinidades** | Especialistas / entrenadores / directores de arte | Nube de nodos-estrella por talento, transversal al colegio |
| 4 | **Núcleo de Soporte** | Psicoorientación / directivas | Grafo orbital de la familia; tensión del vínculo; alerta de lazos fraternales |
| 5 | **Velo de Confidencialidad / Auras de Cuidado** | Orientador ──► docente | Doble nivel: el orientador ve el detalle; el docente solo un aura abstracta sobre el pupitre |

---

## 2. Contrato con lo asentado (v1.34.0)

### 2.1 Se reusa tal cual (no se reinventa)

- **Tenancy + RLS**: toda tabla nueva lleva `institution_id`, `ENABLE + FORCE ROW LEVEL SECURITY`,
  índice líder por `institution_id`, GUC vía `Tenant::Guc`/`within_tenant`. PK `uuidv7()`. Sin
  `default_scope` — Query objects siempre.
- **RBAC rol+scope**: `IdentityAccess::PermissionCheck`, `authorize!` (puerta dura) + `can?`
  (cosmético). Columnas de scope existentes: `scope_department_id`/`scope_grade_level_id`/
  `scope_group_id` + `valid_from`/`valid_until`. Lectores de scope:
  `Authorization::Assignment::SCOPE_READERS` (`department_id`/`group_id`/`grade_level_id`/`route_id`).
- **Frontera supervisión vs. autoservicio** (`CONCEPTOS_TECNICOS.md §4`): las lentes de terceros
  (1, 3, 4, 5) son **supervisión** (`authorize!` + scope + `Navigation::Registry`); la ficha del hijo
  (2) es **autoservicio** (scope de identidad, sin `authorize!`, fuera del Registry).
- **Portales de persona**: `Core::Access::GuardianScope`/`StudentSelfScope` resuelven "mis hijos"/"mi
  propio registro". La Lente 2 cuelga de ahí, exactamente como `report_cards`/`attendance` en el portal.
- **Molde #4** (`PROJECT_STATE.md §6.6`): índice-con-scope → show → acción gateada, para las vistas
  de supervisión de este dominio.
- **Rol Postgres `edu_bi_reader`** (único `BYPASSRLS`, auditado): reservado a la consolidación
  cross-tenant. **Las 5 lentes NO lo usan** (ver §6.1).
- **`counseling`** (`Case`/`SessionNote`/`Referral`, Clase A/S): dueño del tier clínico. La Lente 5
  **lee proyecciones**, nunca posee el diagnóstico.
- **Patrón snapshot** (`report_cards.lines_snapshot`, `ControlPlane::Subscription#price_tiers_snapshot`,
  `assignments.rubric_snapshot`): congelar estructura/resultado como `jsonb` al publicar.
- **Patrón instrumento-normalizado** (`assignments` rúbricas: `RubricTemplate`/`RubricCriterion`/
  `RubricLevel` + snapshot): molde exacto para el instrumento de carácter (§5.4).
- **`ControlPlane::Usage::Ingest.emit`**: si `analytics_bi` llega a ser un dominio medido, emite por
  aquí (nunca `.call`). Hoy no tiene evento facturable claro — nace `metered:false`.

### 2.2 Qué supersede este documento (explícito)

- **`analytics_bi` deja de ser "solo read-models/reporting".** El mapa de dominios lo describe como
  "vistas materializadas, read models". A partir de aquí **también posee los instrumentos formativos
  del HPS** (evaluación de carácter, taxonomía de afinidades, metadatos de núcleo familiar y
  proyección de auras) — dato *primario* con escritura real, no solo lectura. Justificación: es el
  insumo del HPS y no tiene otro dueño natural; concentrarlo en un dominio mantiene toda la data
  sensible de desarrollo humano + sus reglas de acceso en un solo lugar auditable, en vez de
  esparcirla. (Corregir `PROJECT_STATE.md §4` línea de `analytics_bi` al abrir el primer slice de
  Tier 2.)
- **Se relaja el guardrail "sin librería de charting/JS" — acotado (ver §10.3).** Solo para la viz
  interactiva de este dominio, solo librerías JS *populares y mantenidas* vía importmap sin build, y
  con la regla dura de que **cero dato sensible cruza al cliente**. Cualquier otra librería → decisión
  del PO.
- **Nota de sincronía pendiente:** `PROJECT_STATE.md §4` línea 134 aún dice "Sigue en fase stub" para
  `analytics_bi` — quedó desactualizado frente a v1.34.0 (`InstitutionDashboard` real). Corregir al
  tocar ese doc.

### 2.3 Qué respeta sin tocar

Los invariantes de tenancy, la separación de roles de PG, la disciplina Propshaft/importmap sin build
para todo lo que **no** sea la viz interactiva acotada de §10.3, tokens-only, AA, fail-closed,
append-only de auditoría, y la disciplina **recon-first** por slice.

---

## 3. Los tres tiers de confidencialidad (marco organizador)

Todo dato que toca el HPS cae en exactamente un tier. El tier decide **dónde vive**, **quién escribe**,
**quién lee** y **cómo se proyecta**. Es el eje que evita mezclar lo clínico con lo formativo (el error
más caro posible en este dominio).

| Tier | Nombre | Dueño | Escribe | Lee (y cómo) | Ejemplos |
|---|---|---|---|---|---|
| **T1** | **Operacional** | dominios existentes | flujos ya construidos | supervisión (RBAC+scope) / autoservicio (portal) | notas (`schedules`), asistencia (`attendance`), matrícula, `guardian_students` |
| **T2** | **Formativo** | **`analytics_bi`** | docente/orientador (autoría) + par/acudiente (aporte con resguardos) | acudiente ve *lo digno* de su hijo (autoservicio); staff ve por supervisión | evaluación de carácter, tags de afinidad, fortalezas, medallas, metadatos de núcleo familiar |
| **T3** | **Clínico** | **`counseling`** | orientador/psicólogo | **solo** el equipo clínico ve el detalle; el docente ve **aura abstracta** | tests emocionales, diagnósticos, notas de terapia, remisiones |

**Invariante de tiers:** dato T3 **nunca** se muestra fuera de `counseling` salvo como proyección
abstracta (aura). Dato T2 **nunca** expone un ranking ni un score de personalidad. Dato T1 se reusa
por lectura, `analytics_bi` no lo re-posee.

---

## 4. Modelo de acceso de las 5 lentes

Toda lente pasa por las **dos compuertas en serie**: (1) entitlement del addon `analytics_bi`
(`Entitlement::Registry` propio, `config/entitlements/analytics_bi.rb`), y (2) autorización. La
diferencia por lente es el **tipo** de segunda compuerta:

| Lente | Compuerta #2 | Permiso(s) propuesto(s) | Scope reader | Superficie |
|---|---|---|---|---|
| 1 · Mapa Espacial | **Supervisión** (RBAC) | `hps.classroom.view` | `group_id` (grupo) / `grade_level_id` | `Navigation::Registry` |
| 2 · Ficha | **Autoservicio** (identidad) | — (ninguno: `GuardianScope`/`StudentSelfScope` *es* la puerta) | — | portal, fuera del Registry |
| 3 · Constelación | **Supervisión** (RBAC) | `hps.constellation.view` | institución-wide o `department_id` (especialista) | `Navigation::Registry` |
| 4 · Núcleo Familiar | **Supervisión** (RBAC) | `hps.family.view` | institución-wide (orientación/directivas) | `Navigation::Registry` |
| 5 · Auras (lado orientador) | **Supervisión** (RBAC) | `counseling.*` existente | institución-wide clínico | `counseling` |
| 5 · Auras (lado docente) | **Supervisión** (RBAC) | `hps.aura.view` (solo aura abstracta) | `group_id` | dentro de la Lente 1 |

Permisos de **escritura** del instrumento de carácter (T2), separados de la lectura:
`hps.character.author` (docente/orientador crea/publica evaluaciones), `hps.character.moderate`
(modera aportes de pares/acudientes). El **aporte del par** no es un permiso RBAC: es una acción de
identidad del estudiante sobre su compañero, gateada por co-pertenencia a la sección + consentimiento
+ resguardos (§5.4), nunca por rol.

**Todos los permisos nuevos se agregan a `IdentityAccess::SeedPermissions::CATALOG`** (se siembran por
institución). `hps.*` **no** se hereda por el bootstrap `institution_admin` como cross-tenant —
`cross_tenant_reports.view` sigue reservado a `bi_auditor`/`edu_bi_reader`.

---

## 5. Diseño de datos (ERD conceptual)

> Formas de referencia, no esquema final. Cada tabla se recon-ea al construirse y respeta:
> `institution_id` + RLS FORCE, `uuidv7()`, sin `default_scope`, índice líder `institution_id`, dinero
> en `*_cents bigint` si aplica, `deleted_at`/`status` para soft-delete donde corresponda.

### 5.0 Panorama de dependencias de dato (el hallazgo que ordena el roadmap)

| Insumo | ¿Existe hoy? | Acción |
|---|---|---|
| Notas / asistencia / matrícula / snapshots headcount | ✅ sí (T1) | leer |
| `guardian_students` (grafo familiar base) | ✅ sí (T1) | leer + extender (§5.6) |
| `counseling` (`Case`/`SessionNote`/`Referral`) | ✅ sí (T3) | leer/proyectar (§5.7) |
| Geometría del aula (pupitres fila/columna) | ❌ no | modelar (§5.3) |
| Evolución temporal año-a-año (placements históricos) | ⚠️ parcial (`students.section_id` es puntero mutable) | modelar (§5.2) |
| Instrumento de evaluación de carácter | ❌ no | modelar (§5.4) — T2 |
| Taxonomía de afinidades / talentos | ❌ no | modelar (§5.5) — T2 |
| Metadatos de núcleo familiar (custodia/hogar) | ❌ no | modelar (§5.6) — T2 |
| Tests emocionales / auras | ⚠️ base clínica sí; proyección no | modelar en `counseling` + proyección (§5.7) |

> **Trampa documentada:** `student_support` (convivencia/incidencias/historia médica/acomodaciones)
> **NO tiene tablas reales** (Clase C, `OPEN_PROCESS.md`). No es fuente de dato hoy. La libreta de
> horario/`rooms` de `schedules` tampoco. Cualquier lente que las asuma requiere primero un slice de
> modelado en su dominio dueño — **no** se inventa esquema ajeno desde `analytics_bi`.

### 5.1 Reuso de dato existente (T1, solo lectura)

`analytics_bi` lee por **query objects propios** que aplican el filtro de inquilino explícito, sin
poseer estas tablas ni escribir en ellas:

- `Schedules::Assessment.graded` → notas (radar académico, heat de rendimiento).
- `Attendance::AttendanceRecord` → asistencia (heat de presencia, señal de riesgo).
- `Schedules::Enrollment` + `academic_terms` → "matriculado en el término" (vía
  `Schedules::ActiveTermEnrollmentScope`, nunca re-derivar el join).
- `Core::guardian_students` → grafo familiar base.
- `ControlPlane::StudentHeadcountSnapshot` → tendencias ya persistidas (histórico sin recomputar).

### 5.2 Temporalidad año-a-año (integridad histórica)

**Problema:** `students.section_id` es un puntero **mutable** al grupo actual; reorganizar salones
sobreescribe el pasado. El BI necesita responder *"¿cómo cambió el mapa de afinidades de este
estudiante de 2° a 8°?"* sin que una reorganización rompa la historia.

**Solución — tabla de *placement* efectivo-fechada y append-only** (no sobrescribir, cerrar+abrir):

```
student_placements
  id                uuid  PK (uuidv7)
  institution_id    uuid  NOT NULL  (RLS)
  student_id        uuid  NOT NULL  FK -> group_management.students
  section_id        uuid  NOT NULL  FK -> group_management.sections
  grade_level_id    uuid  NOT NULL  FK -> group_management.grade_levels
  academic_term_id  uuid  NOT NULL  FK -> core.academic_terms
  valid_from        date  NOT NULL
  valid_until       date  NULL      (NULL = vigente; se cierra al reubicar)
  created_at ...
índices: (institution_id, student_id, valid_from)  [líder institution_id]
constraint: EXCLUDE USING gist — no solapamiento de placements activos por (institution_id, student_id)
            usando daterange(valid_from, COALESCE(valid_until,'infinity'), '[)')  (btree_gist, molde v1.33.0)
```

- **Escritura**: cuando `group_management` reasigna `students.section_id`, un service object cierra el
  placement vigente (`valid_until = ayer`) y abre uno nuevo — mismo molde simétrico "cerrar el rango
  al terminar" que `Subscription#end!`/`Entitlement#revoke!` (guardrail v1.33.0). `students.section_id`
  se mantiene como **caché del placement vigente** (no se elimina — muchos flujos ya lo leen).
- **Lectura BI**: cualquier análisis retrospectivo se une a `student_placements` por `academic_term_id`,
  nunca a `students.section_id` (que solo conoce el presente).
- **Snapshots derivados por término** (§7) cuelgan de este eje temporal: un `hps_term_snapshot` por
  `(student, academic_term)` congela el estado del HPS de ese año, para tendencias baratas.

> **Alcance del slice:** este modelo lo puede introducir `analytics_bi` porque es dato transversal de
> análisis, pero **idealmente lo escribe `group_management`** en su flujo de reasignación (dueño de
> `students`/`sections`). Decisión de frontera a confirmar en el checkpoint del slice temporal.

### 5.3 Geometría del aula (Lente 1)

Distribución dinámica de pupitres por salón y año, reconfigurable a mitad de año **manteniendo el
histórico de ubicaciones**:

```
classroom_layouts                         (una configuración por sección+término, versionable)
  id, institution_id (RLS)
  section_id        FK -> sections
  academic_term_id  FK -> academic_terms
  rows              smallint   (nº filas)
  cols              smallint   (nº columnas)
  board_orientation smallint   (0/90/180/270 — orientación del tablero)
  aisles            jsonb      (posiciones de pasillos: [{after_col:2},{after_row:3}] — geometría pura, no PII)
  version           integer    (incrementa al reconfigurar)
  effective_from    date
  effective_until   date NULL  (NULL = vigente)
índices: (institution_id, section_id, academic_term_id, effective_from)

seat_assignments                          (quién se sienta dónde, efectivo-fechado)
  id, institution_id (RLS)
  classroom_layout_id  FK -> classroom_layouts
  student_id           FK -> students
  row                  smallint
  col                  smallint
  effective_from       date
  effective_until      date NULL
índices: (institution_id, classroom_layout_id, effective_from)
constraint: EXCLUDE USING gist — un asiento (row,col) no puede tener dos estudiantes activos a la vez
            en el mismo layout; y un estudiante no puede tener dos asientos activos a la vez
```

- **Reconfiguración a mitad de año**: se cierra el `classroom_layout` vigente
  (`effective_until = ayer`), se crea `version+1`. Los `seat_assignments` viejos quedan intactos →
  histórico preservado. El docente reconfigura desde una vista de arrastrar-soltar (Stimulus, §10.4).
- **Dato poco sensible**: la geometría y "quién se sienta dónde" es T1 espacial, el colegio ya lo
  tiene. El **heat** (§10.2) se *deriva* de T1 (notas/asistencia); no se persiste "quién necesita
  atención" como columna — se computa en la vista.

### 5.4 Instrumento de evaluación de carácter (T2 — molde rúbrica)

**Decisión (#1 del PO):** un set de evaluación de carácter **como las rúbricas, pero de
comportamiento**. Aporta *varias voces* de quienes comparten con el estudiante (docentes, pares) y
puede involucrar acudientes. Estructurado, auditable, de autoría humana — **nunca** un score
algorítmico (no-negociable §1.1.2).

**Estructura (espeja `assignments` rúbricas):**

```
character_frameworks            (biblioteca reutilizable, author-owned, por institución)
  id, institution_id (RLS)
  name, description, status (draft/published/archived)

character_dimensions            (ej: Lógica, Creatividad, Empatía, Convivencia, Perseverancia)
  id, institution_id (RLS)
  framework_id FK
  name, position, weight (peso relativo — nunca suman 100 obligatorio, molde rúbrica)

character_levels                (descriptores cualitativos por dimensión: "En desarrollo"/"Consolidado"/…)
  id, institution_id (RLS)
  dimension_id FK
  label, descriptor (texto observable, no un número), position

character_evaluations           (una evaluación publicada de un estudiante, por un autor, en un término)
  id, institution_id (RLS)
  student_id       FK -> students
  academic_term_id FK -> academic_terms
  framework_id     FK
  framework_snapshot jsonb       (estructura CONGELADA al publicar — molde rubric_snapshot)
  author_kind      smallint      (teacher / counselor)   ← T2, autoría staff
  author_institution_user_id FK
  status           (draft/published)
  published_at
índice único: (institution_id, student_id, academic_term_id, framework_id, author_institution_user_id)
              — un autor no evalúa dos veces al mismo estudiante en el mismo término con el mismo marco

character_dimension_scores      (el nivel elegido por dimensión, referido al snapshot)
  id, institution_id (RLS)
  evaluation_id FK
  dimension_key text            (referencia al snapshot congelado, no FK viva — molde rúbrica)
  level_label   text
  note          text NULL       (observación cualitativa opcional del autor)
```

**Aporte de pares y acudientes (el feedback "votado por compañeros" del prompt) — con resguardos
duros contra el acoso, tabla SEPARADA de la evaluación de autoría staff:**

```
peer_appreciation_tags          (catálogo CERRADO y predefinido — nunca texto libre del par)
  id, institution_id (RLS)
  label ("Buen compañero", "Creativo/a", "Ayuda a los demás", …)   ← solo constructivos
  category, active (bool)

peer_appreciations              (un aporte de un par o acudiente hacia un estudiante)
  id, institution_id (RLS)
  student_id        FK   (recibe)
  tag_id            FK -> peer_appreciation_tags
  giver_kind        smallint  (peer_student / guardian)
  giver_student_id  FK NULL   (XOR con giver_guardian_user_id, CHECK num_nonnulls=1 — molde v1.20.0)
  giver_guardian_user_id FK NULL
  academic_term_id  FK
  status            smallint  (active / withheld_by_moderation)
índice único PARCIAL: (institution_id, student_id, tag_id, giver_student_id, academic_term_id)
              WHERE status='active'  — un par no repite el mismo tag al mismo compañero en el término
                                       (anti-duplicado/anti-brigading, molde extracurriculars v1.27.0)
```

**Resguardos anti-acoso (invariantes de la Lente 2, no opcionales):**

1. **Sin texto libre del par**: el par/acudiente solo elige de `peer_appreciation_tags`, un catálogo
   *curado y solo constructivo*. Imposible escribir un insulto.
2. **Umbral de agregación antes de surfacear**: un tag solo aparece en la ficha tras **N aportes
   distintos y legítimos** (N configurable, ≥3 sugerido). Nunca se muestra un aporte individual.
3. **Nunca atribuible**: el estudiante/acudiente ve *"reconocido como creativo por sus compañeros"*,
   jamás *quién* lo dio. Solo `hps.character.moderate` ve la trazabilidad (auditada).
4. **Solo fortalezas**: la ficha (Lente 2) es *strengths-only y digna* (no-negociable §1.1.4). Nada
   negativo del par se surface jamás.
5. **Consentimiento del acudiente** para que un menor participe dando/recibiendo aportes de pares
   (Habeas Data) — acuse explícito, molde `assignments.requires_consent`; sin consentimiento, el menor
   no participa y queda registro auditable.
6. **Moderación + append-only**: `withheld_by_moderation` es un flip de estado, nunca `destroy`; todo
   aporte se audita (`audit_events`).

**Cómo alimenta las lentes:** las `character_evaluations` (autoría staff) → el **radar** de la Lente 2
y la **brújula de carácter** (alineación cualitativa derivada de las dimensiones, no un cálculo de
"bueno/malo"). Las `peer_appreciations` agregadas → las **medallas/tags** de la Lente 2 y los **nodos**
de afinidad de la Lente 3.

### 5.5 Taxonomía de afinidades y constelación (T2 — Lente 3)

Talentos, artes, pasatiempos y deportes (dentro o fuera del colegio), buscables por taxonomía:

```
affinity_taxonomy               (árbol curado de talentos — NO texto libre por menor)
  id, institution_id (RLS)
  parent_id  FK NULL            (jerarquía: Deportes > Fútbol; Artes > Piano)
  name, kind (sport/art/hobby/academic), active
  search_tsv  tsvector          (FTS nativo PG18 — índice GIN para el buscador por taxonomía)
índice: GIN(search_tsv)

student_affinities              (vínculo estudiante ↔ talento)
  id, institution_id (RLS)
  student_id      FK
  taxonomy_id     FK
  source          smallint      (teacher_observed / guardian_reported / self_reported)
  context         smallint      (in_school / out_of_school)
  academic_term_id FK           (para la evolución temporal §5.2)
índice único: (institution_id, student_id, taxonomy_id, academic_term_id)
```

- **Buscador por taxonomía** = FTS sobre `affinity_taxonomy` (no sobre nombres de menores → respeta
  "sin buscador de personas"). El especialista busca *un talento*, y la constelación **enciende los
  nodos** (estudiantes con esa afinidad en su scope) mientras difumina el resto (§10.2 dimming).
- **jsonb vs. relacional (respuesta al REQ2 del prompt):** **relacional explícito** para afinidades y
  aportes de pares (integridad, unicidad, anti-duplicado, auditoría). **jsonb solo** para el snapshot
  congelado de estructura (`framework_snapshot`) — nunca para dato que necesita constraint o búsqueda.

### 5.6 Núcleo familiar / grafo orbital (T2 — Lente 4)

Extiende el `guardian_students` existente (no lo reemplaza) con la metadata que el grafo orbital
necesita:

```
guardian_relationships          (metadata de la relación acudiente↔estudiante — T2 sensible)
  id, institution_id (RLS)
  guardian_student_id  FK -> core.guardian_students   (extiende, no duplica)
  relationship_kind    smallint  (mother/father/grandparent/legal_guardian/…)
  is_primary_caregiver bool
  custody_kind         smallint NULL  (shared/sole/…)   ← sensible; segregado (§6.2)
  household_id         uuid NULL      (agrupa cuidadores del mismo hogar)

households                      (tipología de hogar — opcional, sensible)
  id, institution_id (RLS)
  kind smallint  (nuclear/single_parent/extended/…)
```

- **Grafo orbital**: el estudiante en el centro; cuidadores en órbitas por `is_primary_caregiver`;
  hermanos detectados por **`guardian_students` compartido** (dos estudiantes con el mismo acudiente
  primario) — no requiere tabla nueva, es una query.
- **"Tensión del vínculo" = engagement del acudiente** (read-model, no columna persistida): se *deriva*
  de señales T1 ya existentes — último login (`sessions`), lectura de mensajes
  (`conversation_participants.last_read_at`), acuse de consentimientos, apertura del portal. Se computa
  en memoria; si pesa, se snapshotea por término (§7).
- **Alerta de "lazos fraternales"** (read-model de análisis): detecta cuando el comportamiento de
  varios hermanos en distintos grados **se altera en la misma ventana temporal** (señal de crisis en
  el hogar). Se computa cruzando señales T1 (caída de asistencia/notas/asignaciones) de estudiantes
  con acudiente compartido, en una ventana móvil. **Es una señal para intervención humana, no un
  veredicto** — surface solo a orientación/directivas (`hps.family.view`), auditada.

### 5.7 Auras de cuidado (Lente 5 — T3 clínico → proyección abstracta al docente)

**Aislamiento clínico (respuesta al REQ3 del prompt):** el detalle psicopedagógico vive y **se queda**
en `counseling`. `analytics_bi` **no lee** diagnósticos ni notas de terapia. Lo único que cruza la
frontera es una **proyección abstracta** que el orientador *decide publicar* como instrucción de trato:

```
care_auras                      (proyección PÚBLICA-al-docente — NO contiene diagnóstico)
  id, institution_id (RLS)
  student_id       FK
  aura_kind        smallint   (enum CERRADO: private_or_oral_evaluation / positive_reinforcement_public /
                               extra_time / quiet_space / …)   ← instrucción de trato, no diagnóstico
  guidance_text    text       (redactado por el orientador, apto para el docente — sin dato clínico)
  authored_by_counselor_id FK
  effective_from, effective_until date
  academic_term_id FK
índice: (institution_id, student_id, effective_from)
```

- **Doble nivel**: el orientador (permiso `counseling.*`) crea el aura **desde** `counseling`, donde sí
  ve el `Case`/`SessionNote` que la motiva. El docente (permiso `hps.aura.view`) ve **solo** la fila
  `care_auras` (enum + `guidance_text`), superpuesta como un ícono discreto sobre el pupitre en la
  Lente 1. El docente **nunca** alcanza `counseling`.
- **`care_auras` es una tabla de `analytics_bi`** (proyección), poblada por un service object invocado
  desde `counseling` (cross-domain por FK + service, nunca leyendo tablas ajenas). Contiene
  **cero PII clínica** — el `guidance_text` es responsabilidad del orientador y se audita.
- **Segregación de columnas T3** (dentro de `counseling`, refuerzo): diagnóstico/notas clínicas van
  cifradas (`encrypts`), en su propia tabla, **excluidas de todo serializador por defecto**
  (allowlist explícita de atributos, nunca `to_json` sin filtro), y **filtradas de logs**
  (`filter_parameters`). Ninguna query de `analytics_bi` referencia esas columnas.

**Implementado (v1.37.0, Slice 3) — desviaciones y decisiones respecto a esta forma de referencia:**

- **`aura_kind` es `string` + CHECK, no `smallint`.** El molde de la casa para un enum cerrado es
  `t.string` + `add_check_constraint` (ver `extracurriculars.kind`), no un `smallint` con mapeo — más
  greppable y explícito ("aburrido/explícito/greppable"). El set cerrado es
  `private_or_oral_evaluation`/`positive_reinforcement_public`/`extra_time`/`quiet_space`; las
  etiquetas humanas viven en `AnalyticsBi::CareAura::KIND_LABELS` (única fuente, compartida por la
  superficie de autoría y el badge del docente).
- **`authored_by_counselor_id` FK a `institution_users`, `ON DELETE RESTRICT`** (identidad, misma
  postura de accountability que `counseling_cases.opened_by`) — jamás una asociación a un modelo de
  `counseling`. El modelo `AnalyticsBi::CareAura` **no declara NINGUNA asociación a
  `Case`/`SessionNote`/`Referral`** (probado a nivel de modelo).
- **Concurrencia (§5.7 lo dejó abierto): un estudiante PUEDE tener varias auras activas de kinds
  DISTINTOS** (puede necesitar `extra_time` Y `quiet_space` a la vez), pero **nunca dos activas del
  MISMO kind** — hecho cumplir con un índice único PARCIAL `(institution, student, aura_kind) WHERE
  effective_until IS NULL` (molde de `extracurriculars` v1.27.0), no un `EXCLUDE gist` (§5.7 dice
  saltárselo salvo invariante real; el índice parcial basta y es más simple).
- **Escritura append-only** vía `AnalyticsBi::Aura::Projector` (invocado desde
  `Counseling::CareAurasController`, gate `counseling.write` — el key existente, sin inventar uno
  nuevo): republicar un kind cierra la activa (`effective_until = Date.current`) y abre la nueva
  (mismo molde adyacente `[)` que `SeatAssigner`); `Projector.retire` cierra una activa. La lectura del
  docente pasa por `AnalyticsBi::Lens::AuraScope`, que devuelve un `Data` de 4 campos
  (`kind`/`guidance`/`effective_from`/`effective_until`) — allowlist por construcción, jamás el AR
  model con asociaciones navegables. La lectura del orientador pasa por
  `AnalyticsBi::Aura::CounselorScope` (counseling nunca toca `AnalyticsBi::CareAura` directo).

---

## 6. Guardrails de confidencialidad y desempeño (REQ3)

### 6.1 Bypass de RLS seguro — cross-tenant vs. las 5 lentes

**Las 5 lentes son TENANT-SCOPED.** Corren bajo el rol `edu_app_runtime` (sin `BYPASSRLS`), con el
GUC de la institución activa, exactamente como cualquier otra vista del inquilino. **Nunca** tocan
`edu_bi_reader`. Un docente/orientador/directivo ve solo su propia institución, por RLS + scope RBAC.

**La consolidación cross-tenant** (comparar/agregar entre instituciones, dashboards de plataforma) es
la **otra mitad** de `analytics_bi` — `CrossTenantReportRoster`, hoy en stub, diferida a su propio
slice por el guardrail v1.34.0. Cuando se construya:

1. Corre bajo el rol Postgres **`edu_bi_reader`** (único `BYPASSRLS`, auditado). Es la primera vez que
   la app conecta a un rol distinto para una query real → checkpoint de diseño dedicado (cómo se
   cambia de conexión, cómo se audita cada acceso).
2. **Doble filtro a nivel de aplicación**: aunque `BYPASSRLS` permita ver todo, **cada query object
   cross-tenant DEBE incluir el predicado `institution_id` explícito** (o el conjunto de instituciones
   autorizado) en el `WHERE` de Rails — el bypass es para *eficiencia de agregación*, nunca licencia
   para mezclar filas. La disciplina "el scoping primario es explícito en la app, RLS es el backstop"
   (`PROJECT_STATE.md §3.1`) se **invierte** aquí: sin backstop de RLS, el filtro de app es la *única*
   defensa, así que es obligatorio y se testea con un caso cross-tenant dedicado.
3. **Solo agregados, nunca PII fila-a-fila cross-tenant.** La consolidación devuelve conteos/promedios
   por institución, jamás el registro de un menor de otra institución.
4. **Auditoría por acceso**: cada consulta cross-tenant loguea `cross_tenant_report_accessed` en
   `audit_events` (actor, alcance, timestamp).
5. Gateado por `cross_tenant_reports.view` (reservado a `bi_auditor`) — nunca un rol de institución.

### 6.2 Aislamiento clínico (resumen operativo)

- T3 vive en `counseling`, cifrado, en tablas propias.
- `analytics_bi` **jamás** referencia columnas T3 — solo la proyección `care_auras` (sin PII clínica).
- Serializadores: allowlist explícita de atributos; prohibido `to_json`/`as_json` crudo sobre modelos
  con dato T3.
- Logs: `config.filter_parameters` cubre los nombres de columnas clínicas; los service objects clínicos
  no logean payloads.
- Ninguna query "casual" de Rails (consola, rake, dashboard) alcanza T3 sin pasar por el permiso
  `counseling.*`.

---

## 7. Estrategia de procesamiento (respuesta a #5 del PO)

**Objetivo del PO:** rápido, poco mantenimiento, entorno más simple, recursos optimizados. **Regla:
in-memory por defecto; tablas-snapshot cuando pese; nunca vistas materializadas.** Escalera de
escalamiento (subir un peldaño solo ante bottleneck real medido):

1. **Cómputo en memoria (service object Ruby sobre queries AR indexadas)** — DEFAULT. Es lo que ya
   hacen `InstitutionDashboard`, `ReportCards::Computation`, `Calendar::Timeline`. Cero infra, testeable,
   greppable. La mayoría de las lentes "del ahora" viven aquí.
2. **Tabla-snapshot tenant-scoped, poblada por un job de Solid Queue** — cuando el agregado es caro
   **y** histórico (no necesita ser vivo). Molde exacto de `report_cards.lines_snapshot` /
   `student_headcount_snapshots`: una tabla normal con `institution_id` + RLS FORCE, un `*Job` que la
   escribe bajo GUC (via `*AllJob` fan-out si es per-institución, guardrail v1.32.0). **Es el corazón
   del análisis año-a-año**: `hps_term_snapshots` congela el estado del HPS por
   `(student, academic_term)`; las tendencias se leen de ahí, no se recomputan desde el crudo.
3. **Vistas SQL planas (no materializadas)** — solo si la lógica es intensamente set-based y estable.
   Respetan el RLS del rol que consulta (corren bajo el invocador). Sin job de refresh. Uso raro.
4. **Vistas materializadas — EVITAR.** El `REFRESH` corre como owner → riesgo real de fuga cross-tenant
   con RLS; además agregan un job de refresh que mantener. Solo bajo decisión explícita del PO, con
   checkpoint de seguridad propio.

**Regla mental:** *vivo para el "ahora", snapshot para el "a lo largo del tiempo"* — exactamente lo que
`InstitutionDashboard` ya aplica (`enrollment_trend` lee snapshots; el resto computa vivo). Esto
mantiene el entorno tan simple como hoy (Solid Queue ya existe; cero servicio nuevo).

---

## 8. Estructura de clases y directorios (Zeitwerk colapsado)

Recordatorio: Zeitwerk colapsa `app/domains/analytics_bi/{models,queries,services,jobs,policies}`, así
que `app/domains/analytics_bi/services/lens/spatial_classroom.rb` → **`AnalyticsBi::Lens::SpatialClassroom`**
(no `AnalyticsBi::Services::Lens::…`). Verificar con `bin/rails zeitwerk:check`.

```
app/domains/analytics_bi/
  models/                       # dato PRIMARIO que este dominio posee (T2)
    character_framework.rb      -> AnalyticsBi::CharacterFramework
    character_dimension.rb
    character_level.rb
    character_evaluation.rb
    character_dimension_score.rb
    peer_appreciation_tag.rb
    peer_appreciation.rb
    affinity_taxonomy.rb
    student_affinity.rb
    guardian_relationship.rb
    household.rb
    care_aura.rb                # proyección T3->docente (sin PII clínica)
    classroom_layout.rb         # (o en group_management — decisión de frontera §5.3)
    seat_assignment.rb
    student_placement.rb        # (o en group_management — decisión de frontera §5.2)
    hps_term_snapshot.rb        # snapshot histórico (§7)
  queries/                      # objetos de lectura con filtro de inquilino EXPLÍCITO
    lens/
      spatial_classroom_scope.rb   -> AnalyticsBi::Lens::SpatialClassroomScope
      constellation_scope.rb
      family_core_scope.rb
    character_evaluation_scope.rb
    cross_tenant_report_roster.rb  # el diferido (edu_bi_reader) — doble filtro app-level
  services/                     # cómputo/orquestación (.call), read-models en memoria
    institution_dashboard.rb    # YA EXISTE (v1.34.0)
    lens/
      spatial_heatmap.rb        # deriva heat HSL desde T1 (notas/asistencia)
      character_card.rb         # arma el radar/brújula/medallas de la Lente 2
      constellation_builder.rb
      family_graph.rb
      sibling_bond_alert.rb     # read-model de la alerta de lazos fraternales
    character/
      publisher.rb              # publica evaluación + congela snapshot (molde rubric)
      peer_appreciation_recorder.rb  # registra aporte con resguardos + consentimiento
      moderation.rb
    aura/
      projector.rb              # invocado DESDE counseling; escribe care_auras (sin PII clínica)
  jobs/
    hps_term_snapshot_job.rb    # per-institución
    hps_term_snapshot_all_job.rb# fan-out (guardrail v1.32.0)
  helpers/  (o app/components)  # SVG server-rendered (ver §10)
    svg/
      radar_chart.rb            -> AnalyticsBi::Svg::RadarChart
      sparkline.rb
      orbital_diagram.rb
      seat_grid.rb

app/controllers/analytics_bi/
  institution_dashboard_controller.rb   # YA EXISTE
  spatial_classrooms_controller.rb      # Lente 1 (supervisión)
  constellations_controller.rb          # Lente 3 (supervisión)
  family_cores_controller.rb            # Lente 4 (supervisión)
  character_evaluations_controller.rb   # T2 escritura (supervisión, hps.character.author)
  cross_tenant_reports_controller.rb    # diferido (bi_auditor)
# Lente 2 (ficha) NO va aquí: cuelga de app/controllers/portals/ (autoservicio)
app/controllers/portals/
  guardian_character_card_controller.rb # Lente 2 — relación-gated, sin authorize!, fuera del Registry

app/views/analytics_bi/...
config/entitlements/analytics_bi.rb     # addon-gate propio
config/navigation/analytics_bi.rb       # auto-registro de nav (solo entradas de supervisión)
```

---

## 9. Flujo de un Query Object de BI (patrón técnico)

**Tenant-scoped (las 5 lentes) — el 95% de los casos:**

```
Controller (authorize! si es supervisión / GuardianScope si es autoservicio)
   -> Query object (AnalyticsBi::Lens::*Scope): relation real + institution_id EXPLÍCITO
                                                 + per-row can?(permiso, fila) donde aplique (molde #4)
   -> Service / read-model (AnalyticsBi::Lens::*): computa en memoria (o lee hps_term_snapshot)
   -> SVG helper/component (AnalyticsBi::Svg::*): escupe SVG inline
   -> Vista: interpola variables CSS HSL server-side; Stimulus para interacción sin round-trip
```

- Corre bajo `edu_app_runtime` + GUC normal. RLS es el backstop; el filtro de app es el scoping
  primario (disciplina de la casa).
- **Cero dato sensible al cliente**: el servidor entrega el SVG/agregado ya renderizado o los datos
  mínimos no-sensibles que la interacción cliente necesita (§10.3).

**Cross-tenant (el slice diferido) — patrón distinto:**

```
Controller (authorize! cross_tenant_reports.view — solo bi_auditor)
   -> AnalyticsBi::CrossTenantReportRoster: conecta al rol edu_bi_reader (BYPASSRLS)
        * incluye SIEMPRE el predicado institution_id/IN(...) explícito (única defensa, §6.1)
        * devuelve SOLO agregados por institución, nunca PII fila-a-fila
        * loguea cross_tenant_report_accessed en audit_events
   -> read-model de consolidación -> vista de plataforma
```

---

## 10. Guía de interacción UX/UI

Hereda `UX_UI.md` (tokens, suavidad, AA, ícono+etiqueta, un verbo por pantalla, móvil primero en
superficies de acudiente). Especificidades del HPS:

### 10.1 SVG server-rendered por defecto

Radar, sparklines, brújula, seat-grid y el estado *estático* de la constelación/órbita se generan como
**SVG plano en el servidor** (helpers/components `AnalyticsBi::Svg::*`) y se sirven inline — máxima
rapidez en dispositivos de bajos recursos, cero dependencia de cliente para *ver* el dato.

### 10.2 Dimming y capas de calor (HSL interpolado server-side)

- El **heat** se deriva en el servidor de dato T1 (notas/asistencia): el service object calcula un
  valor normalizado 0..1 por estudiante y lo mapea a un **gradiente HSL** interpolado *server-side*,
  emitido como **variable CSS** por elemento (`style="--heat: hsl(...)"`). La vista solo consume la
  variable; no recalcula nada en cliente.
- El ***dimming*** (atenuar estables, resaltar necesitados) es una clase CSS que baja opacidad/
  saturación; se activa por el filtro (§10.4). Nunca codifica significado *solo* por color (regla AA de
  `UX_UI.md §7`): siempre acompañado de ícono + etiqueta (aguja/gauge sobre el avatar).

### 10.3 Cuándo se permite librería JS (relajación acotada — decisión #3 del PO)

- **Default:** SVG server-rendered + Stimulus para comportamiento. Se agota esto primero.
- **Permitido:** librerías JS **populares y mantenidas**, vía **importmap sin build** (pin a un ESM de
  CDN), **solo** para viz genuinamente interactiva que el SVG estático no cubre bien — grafo de
  fuerza de la **constelación** (Lente 3) y el **grafo orbital** familiar (Lente 4) con
  arrastre/zoom/expansión.
- **Reglas duras:** (1) **cero dato sensible cruza al cliente** — el servidor entrega solo nodos/aristas
  ya anonimizados/agregados y las etiquetas que el observador tiene permiso de ver; (2) sin build/Node
  (importmap only); (3) **cualquier librería que no sea claramente popular y mantenida → se pregunta al
  PO** antes de pinnearla; (4) la librería es *progressive enhancement*: si el JS no carga, se ve el
  SVG server-rendered de respaldo.

### 10.4 Filtros interactivos sin peticiones HTTP (Stimulus)

- El servidor entrega **todos** los avatares/nodos del scope con sus atributos no-sensibles como data
  attributes (`data-heat`, `data-affinity-ids`, `data-needs-attention`). Un **controlador Stimulus**
  aplica/quita las clases de `dimming`/heat en el cliente al mover un filtro (por talento, por señal),
  **sin round-trip** — la data ya está en el DOM, el filtro solo alterna visibilidad/énfasis.
- Nada de estado de UI en `localStorage` como sustituto de servidor (regla `UX_UI.md §6`): lo que deba
  sobrevivir va en params/sesión/DB.

---

## 11. Segmentación en slices progresivos (recon-first)

Orden por **menor tensión primero** (decisión #4 del PO): lo que ya tiene dato y cierra huecos
declarados antes que lo que exige modelado net-new + carve-out sensible. Cada slice: recon-first,
checkpoint de diseño para los net-new (como CHECKPOINT E), caso de aceptación de seguridad, y cierre
con entrada en `HISTORIA.md` + actualización de `OPEN_PROCESS.md`.

| Slice | Nombre | Dato | Tensión | Depende de |
|---|---|---|---|---|
| **0** | `InstitutionDashboard` tenant-scoped | ✅ existe | — | **✅ HECHO (v1.34.0)** |
| **1** | Cross-tenant `CrossTenantReportRoster` (`edu_bi_reader`) | ✅ existe | media (rol nuevo) | **✅ HECHO (v1.35.0)** |
| **2** | Lente 1 — superficie del mapa espacial (geometría + heat sobre T1) | geometría net-new; heat existe | media | **✅ HECHO (v1.36.0)** — §5.3 |
| **3** | Lente 5 — auras de cuidado (proyección sobre `counseling`) | ✅ base clínica existe | media (carve-out) | **✅ HECHO (v1.37.0)** — §5.7 |
| **4** | Temporalidad año-a-año (`student_placements` + `hps_term_snapshots`) | net-new transversal | media | **✅ HECHO (v1.38.0)** — §5.2 / A1 resuelta a favor de `group_management` |
| **5** | Instrumento de carácter (T2, molde rúbrica) | net-new + sensible | alta (NNA) | **✅ HECHO (v1.39.0)** — §5.4, consentimiento |
| **6** | Lente 2 — ficha de personaje (portal, autoservicio) | usa slice 5 | alta (digna+NNA) | **✅ HECHO (v1.40.0)** — Slices 4, 5 |
| **7** | Afinidades + Lente 3 constelación | net-new + lib JS | alta | **✅ HECHO (v1.42.0)** — §5.5, §10.3 |
| **8** | Núcleo familiar + Lente 4 (grafo orbital, tensión, lazos fraternales) | extiende `guardian_students` | alta | **✅ HECHO (v1.43.0)** — §5.6, §10.3 |

**Justificación del orden:**

- **Slice 1 primero** porque es el hueco que el propio proyecto declaró (guardrail v1.34.0) y **no
  requiere modelar nada nuevo** — solo la conexión al rol `edu_bi_reader` con su checkpoint. Cierra la
  segunda mitad de `analytics_bi` y establece el patrón cross-tenant seguro (REQ3) antes de que llegue
  dato más sensible.
- **Slices 2 y 3** son las lentes con más dato ya real (heat sobre notas/asistencia; auras sobre
  `counseling`). La Lente 1 da la *superficie visual* canónica del proyecto (`UX_UI.md §5`) y la Lente
  5 valida la frontera clínica **antes** de introducir el instrumento de carácter.
- **Slice 4** desbloquea toda tendencia intra-estudiante (no-negociable §1.1.3) — es prerequisito de
  las fichas y la constelación temporal.
- **Slices 5–8** son el corazón formativo (T2), los de mayor tensión NNA — se construyen al final,
  cada uno con checkpoint de consentimiento/anti-acoso, sobre una base ya probada.

Cada slice net-new abre con el **triage A/B/C/S** (`CONCEPTOS_TECNICOS.md §4`): confirmar con
`grep create_table` qué existe antes de cablear; los sensibles (5, 6, 8 y la Lente 5) llevan caso de
aceptación de seguridad a nivel de MODELO, no solo HTTP.

---

## 12. Invariantes heredados (checklist por slice)

Antes de dar por cerrado cualquier slice de este dominio:

- [ ] `institution_id` + `enable_rls` (ENABLE + FORCE) + índice líder `institution_id` en toda tabla nueva.
- [ ] `uuidv7()` como PK; dinero (si hubiera) en `*_cents bigint`.
- [ ] Sin `default_scope`; Query object con filtro de inquilino explícito.
- [ ] `authorize!` al inicio de cada acción de supervisión; `can?` solo cosmético.
- [ ] Autoservicio (Lente 2) por `GuardianScope`/`StudentSelfScope`, sin `authorize!`, fuera del Registry.
- [ ] Entitlement del addon `analytics_bi` antes de RBAC (gate #1 antes de gate #2).
- [ ] Permisos nuevos en `SeedPermissions::CATALOG`; ninguno `hps.*` es cross-tenant.
- [ ] `bin/rails zeitwerk:check` verde; constantes colapsadas correctas.
- [ ] Migrar dev **y** test (`RAILS_ENV=test bin/migrate`); suite en serie (`PARALLEL_WORKERS=1`).
- [ ] KPI de solo lectura **no** reusa servicio con side-effect (v1.34.0); ausencia de dato = `nil`/"—".
- [ ] Dato T3 nunca fuera de `counseling` salvo `care_aura` (sin PII clínica); serializadores allowlist; logs filtrados.
- [ ] Cross-tenant (si aplica): doble filtro app-level + solo agregados + auditoría por acceso.
- [ ] Slices sensibles: consentimiento del acudiente + resguardos anti-acoso + caso de aceptación de seguridad a nivel de modelo.
- [ ] Cierre: entrada en `HISTORIA.md` + actualización de `OPEN_PROCESS.md` + este documento.

---

## 13. Decisiones abiertas (a confirmar con el PO en el checkpoint de cada slice)

| # | Decisión | Lean propuesto |
|---|---|---|
| **A1** | ¿`student_placements` (§5.2) lo escribe `analytics_bi` o `group_management`? | **✅ RESUELTO (v1.38.0): `group_management`** (dueño de `students`/`sections` — modelo `GroupManagement::StudentPlacement`, escritura vía `GroupManagement::SectionReassigner`, el único seam que mueve un estudiante de sección); `analytics_bi` solo lee (`AnalyticsBi::PlacementScope`). |
| **A2** | ¿`classroom_layouts`/`seat_assignments` (§5.3) viven en `analytics_bi` o `group_management`? | **✅ RESUELTO (v1.36.0): `group_management`** (dato del aula física — modelos `GroupManagement::ClassroomLayout`/`SeatAssignment`, escritura vía `ClassroomReconfigurer`/`SeatAssigner` gateada por `groups.manage`); `analytics_bi` solo lee (`AnalyticsBi::Lens::SpatialClassroomScope`) para la Lente 1. |
| **A3** | Umbral N de agregación para tags de pares (§5.4) | **✅ RESUELTO (v1.39.0): N = 3**, como constante de módulo (`AnalyticsBi::Character::PeerAppreciationRecorder::AGGREGATION_THRESHOLD`), **NO configurable por institución todavía** — no existe ningún mecanismo de settings-por-institución en el codebase, e inventar una tabla genérica para un solo número es especulativo (deferido hasta que una institución real lo pida). |
| **A4** | ¿`analytics_bi` se vuelve dominio medido (`Usage::Ingest.emit`)? | No por ahora (`metered:false`); sin evento facturable claro. |
| **A5** | Set inicial de `character_frameworks` y `peer_appreciation_tags` | **✅ RESUELTO (v1.39.0): sembrado un set STARTER** (`bin/rails bi:seed_character_starter`) usando el contenido que este mismo §5.4 ya sugiere (dimensiones Lógica/Creatividad/Empatía/Convivencia/Perseverancia; tags Buen compañero/Creativo-a/Ayuda a los demás/Perseverante/Curioso-a) — **NO** es la curación pedagógica real que esta decisión pedía; es el placeholder "aburrido" que reemplaza una UI de autoría de frameworks, deferida hasta una necesidad real de curación. |
| **A6** | ¿La "tensión del vínculo" y la "alerta de lazos fraternales" (§5.6) se persisten como snapshot o se computan vivas? | **✅ RESUELTO (v1.43.0): vivas**, exactamente el lean propuesto — `AnalyticsBi::Lens::BondTension`/`SiblingBondAlert` computan en memoria en cada request, sin persistir nada; snapshot por término queda como escalón futuro si algún día pesa (§7). |
| **A7** | Fechado de `character_evaluations`/`care_auras`: ¿se acopla a `academic_terms` o calendario independiente? | **✅ RESUELTO para ambos.** `care_auras` (v1.37.0): acoplado a `academic_terms` (`care_auras.academic_term_id` FK NOT NULL; el `Projector` toma `Core::AcademicTerm.active`). **`character_evaluations` (v1.39.0): también acoplado a `academic_terms`** (mismo criterio — `academic_term_id` FK NOT NULL, parte de la unicidad `(student, term, framework, author)`; el controller resuelve `Core::AcademicTerm.active`). |

---

## 14. Changelog

### v0.9.0 — 2026-07-21 — Slice 8 cerrado: Lente 4 "Núcleo Familiar" — LAS 8 LENTES DEL ROADMAP ORIGINAL, CERRADAS

- **Último slice del roadmap de 8 que este documento fijó en v0.1.0.** Extiende — nunca duplica — el
  `guardian_students` ya existente con la metadata que el grafo orbital necesita: quién es el
  cuidador principal, la dimensión de custodia (sensible, §6.2) y la agrupación por hogar. También
  reusa (no introduce) la relajación acotada de librería JS del §10.3 por segunda vez.

- **`AnalyticsBi::Household`/`AnalyticsBi::GuardianRelationship`** (§5.6), net-new, tenant-scoped (RLS
  `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`). `guardian_relationships` es una
  extensión 1:1 de `core.guardian_students` (índice único por `guardian_student_id`) —
  `student_id`/`guardian_user_id`/`relationship` siguen viviendo SOLO en `core`, nunca duplicados
  aquí. `relationship_kind`/`custody_kind`/`households.kind` son `string`+CHECK — desviación
  documentada del `smallint` del boceto, mismo molde que todos los slices anteriores.
  `custody_kind` es NULLABLE y solo se puebla cuando hay algo real que registrar (§6.2 — nunca
  especulativo).

- **Segregación de `custody_kind` por CONSTRUCCIÓN, no por convención (§6.2).** Es una columna
  plana (T2, no necesita la postura de columnas cifradas de `counseling`/T3), pero
  `AnalyticsBi::Lens::FamilyGraph` — el ÚNICO camino de lectura que un orientador/directivo consulta
  para ver el grafo — **nunca la incluye en su payload**, ni en los `Data` internos ni en
  `cytoscape_elements`. Probado con una aserción estructural sobre el JSON serializado del grafo
  (`assert_no_match(/custody/i, payload)`), no solo revisión de código — mismo rigor que el
  aislamiento clínico de la Lente 5 y la prueba "sin buscador de personas" de la Lente 3.

- **Detección de hermanos: una QUERY, cero tabla nueva** (§5.6, exactamente como el documento lo
  anticipaba). `AnalyticsBi::Lens::FamilyCoreScope#siblings_for` matchea el lenguaje del documento
  al pie de la letra: dos estudiantes comparten hermandad cuando comparten el mismo cuidador
  marcado como **PRIMARIO** (`is_primary_caregiver: true`) — un cuidador compartido sin ese marcaje
  todavía produce CERO hermanos detectados (estado vacío honesto, nunca una suposición) hasta que
  la metadata real se registre.

- **`AnalyticsBi::Lens::BondTension` — decisión A6 resuelta exactamente como el lean propuesto:
  "tensión del vínculo" computada VIVA, nunca persistida.** Reusa señales T1 REALES ya existentes:
  último login (`Core::Session.created_at`) + última lectura de mensaje
  (`Communication::ConversationParticipant.last_read_at`) — bucketeadas en recencia (`<=7 días` =
  1.0, `<=30` = 0.6, `<=90` = 0.3, más antiguo/nunca = 0.0), nunca una curva de decaimiento continua
  ("aburrido sobre ingenioso"). `engagement` = media de las señales DISPONIBLES (nil sin ninguna,
  nunca un cero engañoso — mismo molde `wellbeing`/`heat` de `SpatialHeatmap`/`Hps::Snapshotter`);
  `tension = 1 - engagement`. **"Apertura del portal" y "acuse de consentimientos"** (también
  mencionadas en §5.6) se excluyeron honestamente — no existe ninguna tabla de seguimiento de visitas
  al portal ni de acuses de consentimiento general en el codebase (grep-confirmado), documentado como
  hueco real, no simulado. La etiqueta visible es SIEMPRE cualitativa
  ("Comprometido"/"Seguimiento moderado"/"Necesita seguimiento"/"Sin datos suficientes") — el float
  interno nunca se renderiza, mismo principio ordinal-nunca-visible que `CharacterCard` fijó en
  v1.40.0.

- **`AnalyticsBi::Lens::SiblingBondAlert` — señal de intervención, nunca un veredicto (§5.6).**
  Read-model puro, computado en cada request (§7/A6). Heurística documentada como PLACEHOLDER (sin
  umbral de negocio confirmado por el owner todavía — misma postura de decisión abierta que
  `alertas tempranas` en `guidelines/CLOSURE_PLAN.md`): un estudiante "declina" cuando AMBAS ventanas
  (reciente de 14 días vs. base de los 30 días previos) tienen dato Y la reciente es
  ≥20 puntos porcentuales peor en asistencia O ≥1.0 punto peor en nota promedio (escala 5.0).
  Una alerta dispara cuando **≥2 hermanos** del mismo cuidador primario declinan a la vez. La
  ausencia de dato NUNCA cuenta como declive (un estudiante sin registros en alguna ventana
  simplemente no puede evaluarse, nunca se asume en caída). **Auditada** (`family_core.sibling_alert_viewed`,
  nuevo en `IdentityAccess::AuditEventIndex::ACTIONS`) — pero SOLO cuando el controller realmente
  tiene una alerta que mostrar, nunca en cada vista simple del grafo (ruido proporcional a la
  exposición real de la señal, mismo criterio que `cross_tenant_report_accessed`).

- **Cytoscape.js REUSADO, no una segunda librería.** El grafo orbital usa el MISMO Cytoscape.js
  pinneado en el Slice 7 — `family_graph_controller.js` replica el molde exacto de progressive
  enhancement del controlador de la constelación (`import` dinámico envuelto en `try/catch`, fallback
  server-renderizado siempre real) con su propio estilo de nodos (estudiante-centro/cuidador/hermano).
  Cero librería nueva, cero vendor nuevo — la relajación de §10.3 se ejerce una vez por
  slice-que-la-necesita, no una vez por librería-que-se-nos-ocurra.

- **Permiso nuevo: `hps.family.view` — institución-wide SOLAMENTE (§4), sin lector de scope más
  pequeño** (a diferencia de `hps.constellation.view`, que sí soporta `department_id`) — una familia
  cruza secciones/grados por definición, así que no existe una forma honesta de acotarla a un scope
  menor. **Sin entrada nueva en `Navigation::Registry`** — mismo criterio que la autoría de auras en
  la Lente 5 (v1.37.0): el punto de entrada es un enlace `can?`-gateado desde una superficie
  per-estudiante YA EXISTENTE (`group_management/students#show`, pestaña "Núcleo familiar"), nunca un
  ítem de navegación de nivel superior — evita que esta lente se convierta en un índice/directorio de
  estudiantes (que rozaría el no-negociable §1.1.6).

- **Sin superficie de autoría de `guardian_relationships`/`households` este slice** (deferido,
  documentado) — alcanzable por consola/rake por ahora, misma postura que la autoría de
  `character_frameworks` en el Slice 5.

- **Tests (18 nuevos, suite completa 722→740 runs / 0 fallos / 1 skip preexistente, en serie
  `PARALLEL_WORKERS=1`):** el CHECK de `relationship_kind` a nivel de BD; unicidad 1:1 de
  `guardian_relationships`; detección de hermanos exigiendo cuidador marcado PRIMARIO (nunca
  cualquier cuidador compartido) + el estado vacío honesto sin esa metadata; ensamblado del grafo
  (estudiante-centro + cuidadores + hermanos + aristas) con la prueba estructural de que
  `custody_kind` nunca aparece en el payload serializado; grafo vacío honesto sin datos
  (`family_graph_test.rb`). `BondTension`: nil sin señales, bucket de recencia con login reciente
  vs. antiguo, media de señales disponibles (`bond_tension_test.rb`). `SiblingBondAlert`: dispara
  con ≥2 hermanos declinando a la vez, NO dispara con solo uno, NO dispara sin datos (ausencia ≠
  declive), un hijo único nunca aparece en ningún grupo de alerta (`sibling_bond_alert_test.rb`).
  Caso de aceptación HTTP: 403 sin `hps.family.view`, 200 con el permiso Y `custody_kind` ausente de
  la respuesta completa, 404 cross-tenant/id desconocido, y CERO evento de auditoría en una vista sin
  alerta real que mostrar (`analytics_bi_family_core_test.rb`).

- **Nota operativa de esta sesión**: por decisión explícita del owner (tras el corte de gasto que
  interrumpió al agente del Slice 7), este slice se construyó ENTERAMENTE de forma directa, sin
  delegar a un agente nuevo — mismo nivel de rigor de recon-first, smoke tests manuales antes de los
  tests formales, y verificación de suite completa que los slices delegados anteriores.

- Ver `HISTORIA.md` v1.43.0 para la narrativa completa del slice.

### v0.8.0 — 2026-07-21 — Slice 7 cerrado: Lente 3 "Constelación de Afinidades"

- **Primera librería JS real del codebase** — la relajación acotada que §10.3 ya pre-aprobaba
  específicamente para esta lente y la Lente 4, ejercida por primera vez. Además, primer consumidor
  real del mecanismo `IdentityAccess::PermissionCheck#scope_for` (existía desde P1, sin ningún
  dominio adoptándolo — "adopción incremental por dominio").

- **`AnalyticsBi::AffinityTaxonomy`/`AnalyticsBi::StudentAffinity`** (§5.5), net-new, tenant-scoped
  (RLS `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`). Árbol curado auto-referencial
  (`parent_id`), `kind` (`sport`/`art`/`hobby`/`academic`, `string`+CHECK — desviación documentada
  del `smallint` del boceto, mismo molde `care_auras.aura_kind`/`character_evaluations.author_kind`).
  **`search_tsv` es una columna GENERADA nativa de PG18** (`GENERATED ALWAYS AS
  (to_tsvector('spanish', name)) STORED`, índice GIN) — sin trigger/callback, Postgres la mantiene
  sola. `student_affinities` (vínculo estudiante↔talento): `source`
  (`teacher_observed`/`guardian_reported`/`self_reported`) + `context`
  (`in_school`/`out_of_school`), ambos `string`+CHECK; único por `(institution, student, taxonomy,
  term)`.

- **Extensión de esquema más allá del boceto de §5.5 (documentada): `affinity_taxonomy` gana un
  `department_id` FK nullable.** El §4 hace de la Lente 3 una superficie de SUPERVISIÓN con scope
  "institución-wide O `department_id` (un especialista)" — pero ni el boceto del ERD ni `students`
  exponían una dimensión de departamento para que el lector de scope `:department` (YA existente en
  `Authorization::Assignment::SCOPE_READERS`) tuviera algo que cubrir. Etiquetar el árbol curado por
  departamento (el subárbol Deportes → el departamento Deportes) es la forma mínima y honesta de
  hacer el modelo de acceso del §4 REAL y testeable, reusando el lector `:department` exactamente
  como la Lente 1 reusó `:group`/`:grade_level` — **nunca un `scope_type` nuevo**. Un
  `department_id` NULL es un talento de nivel-institución, visible solo con un grant institución-wide.
  La constelación en sí sigue siendo "transversal al colegio" (§1.2): un especialista con scope de
  departamento ve a TODOS los estudiantes de todo el colegio que tengan un talento de su
  departamento, nunca solo los de su propia sección.

- **La búsqueda es SOLO de talento, nunca de persona (no-negociable §1.1.6).**
  `AnalyticsBi::Lens::TaxonomySearchScope` corre `websearch_to_tsquery('spanish', ...)` contra
  `search_tsv` — su SQL no tiene ningún join ni columna de `students`, probado con una aserción
  estructural sobre el SQL generado (no solo revisión de código). Una búsqueda vacía no matchea
  "todo", matchea nada.

- **`AnalyticsBi::Lens::ConstellationScope`** resuelve QUÉ nodos de talento puede ver el observador
  (institución-wide vs. su(s) departamento(s)) vía `context.scope_for("hps.constellation.view")` —
  filtra a nivel de índice (`idx_affinity_taxonomy_on_inst_department`) en vez de cargar cada fila y
  llamar `can?` una por una (ambos son equivalentes, documentado en el propio motor). Un observador
  con el permiso pero SIN ningún grant de departamento falla cerrado (relación vacía), nunca "ve
  todo por error".

- **`AnalyticsBi::Lens::ConstellationBuilder`** ensambla el grafo en memoria (§7 default): TODOS los
  nodos de talento autorizados + TODOS los estudiantes vinculados a ellos, como un `Graph` (`Data`)
  con nodos de talento, nodos de estudiante (**iniciales** como etiqueta de grafo — el nombre
  completo solo en el fallback accesible que el mismo observador ya autorizado lee, misma postura
  que `AnalyticsBi::Svg::SeatGrid`) y enlaces. **Nunca un ranking entre estudiantes** (no-negociable
  §1.1.3) — es un mapa de descubrimiento ("quién comparte este talento"), no una tabla de
  posiciones. Cero dato más allá de lo que el observador ya tiene permiso de ver cruza al cliente.

- **Cytoscape.js, pinneado vía `bin/importmap pin cytoscape` (resuelto y vendorizado de verdad,
  3.34.0, `vendor/javascript/cytoscape.js`)** — elegido sobre ensamblar D3 a mano
  (`d3-force`+`d3-drag`+`d3-zoom`) porque trae arrastre/zoom/expansión (§10.3 los pide
  explícitamente) listos para usar, con mucho menos JS propio que mantener ("aburrido sobre
  ingenioso"). **Progressive enhancement real**: `constellation_controller.js` intenta un `import`
  DINÁMICO de Cytoscape dentro de `connect()`, envuelto en `try/catch` — un pin roto o ausente
  simplemente deja visible el fallback server-renderizado (lista agrupada por talento), la página
  nunca se rompe. El servidor entrega TODO el scope autorizado una sola vez como datos ya en el DOM
  (`data-constellation-graph-value`, mismo molde §10.4 que la Lente 1); la búsqueda filtra/atenúa en
  el cliente sin round-trip, tanto en el grafo (dimming de nodos) como en el fallback plano (mismo
  input, dos caminos de filtrado según haya JS o no).

- **Autoría mínima: solo `teacher_observed`.** `AnalyticsBi::StudentAffinitiesController`
  (`new`/`create`, molde #4 supervisión, gate NUEVO `hps.affinity.author` — espejo exacto de
  `hps.character.author`, scope vía `StudentAffinity#group_id` delegado al estudiante, mismo truco
  que `character_evaluations`/`care_aura`). El punto de entrada es un estudiante ya supervisado
  (`student_id` en params), nunca un buscador de personas. **Deferido, documentado**: la UI de
  autoría `guardian_reported`/`self_reported` (portal) — un futuro slice, exactamente como la Lente 2
  fue deferida del Slice 5.

- **Permisos nuevos**: `hps.constellation.view` (ver el grafo, scope institución-wide o
  `department_id`) y `hps.affinity.author` (registrar afinidades observadas). Ambos normales
  per-institución (heredados por `institution_admin` vía bootstrap, NO cross-tenant). Entrada nueva
  en `Navigation::Registry` ("Constelación de afinidades") — esta lente SÍ es de supervisión, a
  diferencia de la Lente 2.

- **Taxonomía STARTER sembrada** (`bin/rails bi:seed_affinity_starter`, mismo posture que
  `bi:seed_character_starter` del Slice 5) — Deportes/Artes/Pasatiempos/Académico con algunos hijos
  de ejemplo; explícitamente NO curación pedagógica real, un placeholder hasta que exista una
  necesidad real de curación (misma decisión A5 aplicada aquí por analogía).

- **Tests (18 nuevos, suite completa 704→722 runs / 0 fallos / 1 skip preexistente, en serie
  `PARALLEL_WORKERS=1`):** el CHECK de `kind` a nivel de BD (bypaseando la validación de app);
  jerarquía padre/hijo; la búsqueda FTS acento-insensible + prueba estructural de que su SQL nunca
  toca `students`; una búsqueda vacía no matchea nada; un nodo inactivo queda fuera de la búsqueda
  por defecto; unicidad de `student_affinities` (AR y backstop de BD)
  (`affinity_taxonomy_test.rb`); resolución de scope institución-wide vs. departamento (incluyendo un
  talento de nivel-institución invisible para un especialista de departamento, y fail-closed sin
  ningún grant de departamento) + ensamblado del grafo (conteos correctos, iniciales-nunca-nombre-
  completo en el payload del cliente, grafo vacío honesto sin datos) (`constellation_test.rb`); caso
  de aceptación HTTP — persona por defecto sin `hps.constellation.view`/`hps.affinity.author` recibe
  403 en ambas superficies, un especialista de un departamento ve SOLO los talentos de su
  departamento (el otro departamento no aparece en absoluto), un titular de `hps.affinity.author`
  registra de verdad, y reenviar la misma afinidad es un no-op amable, nunca un 500
  (`analytics_bi_constellation_test.rb`).

- Ver `HISTORIA.md` v1.42.0 para la narrativa completa del slice.

### v0.7.0 — 2026-07-21 — Slice 6 cerrado: Lente 2 "Ficha de Personaje" (autoservicio)

- **La primera lente de AUTOSERVICIO del HPS** (§4): sin `authorize!`, sin permiso RBAC, fuera de
  `Navigation::Registry` — la compuerta es pura identidad (`GuardianScope`/`StudentSelfScope`), exactamente
  como `attendance`/`calendar` ya lo hacen en el portal. **Cero tablas nuevas**: este slice es un
  consumidor puro de la maquinaria del Slice 5 (v1.39.0) — tal como el propio documento lo predecía
  ("usa Slice 5").

- **`AnalyticsBi::Lens::CharacterCard`** (read-model, in-memory sobre AR indexado, filtro de inquilino
  explícito): ensambla cuatro piezas de UNA ficha por estudiante —
  - **Radar de fortalezas**: de la `CharacterEvaluation` PUBLICADA más reciente. Por cada dimensión del
    `framework_snapshot` congelado, resuelve el nivel elegido y su POSICIÓN ORDINAL dentro de los
    niveles de esa dimensión — **ese ordinal es SOLO un insumo geométrico** para
    `AnalyticsBi::Svg::RadarChart` y **nunca se muestra al usuario como número** (no-negociable
    §1.1.2/§1.1.4); todo campo visible/accesible es texto cualitativo (`level_label`/`descriptor`).
    Sin evaluación publicada → estado vacío real (`axes == []`, mensaje honesto), nunca un radar plano
    falso.
  - **Brújula de carácter**: "fortalezas más consolidadas" — las dimensiones en el nivel MÁS ALTO
    observado, listadas por nombre, puramente descriptivo, nunca un veredicto calculado.
  - **Medallas**: consume `AnalyticsBi::Character::PeerAppreciationDigest` (Slice 5) TAL CUAL — ya
    agregado-solamente, ya con umbral, ya jamás atribuible; este slice no construye un segundo camino
    de lectura.
  - **Crecimiento en el tiempo** (no-negociable §1.1.3, intra-estudiante, nunca ranking): una
    evaluación publicada por término, ordenada por el inicio calendario del propio término (mismo
    molde `HpsTermSnapshotScope#trend_for` del Slice 4 — nunca por `published_at`, para que
    re-publicar no reordene la historia). Es una narrativa de "cómo ha crecido este estudiante", no un
    gráfico de una sola nota mejorando.

- **`AnalyticsBi::Svg::RadarChart`** (§10.1, molde exacto `AnalyticsBi::Svg::SeatGrid`): SVG plano
  server-rendered, un eje por dimensión, la distancia del vértice la maneja el ordinal (geometría
  únicamente). **AA (nunca color/forma solo)**: cada etiqueta de eje es texto SVG real con el nombre
  de la dimensión + el nivel CUALITATIVO (nunca el ordinal), `role="img"` + `aria-label` descriptivo, y
  una tabla `visually-hidden` espeja cada eje (dimensión/nivel/descriptor) en texto plano. Sin
  `Sparkline` separado para el crecimiento — se renderiza como una lista/`<dl>` accesible por término;
  MVP honesto, un segundo tipo de gráfico no estaba ganado todavía (documentado como scope-down, no
  un olvido).

- **`AnalyticsBi::SectionClassmatesScope`** (query object nuevo): el roster CERRADO de compañeros de
  sección del estudiante, para el picker de "dar un reconocimiento" — lee el CACHÉ vivo
  `students.section_id` (quién comparte sección AHORA, una pregunta de presente), no
  `PlacementScope#students_in` (que es retrospectivo por término). Nunca un buscador de personas
  (no-negociable §1.1.6): el picker es un `<select>` cerrado de compañeros actuales, y el controller
  vuelve a resolver el destinatario/tag por lectura scopeada (`SectionClassmatesScope#for(...).find`,
  `PeerAppreciationTag.active.find_by!`) — un ID de compañero fuera de sección o un tag inactivo
  manipulado en el parámetro simplemente 404/falla limpio, nunca confía en el parámetro crudo.

- **Cuatro controllers de portal, todos self-service** (`Portals::GuardianCharacterCardController`,
  `Portals::StudentCharacterCardController`, `Portals::GuardianCharacterConsentsController`,
  `Portals::StudentPeerAppreciationsController`): la resolución `GuardianScope.for(...).find(...)`/
  `StudentSelfScope.for(...)` ES la compuerta — un hijo fuera de los vínculos activos del acudiente
  404 ("caso de María"), un estudiante da un reconocimiento solo con `PeerAppreciationRecorder`
  (Slice 5, sin tocar) rescatando `ConsentRequired`/`TagUnavailable` en un flash amable, nunca un 500
  (misma disciplina que `CharacterEvaluationsController` en el Slice 5).

- **UI de consentimiento del acudiente (deferida del Slice 5, §5.4 punto 5)**: un botón
  otorgar/revocar en la ficha del acudiente, llamando `CharacterProgramConsent.grant!`/`.revoke!`
  (Slice 5, idempotentes y append-only, sin tocar aquí) — sin llave de idempotencia en el botón (a
  diferencia del molde de `GuardianActivityEnrollmentsController`): el propio modelo ya es idempotente,
  así que pasar una clave que el modelo ignora habría sido imitar el molde sin necesitarlo.

- **Superficie de dar un aporte de par (deferida del Slice 5)**: `Portals::
  StudentPeerAppreciationsController#new`/`#create` — el estudiante elige un compañero de su sección
  actual (picker cerrado) y un tag del catálogo activo, y `PeerAppreciationRecorder` hace el resto
  (consentimiento, anti-duplicado, umbral — todo intacto del Slice 5). **Deferido, documentado**: la
  UI de dar-como-acudiente (`giver_kind: "guardian"`, un acudiente reconociendo a un estudiante que no
  es su hijo) — el modelo y el `Recorder` ya lo soportan y está probado a nivel de modelo desde el
  Slice 5, pero una UI real abre su propia pregunta de alcance/búsqueda-de-personas sin resolver (¿qué
  estudiantes ajenos puede ver un acudiente?) que este slice no resuelve — misma postura que el Slice 5
  ya tomó al deferir por completo el controller de autoría-acudiente.

- **Enlaces de hub cableados** (`app/views/portals/guardian_students/show.html.erb`,
  `app/views/portals/student_portal/show.html.erb`) — el hallazgo de v1.28.0 (una superficie de portal
  nueva que se olvida de enlazar desde el hub) **no se repitió** esta vez.

- **Gotcha real**: el comentario mágico de locals estrictos de Rails (`<%# locals: (card:) %>`) debe
  quedar SOLO en su propia línea — cualquier prosa después de `locals:` hasta el `%>` se interpreta
  como parte de la firma del método compilado, produciendo un `SyntaxErrorInTemplate` que Erubi crudo
  no habría detectado. Documentado para cualquier partial futuro con firma de locals + comentario.

- **Tests (21 nuevos, suite completa 679→700 runs / 0 fallos / 1 skip preexistente, en serie
  `PARALLEL_WORKERS=1`):** el read-model ensamblando las cuatro piezas + el estado vacío real +
  exclusión de borradores + el umbral (`character_card_test.rb`); estructura/AA/ausencia de número
  crudo del SVG (`radar_chart_test.rb`); caso de María en lectura Y escritura (un acudiente fuera de
  la relación 404 tanto en la ficha como en el consentimiento), el round-trip de consentimiento, el
  estado vacío, y una aserción explícita de que ningún número aparece donde debería ir un nivel
  cualitativo (`portals_character_card_test.rb`); el picker cerrado excluyendo a un compañero de otra
  sección y al propio dador, el camino feliz, el rechazo de un destinatario fuera de sección, y el gate
  de consentimiento (`portals_peer_appreciation_test.rb`).

- Ver `HISTORIA.md` v1.40.0 para la narrativa completa del slice.

### v0.6.0 — 2026-07-21 — Slice 5 cerrado: instrumento de carácter (T2) + aportes de pares/acudientes

- **La pieza de mayor tensión NNA construida hasta ahora (Clase S, junto con la Lente 5): el primer
  tier T2 formativo real, y el primer CONSENTIMIENTO del codebase.** Dos piezas independientes, nunca
  mezcladas — la evaluación de autoría staff (profesional, T2) y el aporte de pares/acudientes
  (identidad, con resguardos anti-acoso duros).

- **Instrumento staff-autoría, molde rúbrica exacto** (§5.4): `AnalyticsBi::CharacterFramework` (`name`/
  `description`/`status` draft·published·archived) → `AnalyticsBi::CharacterDimension` (`name`/
  `position`/`weight`) → `AnalyticsBi::CharacterLevel` (`label`/`descriptor` cualitativo — **nunca un
  número**, no-negociable §1.1.2) → `AnalyticsBi::CharacterEvaluation` (`framework_snapshot` jsonb
  **congelado al publicar**, molde exacto `assignments.rubric_snapshot`/`price_tiers_snapshot`; único
  índice `(institution, student, term, framework, author)` — un autor no evalúa dos veces al mismo
  estudiante en el mismo término con el mismo marco) → `AnalyticsBi::CharacterDimensionScore`
  (`dimension_key` texto que referencia el snapshot CONGELADO, NUNCA un FK vivo — mismo molde que las
  puntuaciones de rúbrica: editar/archivar un framework después de publicar nunca reescribe una
  evaluación ya publicada). `AnalyticsBi::Character::Publisher` congela y valida cada selección contra
  el snapshot (`InvalidSelection` si la dimensión/nivel no existía al momento de publicar).

- **Aportes de pares/acudientes — tabla SEPARADA, con los seis resguardos de §5.4 hechos cumplir por
  CONSTRUCCIÓN, no por convención:**
  1. **Sin texto libre, nunca**: `peer_appreciations` no tiene NINGUNA columna de texto — solo
     `tag_id` hacia `peer_appreciation_tags` (catálogo cerrado, curado, solo-constructivo). Es
     estructuralmente imposible escribir un insulto, no solo bloqueado a nivel de servicio.
  2. **Umbral de agregación antes de surfacear** (decisión A3 resuelta: N=3, constante de módulo, NO
     configurable por institución — no existe mecanismo de settings-por-institución en el codebase,
     inventar una tabla para un solo número es especulativo, deferido). `AnalyticsBi::Character::
     PeerAppreciationDigest` es el ÚNICO camino de lectura sancionado — agrega por tag, filtra por
     umbral, y **nunca expone `giver_student_id`/`giver_guardian_user_id`** (allowlist por
     construcción: el `Data.define(:tag_label, :category, :count)` de retorno no tiene ningún campo
     de atribución). Construido y probado ahora aunque nada lo renderiza todavía — el Slice 6/Lente 2
     lo consume.
  3. **Nunca atribuible fuera de `hps.character.moderate`**: las columnas de identidad del dador
     (`giver_student_id`/`giver_guardian_user_id`) existen SOLO para `AnalyticsBi::Character::
     Moderation` y el rastro de auditoría.
  4. **Solo fortalezas**: el catálogo `peer_appreciation_tags` es curado y constructivo por diseño
     (sembrado con el propio contenido de ejemplo de este §5.4 — ver A5 abajo).
  5. **Consentimiento del acudiente**: ver el primitivo nuevo, abajo.
  6. **Moderación append-only**: `AnalyticsBi::Character::Moderation.withhold!` es un flip de estado
     (`active` → `withheld_by_moderation`), **nunca** un `destroy`; cada withhold audita
     (`peer_appreciation.withheld`, nuevo en `IdentityAccess::AuditEventIndex::ACTIONS`). Idempotente:
     un segundo withhold sobre una fila ya retirada no vuelve a auditar.

- **XOR de identidad del dador** — `giver_kind` (`peer_student`/`guardian`, string+CHECK) más
  `num_nonnulls(giver_student_id, giver_guardian_user_id) = 1`, el mismo molde de
  `messages_sender_identity_check`/`conversation_participants_identity_check`. El acudiente-dador es
  un `Core::User` global (misma columna de identidad que `guardian_students.guardian_user_id`), NO un
  `institution_user` — un acudiente no es staff.

- **Anti-duplicado/anti-brigading REFORZADO más allá del boceto de §5.4**: DOS índices únicos
  parciales `WHERE status='active'` (uno por columna de dador), no uno solo — porque el CHECK XOR
  garantiza que exactamente una columna de dador es no-nula por fila, y una columna NULL es "distinta"
  dentro de un índice único de Postgres; un solo índice sobre `giver_student_id` habría dejado a
  cualquier acudiente repetir el mismo tag al mismo estudiante sin límite (todas sus filas comparten
  `giver_student_id: NULL`, que Postgres nunca considera "duplicado"). Desviación documentada,
  endurecimiento real encontrado durante la construcción, no un capricho de diseño.

- **`AnalyticsBi::CharacterProgramConsent` — el primer primitivo de consentimiento del codebase**
  (§5.4 punto 5). El doc apuntaba a un molde `assignments.requires_consent` que **no existe en ningún
  lugar del repo** (grep-confirmado) — una referencia obsoleta/aspiracional, la misma clase de
  corrección que ya hicieron los Slices 2 y 3 sobre otros moldes citados. Reemplazo: una tabla
  tenant-scoped, PROPIA de `analytics_bi` (deliberadamente NO un framework general de Habeas Data —
  ese alcance mayor no está pedido ni justificado todavía), append-only (`granted_at`/`revoked_at`,
  índice único parcial "una consent activa por estudiante" `WHERE revoked_at IS NULL`, molde
  `care_auras` de una-activa-a-la-vez). `AnalyticsBi::Character::PeerAppreciationRecorder` exige
  consentimiento activo del **estudiante que recibe** siempre, y del **par que da** si el dador es
  otro estudiante (un acudiente-dador es adulto, sin gate de consentimiento propio) — rechazo limpio
  (`ConsentRequired`), nunca un 500. **Alcance deliberadamente acotado**: esta pieza NO incluye la UI
  de otorgar/revocar consentimiento desde el portal del acudiente — el modelo + `grant!`/`revoke!` +
  el gate ya están completos y probados; la superficie de portal se construye en el Slice 6 (donde de
  todas formas se construye el resto del portal del acudiente para este dominio).

- **Permisos nuevos** (`SeedPermissions::CATALOG`): `hps.character.author` (docente/orientador
  crea/publica evaluaciones — SUPERVISIÓN, molde #4, `authorize!` al inicio de cada acción,
  scope-cubierto vía `CharacterEvaluation#group_id`/`grade_level_id` delegados al estudiante, mismo
  truco que `care_aura#group_id`) y `hps.character.moderate` (modera aportes — y es la ÚNICA llave que
  alguna vez ve atribución). El ACTO de dar un aporte de par/acudiente **no** usa `authorize!` — es una
  acción de identidad (co-pertenencia + consentimiento, §4), gateada enteramente por
  `PeerAppreciationRecorder`. Ambas llaves nuevas son per-institución normales (heredadas por
  `institution_admin` vía bootstrap, NO cross-tenant).

- **Superficie de autoría** (`AnalyticsBi::CharacterEvaluationsController`, `new`/`create` solamente):
  el punto de entrada es un estudiante ya supervisado (`student_id` en params), nunca un buscador de
  personas (no-negociable §1.1.6). **Deferido, documentado**: la UI de autoría de
  frameworks/dimensiones/niveles (CRUD) — en su lugar, `bin/rails bi:seed_character_starter` siembra
  un framework + catálogo de tags STARTER usando el contenido de ejemplo que este mismo §5.4 ya sugiere
  (dimensiones Lógica/Creatividad/Empatía/Convivencia/Perseverancia; tags Buen compañero/Creativo-a/
  Ayuda a los demás/Perseverante/Curioso-a) — **no** es la curación pedagógica real que pedía la
  decisión A5, es el placeholder aburrido que la reemplaza hasta que haya una necesidad real de
  curación. Ni la superficie de dar un aporte de par (portal) ni la ficha de la Lente 2 se construyen
  en este slice — ambas son Slice 6.

- **Decisiones A3/A5/A7 resueltas** (ver §13): umbral N=3 no-configurable-todavía; set starter
  sembrado (no curado pedagógicamente); `character_evaluations` acoplado a `academic_terms` (mismo
  criterio que `care_auras`).

- **Tests (22 nuevos, suite completa 657→679 runs / 0 fallos / 1 skip preexistente, en serie
  `PARALLEL_WORKERS=1`):** congelado del snapshot al publicar + inmutabilidad tras editar el framework
  + `InvalidSelection` + unicidad autor/estudiante/término/framework (AR y backstop de BD)
  (`character_evaluation_test.rb`); los seis resguardos anti-acoso (catálogo cerrado, XOR de dador —
  BD y AR, índice parcial anti-duplicado como backstop de BD, gate de consentimiento rechazando
  receptor-sin-consentimiento y par-dador-sin-consentimiento limpiamente, revocación corta
  participación futura, umbral de agregación + proyección jamás atribuible, moderación append-only +
  auditada + idempotente) (`peer_appreciation_test.rb`); caso de aceptación de seguridad HTTP (la
  persona por defecto sin `hps.character.author` recibe 403 en `new`/`create`, un titular publica de
  verdad a través del `Publisher`, el formulario renderiza) (`analytics_bi_character_evaluation_test.rb`).

- **Gotcha real encontrado** (para quien construya sobre esto): los dos índices únicos parciales por
  columna de dador (arriba) no estaban en el boceto original de §5.4 — se detectaron al razonar sobre
  qué hace un índice único de Postgres con NULLs (cada NULL es distinto), no al correr un test que
  fallara. Vale la pena re-chequear ese razonamiento en cualquier índice parcial futuro sobre una
  columna que puede ser NULL por una XOR.

- Ver `HISTORIA.md` v1.39.0 para la narrativa completa del slice.

### v0.5.0 — 2026-07-17 — Slice 4 cerrado: temporalidad año-a-año (`student_placements` + `hps_term_snapshots`)

- **Desbloquea toda tendencia intra-estudiante (no-negociable §1.1.3), prerequisito de las Lentes 2 y
  3 (§11).** El problema (§5.2): `students.section_id` es un puntero MUTABLE al grupo actual —
  reorganizar salones sobreescribe el pasado, y el BI no puede responder "¿cómo cambió el mapa de este
  estudiante de 2° a 8°?" sin una historia append-only.

- **Decisión A1 resuelta a favor de `group_management` (lean propuesto ejecutado sin cambios).**
  `GroupManagement::StudentPlacement` (`student_placements`), net-new, tenant-scoped (RLS
  `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`), efectivo-fechada
  (`valid_from`/`valid_until`, `NULL` = vigente). **`EXCLUDE USING gist`** (btree_gist, molde v1.33.0)
  por `(institution, student, daterange)` — un estudiante nunca tiene dos placements activos
  solapados; `analytics_bi` **solo lee** vía `AnalyticsBi::PlacementScope` (filtro de inquilino
  explícito, nunca `default_scope`), exactamente el mismo reparto de dueño que la geometría de aula de
  Slice 2 (A2).

- **Un solo seam de escritura: `GroupManagement::SectionReassigner`.** Mantiene DOS cosas en
  lock-step para que ningún call site tenga que saber de historia: (1) `students.section_id` — el
  CACHÉ vivo del placement actual (§5.2 lo deja así, muchos flujos ya lo leen); (2)
  `student_placements` — CIERRA el placement abierto (`valid_until = Date.current`) y ABRE uno nuevo,
  el mismo molde simétrico de `SeatAssigner`/`ClassroomReconfigurer` (v1.36.0) y
  `Subscription#end!`/`Entitlement#revoke!` (v1.33.0). **Desviación de redacción respecto a §5.2**
  (que esbozaba "ayer"): se cierra con `Date.current`, igual que Slice 2 — `[from, hoy)` y `[hoy, ∞)`
  son ADYACENTES bajo `daterange '[)'`, nunca solapan, y el constraint se satisface incluso
  reasignando el mismo día en que se abrió el placement. `requires_new: true` (SAVEPOINT) por la misma
  razón que `SeatAssigner`.
  - **`section: nil` desasigna**: cierra el placement abierto sin abrir uno nuevo (un estudiante sin
    sección no tiene placement activo); el caché se pone a `nil`.
  - **Idempotente por construcción**: reasignar al mismo section con un placement abierto que ya
    coincide es un no-op — reenviar el mismo roster nunca ensucia la historia (hallazgo real: el
    roster de `memberships_controller#update` se reenvía típicamente sin cambios).
  - **Auto-sanador**: si el caché ya apunta a la sección correcta pero falta el placement (un
    estudiante creado por importación de roster, o pre-backfill), el placement se abre igual — el
    seam no asume que el estado previo ya era consistente.
  - **Borde documentado**: si no hay `grade_level_id` resoluble (ni del estudiante ni de la sección) o
    no hay término activo, el caché igual se actualiza pero NO se escribe placement (las columnas NOT
    NULL no podrían satisfacerse de todas formas) — nunca una excepción a mitad de un flujo de
    matrícula.

- **`GroupManagement::PlacementBackfill`** (one-shot, idempotente, re-ejecutable): abre un placement
  por cada estudiante activo y con sección hoy, sobre `SectionReassigner` (reusa su auto-sanación, no
  duplica lógica). Batched con `find_each`; corre bajo el GUC del propio invocador (rake), sin job
  throttleado — el volumen por-tenant no lo justifica (documentado, revisar si un tenant crece).
  Expuesto en `bin/rails bi:backfill_placements[institution_id]` (`lib/tasks/bi.rake`).

- **`memberships_controller.rb` refactorizado**: los dos `update_all` de bulk (asignar/desasignar
  roster de un grupo) se reemplazan por `find_each` + `SectionReassigner.call` por estudiante — el
  ÚNICO write seam que mantiene caché e historia en lock-step. El roster de un homeroom es pequeño
  (~30-40), así que per-fila es aceptable; ningún call site vuelve a tocar `section_id` directo.

- **`AnalyticsBi::HpsTermSnapshot`** (`hps_term_snapshots`), net-new en `analytics_bi` (§7: "snapshot
  para el 'a lo largo del tiempo'"). Tenant-scoped, uno por `(student, academic_term)` (índice único
  `idx_hps_term_snapshots_one_per_student_term`, líder `institution_id`). `payload` jsonb —
  `attendance_rate`/`average_grade`/`grade_scale`/`wellbeing`/`heat`/`section_id`+`name`/
  `grade_level_id`+`name` — mismo molde `report_cards.lines_snapshot`: los campos derivados viven en
  jsonb para que los Slices 5–8 agreguen claves sin migración; el triple (institution, student, term)
  es lo único que se filtra o se une jamás.

- **`AnalyticsBi::Hps::Snapshotter`** (mismo molde `Core::Headcount::Snapshotter`): cómputo en memoria
  sobre AR indexado, `find_or_initialize_by` sobre el triple único (idempotente, nunca duplica).
  Señales TERM-scoped (no una ventana rodante de 30 días como el heat de Slice 2, a propósito — el
  punto de un snapshot histórico es congelar el término, no "los últimos 30 días" que cambian según
  cuándo se mire): nota promedio vía `enrollments.academic_term_id`, asistencia vía la ventana de
  calendario del término (`starts_on..min(ends_on, hoy)`, nunca cuenta días futuros de un término sin
  terminar), placement vigente para ese término leído de `student_placements` (nunca de
  `students.section_id`, que solo conoce el presente). `wellbeing`/`heat` siguen la convención de
  `SpatialHeatmap`: media de señales disponibles, `nil` sin ninguna — **nunca un 0 engañoso** (regla
  v1.34.0).

- **`HpsTermSnapshotJob`/`HpsTermSnapshotAllJob`** (fan-out, guardrail v1.32.0): el job por-institución
  resuelve el término activo si no se pasa uno explícito (permite snapshotear un término ya cerrado
  desde un futuro trigger de fin-de-término); sin término activo y ninguno explícito, no-op silencioso
  (temporada baja, nunca un error). **NO** está en `config/recurring.yml`: fin-de-término es un evento
  dependiente de dato, no un reloj fijo — se invoca manualmente
  (`bin/rails bi:snapshot_terms[institution_id]`) hasta que exista un disparador real de cierre de
  término (nota para Slices futuros / `OPEN_PROCESS.md`).

- **`AnalyticsBi::PlacementScope`/`AnalyticsBi::HpsTermSnapshotScope`**: los dos query objects de
  lectura de este slice, ambos con filtro de inquilino EXPLÍCITO, ninguno con `default_scope`. El
  primero da la historia completa (`history_for`) y el placement vigente por término
  (`for_term`/`students_in`); el segundo da la tendencia ordenada por el inicio calendario del término
  (`trend_for`, nunca por `captured_on` — re-snapshotear un término no debe reordenar su lugar en la
  serie histórica).

- **Tests (11 nuevos, suite completa 657 runs / 0 fallos / 1 skip preexistente, en serie
  `PARALLEL_WORKERS=1`):** el `EXCLUDE gist` a nivel de MODELO (dos placements solapados lanzan
  `StatementInvalid`); reasignar cierra-y-abre sin hueco ni solape; desasignar cierra sin abrir;
  reasignar al mismo destino es no-op idempotente; el backfill coloca exactamente un placement por
  estudiante activo-y-ubicado y es re-ejecutable sin duplicar (`student_placement_test.rb`); el
  snapshotter computa el payload correcto por estudiante incluyendo los casos sin nota/sin
  asistencia/sin ninguna señal (`nil`, nunca 0) y es idempotente por re-ejecución
  (`hps_term_snapshotter_test.rb`); el job fija el GUC del tenant correcto, resuelve el término activo,
  no filtra el GUC más allá de su propia transacción, y el fan-out encola un job por institución
  (`hps_term_snapshot_job_test.rb`). Sin caso de aceptación de seguridad HTTP dedicado — este slice no
  abre ninguna superficie de controller nueva (el único punto de entrada del usuario,
  `memberships_controller#update`, ya estaba gateado por `groups.manage` y sin cambios de superficie).

- Ver `HISTORIA.md` v1.38.0 para la narrativa completa del slice.

### v0.4.0 — 2026-07-17 — Slice 3 cerrado: Lente 5 "Auras de Cuidado" (proyección clínica → docente)

- **La pieza más sensible del dominio hasta ahora (Clase S, §11): valida la frontera clínica
  ANTES de introducir el instrumento de carácter (Slice 5).** El diagnóstico psicopedagógico vive y
  **se queda** en `counseling` (T3); lo único que cruza es una **proyección abstracta** (`care_auras`)
  que el orientador *decide publicar* como instrucción de trato, con cero PII clínica.

- **`AnalyticsBi::CareAura` (`care_auras`), tabla net-new de `analytics_bi`** (proyección, §5.7):
  tenant-scoped (RLS `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`), `student_id`/
  `academic_term_id` (A7: acoplada a términos) + `authored_by_counselor_id` (FK a `institution_users`,
  `ON DELETE RESTRICT` — identidad, nunca una asociación a `counseling`), `aura_kind` (`string` +
  CHECK, set cerrado — desviación documentada del `smallint` del ERD, molde `extracurriculars.kind`),
  `guidance_text`, `effective_from`/`effective_until`. **Índice único PARCIAL**
  `(institution, student, aura_kind) WHERE effective_until IS NULL` = "una activa por kind"; kinds
  distintos coexisten (decisión de concurrencia que §5.7 dejó abierta).

- **Un solo seam de escritura cross-dominio: `AnalyticsBi::Aura::Projector`**, invocado DESDE
  `counseling` (`Counseling::CareAurasController`, gate `counseling.write` — el key EXISTENTE, sin
  inventar uno nuevo). Append-only (molde `SeatAssigner`/`Subscription#end!`): republicar un kind
  cierra la activa (`effective_until = Date.current`, rangos adyacentes `[)`) y abre la nueva;
  `Projector.retire` cierra. `requires_new: true` (SAVEPOINT) por si dos publicaciones del mismo kind
  corren en carrera contra el índice parcial. **`analytics_bi` nunca lee tablas de `counseling`;
  `counseling` nunca toca `AnalyticsBi::CareAura` directo** — lee vía `AnalyticsBi::Aura::CounselorScope`.

- **Lado docente: `hps.aura.view` (permiso NUEVO, la SEGUNDA mitad del split de dos lados del §4;
  la primera es `counseling.*`).** El docente ve el aura como un ícono discreto («♥») superpuesto
  ADITIVAMENTE sobre la Lente 1 (Slice 2): `SpatialClassroomsController#show` decide `with_auras:
  can?("hps.aura.view", @section)` — con `hps.classroom.view` pero sin `hps.aura.view` ve el mapa de
  Slice 2 SIN CAMBIOS. La lectura pasa por `AnalyticsBi::Lens::AuraScope`, que devuelve un `Data` de
  4 campos (`kind`/`guidance`/`effective_from`/`effective_until`) — allowlist por construcción (§6.2),
  jamás el AR model con `:student` u otra asociación navegable. El `SeatGrid` SVG (Slice 2) ganó
  `aura_marker` (badge + `<title>` + `aria-label`, AA nunca color-solo) y una columna "Aura de
  cuidado" en su tabla `visually-hidden` (solo cuando hay auras — grid plano intacto sin ellas).

- **Aislamiento clínico probado a nivel de MODELO (no solo HTTP), como exige §11 para un slice
  sensible:** (1) un **SQL tap** sobre el camino de lectura del docente
  (`AnalyticsBi::Lens::SpatialClassroom.for(with_auras: true)`) afirma que NINGUNA query toca
  `counseling_cases`/`session_notes`/`referrals` — y que SÍ lee `care_auras` (el tap funciona); (2)
  una aserción estructural de que `AnalyticsBi::CareAura.reflect_on_all_associations` no apunta a
  ningún `Counseling::*`; (3) `AuraScope` devuelve solo el `Data` de 4 campos. Grep de cierre:
  `analytics_bi` menciona "counseling" ÚNICAMENTE en comentarios, jamás en código/queries.

- **Superficie de autoría en `counseling`, no en `analytics_bi`** (el permiso `counseling.write` vive
  ahí, y el orientador ve el `Case` que motiva el aura, §5.7): anidada bajo el caso
  (`/counseling/:case_id/care_auras`, `new`/`create`/`destroy`), alcanzada por la tile "Orientación"
  ya existente (regla de 3 clics) — **sin entrada de nav nueva**. El show del caso lista las auras
  activas del estudiante con botón "Retirar" (`can?` cosmético).

- **Entitlement:** el lado docente cuelga del addon `analytics_bi` (namespace `analytics_bi/*`, ya
  gateado); el lado autoría cuelga del addon `counseling` (namespace `counseling/*`, ya gateado). Un
  colegio con `counseling` pero sin `analytics_bi` publica auras que el orientador ve en el caso, pero
  ningún docente ve en un mapa — borde aceptado, no un gap.

- **Tests (20 nuevos, suite completa 646 runs / 0 fallos / 1 skip preexistente, en serie
  `PARALLEL_WORKERS=1`):** modelo/servicio (`care_aura_test.rb`: publicación, enum cerrado,
  concurrencia distinta-vs-misma-kind, append-only, retire idempotente, `group_id` delegado, +los dos
  tests de aislamiento clínico a nivel de modelo); autoría (`counseling_care_aura_authoring_test.rb`:
  `counseling.read` solo NO publica → 403, `counseling.write` publica vía el Projector, append-only,
  retire); aceptación de seguridad del docente (`analytics_bi_care_aura_test.rb`, espíritu María §6.4:
  `hps.aura.view` surface el badge con solo enum+texto, sin él el grid plano sin fuga, SQL tap sobre
  la request real, 403 fuera de scope, 404 cross-tenant). Sin SimpleCov en el repo (Minitest sin gema
  de cobertura, igual que Slice 2) — cobertura sostenida por los tests de modelo/servicio/controller
  (happy + fallo) descritos.

- Ver `HISTORIA.md` v1.37.0 para la narrativa completa del slice.

### v0.3.0 — 2026-07-17 — Slice 2 cerrado: Lente 1 "Mapa de Empatía Espacial" (geometría + heat sobre T1)

- **Decisión A2 ejecutada (owner-approved): la geometría del aula la POSEE `group_management`, no
  `analytics_bi`.** Dos tablas net-new tenant-scoped (RLS `ENABLE+FORCE`, `uuidv7()`, índice líder
  `institution_id`), dueño `group_management` (dueño del dato físico del salón — `Section`/`Student`
  viven ahí): `GroupManagement::ClassroomLayout` (una configuración versionable por `(section,
  academic_term)`: `rows`/`cols`/`board_orientation` 0·90·180·270/`aisles` jsonb geometría pura sin
  PII/`version`/`effective_from`/`effective_until`) y `GroupManagement::SeatAssignment` (quién se
  sienta dónde: `classroom_layout_id`/`student_id`/`row`/`col` efectivo-fechado). `analytics_bi`
  **solo lee** estas tablas (vía su propio query object con filtro de inquilino explícito, nunca
  `default_scope`), exactamente como ya lee `Schedules::Assessment`/`Attendance::AttendanceRecord`
  sin poseerlas (§5.1).
- **Tres `EXCLUDE USING gist` (btree_gist, molde v1.33.0 de billing)** — dato hecho cumplir en la BD,
  no en la app: (1) `classroom_layouts_no_overlapping_versions` por `(institution, section, term,
  daterange)` — una sola versión vigente + append-only real (más allá de "una activa a la vez"); (2)
  `seat_assignments_no_double_booked_seat` por `(institution, layout, row, col, daterange)` — un
  asiento nunca tiene dos estudiantes activos; (3) `seat_assignments_no_two_seats_per_student` por
  `(institution, layout, student, daterange)` — un estudiante nunca tiene dos asientos activos.
  `"row"` va **entrecomillado** en todo SQL crudo (palabra reservada). `btree_gist` ya lo habilitó
  la migración de billing; el `down` no lo elimina (esos constraints siguen dependiendo de él).
- **Reconfiguración append-only, molde simétrico `Subscription#end!`/`Entitlement#revoke!`.**
  `GroupManagement::ClassroomReconfigurer` cierra la versión vigente y abre `version + 1`;
  `GroupManagement::SeatAssigner` cierra el asiento activo del estudiante antes de abrir el nuevo
  (mover ≠ violar el constraint). **Desviación de redacción documentada:** §5.3 esbozaba
  `effective_until = ayer`; se cierra con `Date.current` en su lugar — con `daterange '[)'`,
  `[from, hoy)` y `[hoy, ∞)` son ADYACENTES (nunca solapan), lo que satisface el constraint Y
  funciona incluso reconfigurando el mismo día en que se creó la versión (ayer violaría el CHECK
  `effective_until >= effective_from` y dejaría un hueco de un día). Ambos servicios abren su
  transacción con `requires_new: true` (SAVEPOINT): una violación de exclusión revierte solo su
  unidad y re-lanza SIN envenenar la transacción del request (la del `TenantScoped`), así el
  controller la rescata y redirige limpio (bug real encontrado en tests — sin `requires_new` la
  transacción del request quedaba abortada tras el double-book).
- **Superficie de RECONFIGURACIÓN (write) en `group_management`, gateada por `groups.manage`.**
  UX select-based (no drag-and-drop — "aburrido sobre ingenioso", sin precedente de
  nested-attributes-con-JS que respalde un builder cliente): `ClassroomLayoutsController` (crear/
  reconfigurar) + `SeatAssignmentsController` (asignar/mover/liberar), colgados de
  `/group_management/groups/:id/`. El double-booking (constraint) se surface como alerta amable,
  nunca un 500.
- **Superficie de LECTURA (Lente 1) en `analytics_bi`, gateada por `hps.classroom.view`** (permiso
  nuevo en `SeedPermissions::CATALOG` — per-institución, `institution_admin` lo hereda por bootstrap
  como cualquier key salvo `cross_tenant_reports.view`; NO es cross-tenant). Molde #4 (supervisión):
  `AnalyticsBi::SpatialClassroomsController` con `authorize!` al inicio de cada acción; query object
  `AnalyticsBi::Lens::SpatialClassroomScope` (filtro de inquilino explícito + per-row `can?` sobre
  `layout.section` — un grant `:group` o `:grade_level` cubre la sección vía los `SCOPE_READERS`
  existentes). `can?` solo cosmético en vistas.
- **Heat in-memory, HSL server-side, cero recomputación en cliente (§10.2).**
  `AnalyticsBi::Lens::SpatialHeatmap` deriva por estudiante un valor 0..1 (mayor = más necesita
  atención) de `Schedules::Assessment.graded` (nota/5.0) + `Attendance::AttendanceRecord` (presentes
  ÷ registrados, últimos 30 días); `wellbeing = media de señales disponibles`, `heat = 1 - wellbeing`.
  Sin datos → `heat` **nil** (empty state real, dimmed/neutral, nunca un 0 engañoso — mismo principio
  que `InstitutionDashboard` v1.34.0). Mapea a `hsl(hue,72%,52%)` con `hue = (1-heat)*130` (calmo
  verde → cálido rojo), emitido como variable CSS `--heat` por asiento. `AnalyticsBi::Lens::
  SpatialClassroom` compone layout + asientos + heat como read-model (un objeto por controller).
- **SVG server-rendered (§10.1): `AnalyticsBi::Svg::SeatGrid`** (bajo `services/svg/`, colapsa a
  `AnalyticsBi::Svg::SeatGrid` — `helpers/` NO está en la lista de colapso de Zeitwerk, `services/`
  sí; verificado con `zeitwerk:check`). Renderiza la grilla como SVG plano (mismo molde que
  `shared/_bar_chart`), un `<g class="seat">` por asiento con `style="--heat: hsl(...)"` +
  `data-needs-attention`/`data-heat` que consume el Stimulus. **AA (nunca color solo):** el asiento
  que necesita atención lleva marca "!" + `aria-label`, y una tabla `visually-hidden` espeja cada
  asiento. Cero PII al cliente más allá de lo permitido: solo iniciales en el SVG; nombre completo
  solo en la tabla que el observador ya puede ver.
- **Stimulus `spatial_map_controller.js` (§10.4):** atenúa los estables (`.seat--dimmed`) resaltando
  quienes necesitan atención, solo con data-attributes ya en el DOM, sin round-trip, sin
  `localStorage`.
- **Aura overlay (§5.7, `care_auras`) DEFERIDO a Slice 3.** La Lente 1 de §5.7 menciona un ícono de
  aura sobre el pupitre del docente; este slice construye SOLO el mapa espacial + heat. El cableado
  del aura se hace al construir Slice 3 (`counseling` → proyección).
- **Tests (18 nuevos, suite completa 626 runs / 0 fallos / 1 skip preexistente, en serie):** los tres
  `EXCLUDE` a nivel de MODELO (reasignar/reconfigurar a mitad de año no viola; double-book y
  dos-asientos-por-estudiante lanzan `StatementInvalid`), un unit de cómputo de heat
  (thriving/struggling/sin-datos), y dos de aceptación de superficie: `authorize!` + scope realmente
  gatean quién ve qué aula (grupo-scoped ve solo la suya, 403 fuera de scope, 404 cross-tenant — el
  espíritu del caso de María, `PROJECT_STATE.md §6.4`) + el write gateado por `groups.manage`.
  Hallazgo de testing: una violación de exclusión dentro de una transacción *joinable* aborta la
  transacción entera — los tests de modelo fijan el GUC sobre la transacción de fixtures (no una
  anidada joinable) para que cada `create!` que viola caiga a su propio savepoint (comportamiento
  estándar de Rails en tests transaccionales), y los servicios usan `requires_new: true` por la
  misma razón en producción.
- Ver `HISTORIA.md` v1.36.0 para la narrativa completa del slice.

### v0.2.0 — 2026-07-17 — Slice 1 cerrado: `CrossTenantReportRoster` real (`edu_bi_reader`)

- **`AnalyticsBi::BiReaderRecord`** (nuevo, `app/domains/analytics_bi/models/`): la ÚNICA clase de la
  app que conecta como `edu_bi_reader` (BYPASSRLS) — un pool de conexión SEPARADO (nunca reconfigura
  el pool primario de `edu_app_runtime`), vía `ActiveRecord::Base.configurations.configs_for(...)`
  (no requiere una conexión ya abierta, seguro en tiempo de carga/autoload). Contraseña:
  `ENV["EDU_BI_READER_PASSWORD"]` (sin `.fetch` — `nil` es válido, igual que `EDU_DB_PASSWORD` de la
  conexión primaria: Postgres local confía en conexiones TCP de localhost sin importar el rol, así que
  dev/test no necesitan ninguna contraseña; un deployment real si). `AnalyticsBi::BiReader::{Institution,
  Student,Assessment}` son clases lectoras dedicadas bajo esta conexión — nunca se reusan las clases
  del pool primario (`Core::Institution` etc.), que quedarían atadas a la conexión equivocada.
- **`AnalyticsBi::CrossTenantReportRoster.all`** reemplaza el stub — agrega estudiantes activos y nota
  promedio por institución, SIEMPRE agrupado por `institution_id` explícito (el "doble filtro"
  §6.1.2: una vez bypasseado RLS, el `GROUP BY` de la app es la ÚNICA defensa contra mezclar filas de
  distintos tenants — nunca un `.average`/`.count` sin agrupar). Solo agregados salen del método, cero
  fila/PII de estudiante cruza la frontera.
- **Auditoría por acceso** (§6.1.4): `cross_tenant_report_accessed` nuevo en
  `IdentityAccess::AuditEventIndex::ACTIONS`, logueado desde
  `CrossTenantReportsController#index` bajo la institución del propio `bi_auditor` (no
  `ControlPlane::Audit` — el actor es staff de tenant con el permiso, no un `platform_admin`).
- **Hallazgo operativo, no de diseño:** el rol `edu_bi_reader` YA EXISTÍA en el clúster local
  (`BYPASSRLS`, permisos `SELECT` ya otorgados en dev y test desde `lib/tasks/roles.rake`) —
  solo la contraseña era desconocida. Reseteada vía `psql` con el superusuario del SO (mismo
  mecanismo ya documentado para `EDU_MIGRATOR_PASSWORD`), cluster-wide, cubre dev y test con un
  solo `ALTER ROLE`.
- **Hallazgo de testing crítico:** `CrossTenantReportRoster` corre en una conexión de BD
  GENUINAMENTE separada — nunca ve la transacción abierta-y-nunca-comiteada de un test transaccional
  normal de Rails. El primer intento con `self.use_transactional_tests = false` y SIN teardown dejó
  ~13 filas reales de `ControlPlane::Addon` + instituciones/usuarios reales en la base de test,
  chocando (violación de índice único) con decenas de tests no relacionados más adelante en la MISMA
  corrida de la suite. Corregido: (a) el test otorga SOLO el addon `analytics_bi` (nunca
  `grant_full_entitlements`, que crea los 13 addons de dominio de verdad), y (b) un `teardown`
  explícito borra TODO lo creado, en orden seguro de FK. Nuevo test dedicado,
  `test/integration/analytics_bi_cross_tenant_test.rb`, separado del resto de `analytics_bi_test.rb`
  (que sigue transaccional) por esta única razón.
- Ver `HISTORIA.md` v1.35.0 para la narrativa completa del slice.

### v0.1.0 — 2026-07-17
- Creación del documento maestro del dominio `analytics_bi` (HPS / BI Empático) como hermano de
  `PROJECT_STATE.md`/`UX_UI.md`/`LINEAMIENTOS_MVP.md`.
- Se fija la regla de precedencia (manda sobre `LINEAMIENTOS_MVP.md` para BI; nunca sobre invariantes
  de arquitectura; el repo gana sobre el doc).
- Se fijan: la filosofía HPS + seis no-negociables (NNA-first, cualitativo sobre score, intra-estudiante
  nunca ranking, vista digna, aislamiento clínico, sin buscador de personas); los **tres tiers de
  confidencialidad** (operacional/formativo/clínico) como marco organizador; el modelo de acceso de las
  5 lentes (supervisión vs. autoservicio + permisos `hps.*`); el ERD conceptual por capas de
  disponibilidad de dato (reuso T1, temporalidad, geometría de aula, instrumento de carácter molde
  rúbrica con resguardos anti-acoso, taxonomía de afinidades con FTS, núcleo familiar extendido, auras
  de cuidado); las guardas de RLS cross-tenant (doble filtro app-level, solo agregados, auditoría) y de
  aislamiento clínico; la estrategia de procesamiento (in-memory → snapshot → vistas planas; nunca
  materializadas); la estructura Zeitwerk; el flujo de Query Objects; la guía UX/UI (SVG server-rendered
  + HSL server-side + Stimulus sin round-trip + relajación acotada de librerías JS populares con "cero
  dato sensible al cliente"); y la **segmentación en 8 slices** ordenada por menor tensión.
- Se registran las decisiones del PO (#1 instrumento de carácter tipo rúbrica; #2 tests emocionales en
  `counseling`; #3 librerías JS populares acotadas; #4 orden de menor tensión; #5 procesamiento
  in-memory/snapshot) y se abren A1–A7 para los checkpoints de slice.
- Se supersede explícitamente la descripción de `analytics_bi` como "solo read-models": ahora también
  posee los instrumentos formativos (T2). Nota de sincronía pendiente en `PROJECT_STATE.md §4`.