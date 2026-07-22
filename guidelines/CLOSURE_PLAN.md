# edu_platform — Plan de cierre end-to-end (app académica operativa y robusta)

> **Qué es este documento.** Valida el camino para que `edu_platform` ejecute **de principio a fin**
> todos los procesos académicos, sin cabos sueltos ni puntos de quiebre, y sequencia el trabajo que
> falta. **Supersede la premisa de `LINEAMIENTOS_MVP_ITER2.md`** (que asumía el track HPS/BI parado):
> HPS completó las 8 lentes/slices de su roadmap original (v1.35.0→v1.43.0) y la Fase B (seguimiento
> disciplinario) también cerró (v1.45.0). Ante discrepancia con el repo/`HISTORIA.md`, gana el repo.
>
> **Nota de reconciliación (al guardar este doc, 2026-07-21):** `LINEAMIENTOS_MVP_ITER2.md` **no
> existe en el repositorio** (verificado, `ls guidelines/`) — la referencia queda documentada tal como
> se recibió; si ese doc existe en otro lugar o nunca se creó, corregir esta nota al confirmarlo. Este
> plan además llegó con **Slice 6 marcado "en curso"**; al momento de guardarlo, **Slice 6 ya está
> cerrado (v1.40.0)** — ver `HISTORIA.md` v1.40.0 y la corrección en §4/§5/§6 abajo.
>
> **Actualización final (2026-07-21): TODAS las fases (A/B/C) están cerradas — el criterio de hecho
> end-to-end de §1 está completo.** El owner autorizó proceder asumiendo la opción recomendada/más
> conservadora en cada decisión abierta que quedara sin confirmar explícitamente — la Fase C (alertas
> tempranas, §3.2/§6.3) se construyó así, con una heurística documentada explícitamente como
> PLACEHOLDER (no una regla de negocio real confirmada por el owner) — mismo principio de "boring
> default, revisar cuando exista una necesidad real" ya aplicado repetidamente en este proyecto. Solo
> Fase D (tier C, nice-to-have, fuera del criterio de hecho) sigue sin construir — nunca estuvo en
> alcance de este plan.
>
> **Actualización (2026-07-22): Fase D driver-based COMPLETA salvo el greenfield puro.** De los seis
> candidatos de recon (`cafeteria` alérgenos v1.47.0, `student_support` resto v1.48.0,
> `transportation` v1.49.0, `schedules` timetable v1.50.0, `cafeteria` resto v1.51.0 + su metering
> v1.52.0), **cinco ya cerraron** — cero dead-end activo, cero trabajo diferido en el repo. Solo queda
> `admissions`/`library` (greenfield puro, sin stub previo del que inferir reglas de negocio) —
> **gateado a confirmación explícita del owner**, nunca un default seguro de asumir (ver
> `guidelines/OPEN_PROCESS.md` ítem #1). Ver §5/Fase D abajo para el detalle completo.

---

## 1. Definición de "operativa end-to-end" (criterio de hecho fijado por el owner)

La app debe ejecutar, de punta a punta: **matrícula · asignación de grupos · registro de notas ·
evaluación · seguimiento académico · seguimiento disciplinario · psicoorientación · emisión de
boletines · alertas tempranas para docentes y acudientes.** Tier C (`cafeteria`/`transportation`/
timetable/`admissions`/`library`) es **nice-to-have**, explícitamente fuera de este criterio — con
**una salvedad** (§3.1).

---

## 2. Matriz de operabilidad (proceso → estado real, verificado contra `db/migrate/`)

| Proceso | Dominio(s) | Estado | Nota |
|---|---|---|---|
| **Matrícula** (estudiante + término) | `core`/`group_management`/`schedules` | ✅ **CERRADO (v1.41.0)** | Ver §4.4 — `Schedules::EnrollmentsController#create`, acción deliberada, sin depender de una nota. |
| **Asignación de grupos** | `group_management` | ✅ | `SectionReassigner` (v1.38.0), único seam de escritura, historia append-only en `student_placements`. |
| **Registro de notas** | `schedules` | ✅ | `Assessment` (v1.14.0), única fuente de la nota. |
| **Evaluación** | `assignments` + `analytics_bi` | ✅ | Track completo con rúbricas (v1.26.0); instrumento de carácter T2 (v1.39.0) + Lente 2/ficha (v1.40.0). |
| **Seguimiento académico** | `report_cards`/`analytics_bi` | ✅ | Boletines + `hps_term_snapshots` (v1.38.0) + tendencias intra-estudiante + ficha del acudiente/estudiante (v1.40.0). |
| **Seguimiento disciplinario** | `student_support` | ✅ **CERRADO (v1.45.0)** | `StudentSupport::DisciplinaryLog`, molde `counseling`, ver §3.1 — corte mínimo (solo convivencia; `medical_history`/`accommodations` siguen stub). |
| **Psicoorientación** | `counseling` | ✅ | Casos/sesiones/remisiones reales + proyección `care_auras` (v1.37.0). **No** es lo mismo que disciplinario. |
| **Emisión de boletines** | `report_cards` | ✅ | Snapshot congelado al publicar (v1.17.0). |
| **Alertas tempranas** (docente/acudiente) | `analytics_bi` | ✅ **CERRADO (v1.46.0)** | `AnalyticsBi::Lens::EarlyWarningScope`, Lente 6 (amendment MAJOR, `BI_DOCUMENT.md §5.8`) — ver §3.2. Heurística PLACEHOLDER, sin regla de negocio real confirmada. |

**Conclusión de la validación (actualizada 2026-07-21, Fase C cerrada — PLAN COMPLETO):** los NUEVE
procesos del criterio de hecho §1 son todos reales. Las 8 lentes/slices de `analytics_bi` (Fase A,
v1.35.0→v1.43.0), el seguimiento disciplinario (Fase B, v1.45.0), y alertas tempranas (Fase C,
v1.46.0) están CERRADOS — ver `HISTORIA.md` v1.43.0/v1.45.0/v1.46.0. Solo Fase D (tier C,
nice-to-have) queda sin construir, y nunca estuvo dentro del criterio de hecho.

---

## 3. Los dos cabos sueltos de feature

### 3.1 Seguimiento disciplinario — la salvedad de "tier C nice-to-have"
`counseling` (psicoorientación) es real; **convivencia/incidencias disciplinarias** vive en
`student_support`, que es Clase C (cero tablas). Está en el criterio de hecho, así que **no** es
diferible como el resto de tier C. **Corte recomendado:** modelar SOLO `disciplinary_logs` (incidencias
de convivencia) como slice **sensible (S)**, molde `counseling` (carve-out, caso de aceptación de
seguridad a nivel de modelo). `medical_history`/`accommodations` (que alimentan alérgenos de cafetería)
**siguen diferidos** — no se arrastra el Clase C completo para cerrar una necesidad acotada.

### 3.2 Alertas tempranas — capstone de síntesis — ✅ CERRADO (v1.46.0)
~~Todo el dato de señal ya existe...~~ **RESUELTO.** `AnalyticsBi::Lens::EarlyWarningScope` (Lente 6,
amendment MAJOR de `BI_DOCUMENT.md §5.8`) sintetiza heat (`hps_term_snapshots`), `disciplinary_logs`
recientes, y la alerta de lazos fraternales (Lente 4) — cero tabla propia, cero dato re-derivado.
**Punto de gobernanza resuelto: enmienda a `BI_DOCUMENT.md`** (Lente 6), no un mini-spec separado.
**Entrega**: nunca automática — la superficie solo enlaza a `communication` (`conversation.compose`)
y a la Lente 4 para que un humano decida contactar a la familia; cero job/cron/auto-mensaje.
**Construido SIN una regla de negocio real confirmada** (el propio anti-especulación de este párrafo
seguía vigente) — el owner autorizó explícitamente proceder con la opción recomendada/conservadora;
los umbrales (`HEAT_RISK_THRESHOLD`/`RECENT_DISCIPLINARY_WINDOW_DAYS`/`TRIGGER_MIN_SIGNALS`) quedan
documentados como PLACEHOLDER en el código y en `BI_DOCUMENT.md §13` (decisión A8), no como política
real. Ver `HISTORIA.md` v1.46.0.

---

## 4. Cabos de operabilidad (no de feature — impiden operar lo ya construido)

1. ~~**Consentimiento sin UI (Slice 5 → lo cierra Slice 6)**~~ ✅ **CERRADO (v1.40.0).** El instrumento
   de carácter exigía consentimiento activo pero solo se seteaba por rake — Slice 6 construyó
   `Portals::GuardianCharacterConsentsController` (otorgar/revocar desde el portal del acudiente) +
   `Portals::StudentPeerAppreciationsController` (dar un aporte de par desde el portal del estudiante).
   Slice 6 fue, tal como este plan lo preveía, la terminación operativa de Slice 5, no "más BI".
2. ~~**`HpsTermSnapshotJob` fuera de `recurring.yml`**~~ ✅ **CERRADO (v1.44.0).** Descubierto en el
   camino: `Core::AcademicTerm` no tenía NINGUNA UI de staff (solo seeds/consola) — se construyó
   `Core::AcademicTermsController` completo (crear/editar/activar/**cerrar**), y "cerrar término" es
   el disparador manual confirmado por el owner (§6.4): encola `AnalyticsBi::HpsTermSnapshotJob` para
   ese término exacto, molde `report_card.publish`, nunca un reloj/cron. Sigue **fuera de
   `recurring.yml` a propósito** — fin-de-término es un evento de staff, no de calendario fijo.
3. **Autoría de `character_frameworks` sin UI** (solo `bi:seed_character_starter`) — un colegio no
   puede curar su propio marco. **Confirmado deferido en Slice 6** (v1.40.0): el slice se cerró
   consumiendo el framework STARTER sembrado en Slice 5, sin construir la UI de autoría — decisión
   documentada, no un olvido. Sigue abierto para cuando haya una necesidad real de curación (A5 en
   `BI_DOCUMENT.md §13`).
4. ~~**Camino de escritura de matrícula por materia×término**~~ ✅ **CERRADO (v1.41.0).**
   `Schedules::EnrollmentsController#create` expone la MISMA llamada idempotente que
   `GradeEntriesController` ya usaba incidentalmente (`find_or_create_by!`, mismo lookup por
   `student_code`), como su propia acción — sin depender de que exista una nota. Reusa `grades.write`
   (ningún permiso nuevo). **Sin retiro/unenroll** (el índice único de `enrollments` no está scoped
   por `status` como el de `activity_enrollments` — un retiro real necesita su propia decisión de
   migración, deferido a propósito). Ver `HISTORIA.md` v1.41.0.
5. **Settings-por-institución inexistente (A3):** umbral N=3 y otros parámetros hardcodeados. Recurrente;
   decidir si en algún punto es su propio slice de infra o se sigue difiriendo como constante.

---

## 5. Plan de ejecución sin puntos de quiebre (secuencia por dependencia)

> Cada fase: recon-first, checkpoint de diseño para net-new, caso de aceptación (a nivel de modelo para
> los sensibles), cierre con `HISTORIA.md` + `OPEN_PROCESS.md`.

### FASE A — Terminar `analytics_bi`/HPS — ✅ CERRADA (v1.43.0, Slice 8). Las 8 lentes/slices del roadmap original están todas construidas.
- ~~**Slice 6 — Lente 2 (ficha) + operabilidad de T2**~~ ✅ **CERRADO (v1.40.0).** Cerró el cabo de
  consentimiento (§4.1): UI de otorgar/revocar consentimiento + dar aporte de par/acudiente desde
  portal. Autoría de `character_frameworks` (§4.3) quedó **explícitamente diferida**, no incluida.
- ~~**Slice 7 — Afinidades + Lente 3 (constelación).**~~ ✅ **CERRADO (v1.42.0).** Net-new T2 +
  primera librería JS real del codebase (Cytoscape.js, §10.3). Ver `HISTORIA.md` v1.42.0.
- ~~**Slice 8 — Núcleo familiar + Lente 4**~~ ✅ **CERRADO (v1.43.0).** Extiende `guardian_students`
  1:1 (nunca lo duplica); incluye la *alerta de lazos fraternales* (la única alerta ya prevista —
  insumo parcial de la Fase C), Cytoscape.js REUSADO (cero librería nueva). Ver `HISTORIA.md` v1.43.0.
- **Pendiente para cerrar el disparador de fin-de-término (§4.2):** `HpsTermSnapshotJob` sigue
  invocándose por rake manual — el botón de staff que el owner confirmó (§6.4) todavía no se
  construyó. Esto es lo único que falta para que "seguimiento año-a-año" sea 100% operativo sin
  consola; no bloquea nada más de Fase A/B/C.

### FASE B — Cerrar seguimiento disciplinario (§3.1) — ✅ CERRADA (v1.45.0)
- ~~**Slice `student_support` mínimo — `disciplinary_logs` (S).**~~ ✅ **CERRADO.** Molde `counseling`:
  append-only (sin ruta update/destroy — inmutable desde que se crea), auditado
  (`disciplinary_log.recorded`), permiso `disciplinary_logs.manage` REUSADO (ya existía). **Sin
  portal** (misma postura que `counseling`, staff-only) — "relación-gated en portal" del boceto
  original no aplicaba aquí, ninguna superficie de acudiente/estudiante. `medical_history`/
  `accommodations` NO entraron (siguen diferidos, Clase C). Ver `HISTORIA.md` v1.45.0.

### FASE B' — Cerrar el hueco de matrícula (§4.4) — ✅ CERRADA (v1.41.0)
- **Mini-slice: acción deliberada de matrícula por materia×término.** `Schedules::
  EnrollmentsController#create`, gate `grades.write` (reusado, sin permiso nuevo). Ver `HISTORIA.md`
  v1.41.0 para la narrativa completa. Retiro/unenroll deferido (decisión de migración real, no
  trivial — ver §4.4).

### FASE C — Alertas tempranas (capstone, §3.2) — ✅ CERRADA (v1.46.0) — PLAN COMPLETO
- ~~**Mini-spec o enmienda a `BI_DOCUMENT.md`**~~ ✅ **Enmienda MAJOR** (§5.8, Lente 6).
- ~~**Capa de síntesis**~~ ✅ **`AnalyticsBi::Lens::EarlyWarningScope`** — lee heat/convivencia/lazos
  fraternales (todo real desde Fases A/B), entrega vía enlace a `communication` + Lente 4 (nunca
  automática). Se apoyó en todo lo anterior, tal como el plan preveía: sin puntos de quiebre porque
  asistencia/notas/auras/disciplinario ya eran reales al llegar aquí. Ver `HISTORIA.md` v1.46.0.

### FASE D — Tier C propiamente (nice-to-have, fuera del criterio de hecho) — 5/6 CERRADOS, resto gateado
> **Corrección a la secuencia original**: este bloque asumía que "habilitar alérgenos" en `cafeteria`
> dependía de terminar `student_support` (medical/accommodations) primero. El recon del primer
> incremento (v1.47.0) mostró que NO es así — `cafeteria` ya tenía su propio `Cafeteria::
> DietaryRestriction` real e independiente, sin ninguna lectura cruzada a `student_support`. Los dos
> hilos son paralelos, no secuenciales; se corrige aquí (el repo manda sobre el plan).

- ~~**`cafeteria` — chequeo de alérgenos**~~ ✅ **CERRADO (v1.47.0).** `Cafeteria::DietaryRestriction`
  (ya real) conectado de verdad al checkout, reemplazando el stub paralelo `DietaryRestrictionRoster`.
  `MenuRoster`/`Purchase`/`StudentAccount` (menú, venta, saldo) siguen stub — deferido, es una pieza
  más grande (Menú/MenuItem + Compra + deducción de saldo con locking). Ver `HISTORIA.md` v1.47.0.
- ~~**`student_support` — resto**~~ ✅ **CERRADO (v1.48.0).** `medical_histories`/`student_allergies`/
  `accommodations` (tres tablas net-new, RLS `ENABLE+FORCE`) reemplazan `MedicalHistoryRoster`/
  `AccommodationRoster`. `AccommodationsController` ganó `new`/`create` (antes `only: %i[index edit
  update]`, sin ningún camino de creación real) — mismo criterio que `academic_terms` (v1.44.0): sin
  eso la pantalla quedaba permanentemente vacía. `StudentAllergiesController` (nuevo, `new`/`create`)
  gateado por el tier completo únicamente. Ver `HISTORIA.md` v1.48.0.
- ~~**`cafeteria` — resto** (Menú/Compra/Saldo)~~ ✅ **CERRADO (v1.51.0).** `Cafeteria::MenuItem`/
  `Purchase`/`PurchaseLine` reemplazan `MenuRoster`/`StudentAccountRoster`. Sin wallet propio de
  cafetería — una compra es un `Finance::Charge` contra la ÚNICA cuenta compartida
  (`finance.student_accounts`, mismo precedente que `Extracurriculars::EnrollmentCreator`), nunca una
  deducción de crédito prepago. `Cafeteria::PurchaseRecorder` (molde `ChargeCreator`/
  `PaymentRecorder`/`EnrollmentCreator`): `account.lock!` transaccional, idempotencia propia. Sin UI
  de autoría de menú (seeded, molde `dietary_restrictions`/`character_frameworks`). Metering (M1)
  cerrado aparte en v1.52.0, junto con `transportation` — ver `OPEN_PROCESS.md` ítem #5. Ver
  `HISTORIA.md` v1.51.0.
- ~~**`transportation`**~~ ✅ **CERRADO (v1.49.0).** El peor de los cuatro candidatos de recon — nav
  real ("Rutas"/"Abordaje") + controllers/rutas reales sobre `RouteRoster`/`RiderRoster` (100%
  `Data.define`) — cerrado con cuatro tablas net-new (`routes`/`route_stops`/`route_riders` con
  `shift` am/pm/`boarding_events`). De paso se cerró un hallazgo mayor: el scope `:route` de RBAC
  nunca estuvo conectado al motor real (`role_assignments.scope_route_id` no existía) — ahora sí.
  Ver `HISTORIA.md` v1.49.0.
- ~~**`schedules` — mitad de horario/timetable**~~ ✅ **CERRADO (v1.50.0).** El otro dead-end activo
  que `transportation` tenía como par (nav "Horario institucional" + rutas reales sobre
  `RoomRoster`/`ScheduleEventRoster`, 100% `Data.define`) — cerrado con dos tablas net-new
  (`rooms`/`meeting_patterns`, patrón plano `day_of_week`+horas, sin tabla `periods` compartida).
  Doble-booking de salón PERMITIDO (sin `EXCLUDE gist`); el conflicto se CALCULA en lectura
  (`Schedules::MeetingPatternPresenter`) en vez de reflejar el flag inventado del stub. Ver
  `HISTORIA.md` v1.50.0.
- **`admissions`/`library`**: no tienen NINGÚN archivo, ruta, ni entrada de nav — cero superficie,
  cero riesgo de UX. Construirlos sería un dominio enteramente greenfield, no una conversión
  stub→real — sin la urgencia de "arreglar un dead-end visible" que ya cerraron los ítems
  anteriores. Con `transportation`/`schedules` timetable/`cafeteria` resto todos cerrados
  (v1.49.0/v1.50.0/v1.51.0), **Fase D queda reducida a esto únicamente** — no queda ningún dead-end
  ni trabajo diferido en el repo, solo este greenfield puro.

---

## 6. Decisiones a confirmar

1. ~~**Matrícula por materia (§4.4)**~~ **RESUELTO (owner, 2026-07-21): mini-slice AHORA, antes de
   Slice 7** (Fase B' se adelanta, se intercala antes de continuar Fase A).
2. ~~**⚠ Disciplinario**~~ **RESUELTO (owner, 2026-07-21): el corte mínimo basta** —
   `disciplinary_logs` solo (molde `counseling`), `medical_history`/`accommodations` siguen diferidos
   como tier C. Fase B queda así de alcance, sin reabrir la pregunta al llegar ahí.
3. ~~**⚠ Alertas tempranas**~~ **RESUELTO (owner, 2026-07-21): proceder con la opción recomendada/
   conservadora, sin esperar una regla de negocio real.** Construido como Lente 6 en `BI_DOCUMENT.md`
   (enmienda, no spec propio); disparo por cualquier señal real (heat/convivencia/lazos fraternales);
   entrega SIEMPRE vía un enlace a `communication`/Lente 4, nunca automática. Los umbrales quedan
   documentados como PLACEHOLDER (decisión A8 de `BI_DOCUMENT.md §13`) — revisar en cuanto exista una
   regla de negocio real confirmada por el owner.
4. ~~**Fin-de-término**~~ **RESUELTO (owner, 2026-07-21): botón manual de staff**, molde
   `report_cards.publish` — una acción explícita "Cerrar término y congelar HPS", no un reloj/fecha
   programada. Construir al cerrar Fase A (después de Slice 8).
5. ~~**Slice 6:** ¿la autoría de `character_frameworks` (§4.3) entra aquí o se difiere explícita?~~
   **RESUELTO por lo ya construido:** Slice 6 se cerró SIN autoría de frameworks (diferida,
   documentada). Reabrir solo si surge una necesidad real de curación (A5).

**Secuencia ejecutada (completa):** Fase B' (matrícula, v1.41.0) → Slice 7 (afinidades/Lente 3,
v1.42.0) → Slice 8 (núcleo familiar/Lente 4, v1.43.0) → disparador real de fin-de-término (v1.44.0,
cierra Fase A) → Fase B (`disciplinary_logs`, v1.45.0) → Fase C (alertas tempranas/Lente 6, v1.46.0).
**Con esto, el plan de cierre end-to-end está completo** — solo Fase D (tier C, nice-to-have) queda
como backlog futuro fuera de este criterio.

---

## 7. Checklist "sin puntos de quiebre" (verificación final, plan completo)

- [x] Todo dato de cada fase es real (`grep create_table`), nunca stub asumido.
- [x] Los sensibles (disciplinario v1.45.0, carácter v1.39.0, auras v1.37.0) llevan caso de seguridad a nivel de **modelo**.
- [x] Cada capacidad nueva es **operable sin rake/consola** (consentimiento ✅ v1.40.0, snapshots ✅ v1.44.0 — botón de cerrar término; autoría de frameworks ⚠ diferida a propósito §4.3, no bloquea el criterio de hecho).
- [x] Cada señal que la Fase C consumió (heat, convivencia, lazos fraternales) ya estaba construida y probada ANTES de construir la Fase C (v1.46.0).
- [x] Suite completa en serie (`PARALLEL_WORKERS=1`), 0 fallos, corrida entera — 763 runs / 0 fallos / 1 skip preexistente al cierre de Fase C.
- [x] `HISTORIA.md` + `OPEN_PROCESS.md` + este plan actualizados al cerrar cada fase (v1.41.0 → v1.46.0).

**Plan de cierre end-to-end: COMPLETO (2026-07-21).** Los nueve procesos de §1 son reales, verificados
contra el repositorio, con caso de aceptación (HTTP y/o modelo) para cada uno. Fase D (tier C) queda
como backlog futuro, explícitamente fuera de este criterio de hecho.
