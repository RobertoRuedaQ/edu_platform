# edu_platform — Plan de cierre end-to-end (app académica operativa y robusta)

> **Qué es este documento.** Valida el camino para que `edu_platform` ejecute **de principio a fin**
> todos los procesos académicos, sin cabos sueltos ni puntos de quiebre, y sequencia el trabajo que
> falta. **Supersede la premisa de `LINEAMIENTOS_MVP_ITER2.md`** (que asumía el track HPS/BI parado):
> HPS avanzó de Slice 1 a Slice 6 (v1.35.0→v1.40.0). Ante discrepancia con el repo/`HISTORIA.md`, gana
> el repo.
>
> **Nota de reconciliación (al guardar este doc, 2026-07-21):** `LINEAMIENTOS_MVP_ITER2.md` **no
> existe en el repositorio** (verificado, `ls guidelines/`) — la referencia queda documentada tal como
> se recibió; si ese doc existe en otro lugar o nunca se creó, corregir esta nota al confirmarlo. Este
> plan además llegó con **Slice 6 marcado "en curso"**; al momento de guardarlo, **Slice 6 ya está
> cerrado (v1.40.0)** — ver `HISTORIA.md` v1.40.0 y la corrección en §4/§5/§6 abajo.

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
| **Seguimiento disciplinario** | `student_support` | ❌ **GAP** | Clase C — `disciplinary_logs` **no tiene tabla**. Es tier C, pero está en el criterio de hecho (§3.1). |
| **Psicoorientación** | `counseling` | ✅ | Casos/sesiones/remisiones reales + proyección `care_auras` (v1.37.0). **No** es lo mismo que disciplinario. |
| **Emisión de boletines** | `report_cards` | ✅ | Snapshot congelado al publicar (v1.17.0). |
| **Alertas tempranas** (docente/acudiente) | — | ❌ **GAP** | No diseñado. Existen señales crudas (heat/auras/carácter), no una capa de síntesis+entrega (§3.2). |

**Conclusión de la validación (actualizada 2026-07-21, Slice 8 cerrado):** las 8 lentes/slices de
`analytics_bi` (Fase A) están TODAS cerradas (v1.35.0→v1.43.0) — ver `HISTORIA.md` v1.43.0. Esto
**no** entrega por sí solo el criterio de hecho §1: quedan dos procesos sin construir (disciplinario,
Fase B; alertas tempranas, Fase C — ambas con sus decisiones ya confirmadas por el owner en §6) y
varios cabos menores (§4).

---

## 3. Los dos cabos sueltos de feature

### 3.1 Seguimiento disciplinario — la salvedad de "tier C nice-to-have"
`counseling` (psicoorientación) es real; **convivencia/incidencias disciplinarias** vive en
`student_support`, que es Clase C (cero tablas). Está en el criterio de hecho, así que **no** es
diferible como el resto de tier C. **Corte recomendado:** modelar SOLO `disciplinary_logs` (incidencias
de convivencia) como slice **sensible (S)**, molde `counseling` (carve-out, caso de aceptación de
seguridad a nivel de modelo). `medical_history`/`accommodations` (que alimentan alérgenos de cafetería)
**siguen diferidos** — no se arrastra el Clase C completo para cerrar una necesidad acotada.

### 3.2 Alertas tempranas — capstone de síntesis (net-new, no en `BI_DOCUMENT.md`)
Todo el dato de señal ya existe: riesgo de asistencia (`Attendance`), caída de notas (`Assessment`),
auras de cuidado (`counseling`→proyección), carácter (T2, con Lente 2/ficha ya real desde v1.40.0), y
—una vez exista— incidencias (§3.1). Falta la capa que (a) evalúa **reglas de riesgo** contra esas
señales, (b) genera un **artefacto de alerta** y (c) lo **entrega** al docente/acudiente por los
canales ya construidos (`communication` + portal). **Punto de gobernanza:** `BI_DOCUMENT.md` fija 5
lentes; una capa de alertas es capacidad NUEVA → decidir si es enmienda a ese doc (¿"Lente 6"?) o
mini-spec propio. Sin regla de negocio real confirmada (umbrales, a quién notifica, con qué
frecuencia) no se modela — mismo principio anti-especulación del repo.

---

## 4. Cabos de operabilidad (no de feature — impiden operar lo ya construido)

1. ~~**Consentimiento sin UI (Slice 5 → lo cierra Slice 6)**~~ ✅ **CERRADO (v1.40.0).** El instrumento
   de carácter exigía consentimiento activo pero solo se seteaba por rake — Slice 6 construyó
   `Portals::GuardianCharacterConsentsController` (otorgar/revocar desde el portal del acudiente) +
   `Portals::StudentPeerAppreciationsController` (dar un aporte de par desde el portal del estudiante).
   Slice 6 fue, tal como este plan lo preveía, la terminación operativa de Slice 5, no "más BI".
2. **`HpsTermSnapshotJob` fuera de `recurring.yml`** (disparo manual, data-dependiente). Para
   "seguimiento año-a-año" operativo hace falta un **disparador real de fin-de-término** (evento de
   cierre de término, no reloj) — decisión de producto pendiente (§6.4).
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

### FASE B — Cerrar seguimiento disciplinario (§3.1)
- **Slice `student_support` mínimo — `disciplinary_logs` (S).** Molde `counseling`: append-only,
  auditado, relación-gated en portal, caso de seguridad a nivel de modelo. `medical_history`/
  `accommodations` NO entran (siguen diferidos). Con esto el criterio de hecho de "disciplinario"
  queda cubierto sin abrir el Clase C completo.

### FASE B' — Cerrar el hueco de matrícula (§4.4) — ✅ CERRADA (v1.41.0)
- **Mini-slice: acción deliberada de matrícula por materia×término.** `Schedules::
  EnrollmentsController#create`, gate `grades.write` (reusado, sin permiso nuevo). Ver `HISTORIA.md`
  v1.41.0 para la narrativa completa. Retiro/unenroll deferido (decisión de migración real, no
  trivial — ver §4.4).

### FASE C — Alertas tempranas (capstone, §3.2)
- **Mini-spec o enmienda a `BI_DOCUMENT.md`** con las reglas de riesgo confirmadas por el owner.
- **Capa de síntesis** que lee señales existentes (asistencia/notas/auras/carácter/incidencias) +
  **entrega** por `communication`/portal. Se apoya en todo lo anterior — por eso va al final: no tiene
  puntos de quiebre solo si asistencia, notas, auras y disciplinario ya son reales.

### FASE D — Tier C propiamente (nice-to-have, fuera del criterio de hecho)
- Resto de `student_support` (medical/accommodations) → habilita alérgenos → `cafeteria` →
  `transportation` → timetable → `admissions`/`library`. **Driver-based**, como ya fijaba
  `LINEAMIENTOS_MVP_ITER2.md §4` (doc no localizado en el repo — ver nota de reconciliación arriba).
  No bloquea nada de A–C.

---

## 6. Decisiones a confirmar

1. ~~**Matrícula por materia (§4.4)**~~ **RESUELTO (owner, 2026-07-21): mini-slice AHORA, antes de
   Slice 7** (Fase B' se adelanta, se intercala antes de continuar Fase A).
2. ~~**⚠ Disciplinario**~~ **RESUELTO (owner, 2026-07-21): el corte mínimo basta** —
   `disciplinary_logs` solo (molde `counseling`), `medical_history`/`accommodations` siguen diferidos
   como tier C. Fase B queda así de alcance, sin reabrir la pregunta al llegar ahí.
3. **⚠ Alertas tempranas:** sigue abierta — reglas de negocio (qué dispara una alerta, a quién
   notifica — docente/acudiente/ambos—, umbral, frecuencia, y si es "Lente 6" en `BI_DOCUMENT.md` o
   spec propio). Se retoma al llegar a Fase C, no bloquea nada antes.
4. ~~**Fin-de-término**~~ **RESUELTO (owner, 2026-07-21): botón manual de staff**, molde
   `report_cards.publish` — una acción explícita "Cerrar término y congelar HPS", no un reloj/fecha
   programada. Construir al cerrar Fase A (después de Slice 8).
5. ~~**Slice 6:** ¿la autoría de `character_frameworks` (§4.3) entra aquí o se difiere explícita?~~
   **RESUELTO por lo ya construido:** Slice 6 se cerró SIN autoría de frameworks (diferida,
   documentada). Reabrir solo si surge una necesidad real de curación (A5).

**Secuencia confirmada:** Fase B' (matrícula, mini-slice) → Slice 7 (afinidades/Lente 3) → Slice 8
(núcleo familiar/Lente 4) → disparador real de fin-de-término (botón manual) cierra Fase A → Fase B
(`disciplinary_logs`, corte mínimo ya confirmado) → Fase C (alertas, pendiente de reglas de negocio).

---

## 7. Checklist "sin puntos de quiebre" (por fase, antes de dar por cerrada)

- [ ] Todo dato de la fase es real (`grep create_table`), nunca stub asumido.
- [ ] Los sensibles (disciplinario, carácter, auras) llevan caso de seguridad a nivel de **modelo**.
- [ ] Cada capacidad nueva es **operable sin rake/consola** (consentimiento ✅ v1.40.0, snapshots
      ⚠ pendiente §4.2, autoría de frameworks ⚠ diferida a propósito §4.3).
- [ ] Cada señal que una alerta consumirá (Fase C) ya está construida y probada antes de la Fase C.
- [ ] Suite completa en serie (`PARALLEL_WORKERS=1`), 0 fallos, corrida entera (no solo el archivo nuevo).
- [ ] `HISTORIA.md` + `OPEN_PROCESS.md` + este plan actualizados al cerrar cada fase.
