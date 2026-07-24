# Lineamientos de MVP — Colegio K-12 (extracurriculares · comunicación · responsabilidades · calendario del cuidador)

> **Qué es este documento.** Fija el **alcance y los lineamientos** de un primer MVP de `edu_platform`
> para un perfil de cliente concreto. Traduce cada función pedida a la arquitectura ya existente,
> propone la forma de los dominios nuevos (respetando los invariantes del proyecto), y separa lo que
> entra del MVP de lo diferible. **No es un prompt de implementación** — es la guía que alimenta los
> slices siguientes. Cada dominio nuevo, cuando se construya, sigue igual la disciplina recon-first.
>
> Se apoya en el estado `v1.12.0`+ (identidad, RBAC+scope, entitlements, portales de persona, staff
> generalizado, auditoría — todo real). Ante discrepancia con el magro/`HISTORIA.md`, gana el repo.
>
> **✅ MVP CERRADO — camino crítico completo desde `v1.29.0`** (§7 tiene el detalle slice a slice).
> Los 10 ítems de este documento (matrícula/término, asistencia, notas→boletines, pago manual,
> comunicación, asignaciones, calendario, extracurriculares, portal del cuidador ampliado,
> provisioning+correo real) están construidos y reales en el repo. El proyecto siguió avanzando
> post-MVP (Fase D de dominios diferidos, `analytics_bi`/HPS, RBAC real, billing de plataforma) hasta
> `v1.59.0` — ese trabajo posterior vive en `PROJECT_STATE.md`/`HISTORIA.md`/`OPEN_PROCESS.md`, no se
> duplica aquí. Este documento queda como **registro de lineamientos + qué tan cerca terminó la forma
> propuesta de la forma real** (§3/§4 anotan las diferencias donde las hubo).

---

## 1. Perfil del cliente y definición de "hecho"

**Colegio mixto K-12** con: (a) **actividades extracurriculares** — deportes, artes, refuerzo escolar;
(b) **comunicación interna** (staff↔staff) **y externa** (colegio↔acudientes); (c) **aplicación de
responsabilidades** a los menores/acudientes con seguimiento; (d) **calendario compartido** con los
cuidadores de los menores.

**Definición de MVP "hecho":** un colegio puede dar de alta a su gente, inscribir estudiantes en el
término activo, abrir actividades extracurriculares e inscribir estudiantes en ellas, comunicarse con
los acudientes (anuncios + hilos), asignar responsabilidades con vencimiento, y publicar un calendario
— y **el acudiente ve, en su portal, todo lo relativo a sus hijos**: actividades, calendario,
responsabilidades y mensajes, sin ver nada de otros menores.

**Segmento fijado:** K-12 (homerooms, grados, acudientes, menores que pueden no tener login). No
educación superior (registrar/facultades/cursos quedan fuera de este MVP).

---

## 2. Principio de encaje (cómo se conecta lo nuevo a lo que ya hay)

1. **Todo lo externo cuelga del portal del cuidador.** `Core::Access::GuardianScope` ya resuelve "los
   hijos activos de este acudiente" por relación, sin RBAC, sin buscador (Habeas Data). Calendario,
   comunicación, responsabilidades y actividades **del hijo** se resuelven a través de ese mismo scope
   — no se inventa una segunda puerta de acceso de padres.
2. **Un addon = un dominio.** Cada capacidad nueva es un dominio addon-able que el colegio "enciende"
   por entitlement. Para este cliente se habilitan: `extracurriculars`, `communication`, `calendar`
   y `assignments` (asignaciones académicas — dominio propio, ver §4.3). Los fundacionales (core,
   staff, group, identity) no se gatean.
3. **Dos compuertas en serie, sin excepción.** Staff que gestiona (crea actividad, envía anuncio,
   publica evento, asigna responsabilidad) pasa por entitlement → `authorize!` con scope. Acudiente/
   estudiante accede por **relación** (portal), nunca por RBAC.
4. **Staff de actividades usa el staff generalizado.** Entrenadores, profesores de arte y tutores de
   refuerzo son `StaffManagement::StaffMember` (CHECKPOINT E ya lo permite; `department_id` nullable),
   con un rol RBAC apropiado — no un modelo de persona nuevo.
5. **Menores = dato sensible desde el diseño.** Comunicación, calendario y responsabilidades tocan
   datos de menores → relación-gated, PII mínima, sin directorios navegables, auditado.

---

## 3. Mapeo de lo pedido → arquitectura

| Función pedida | Dominio(s) | Estado hoy | Qué falta para el MVP |
|---|---|---|---|
| **Extracurriculares** (deportes/artes/refuerzo) | `extracurriculars` (addon) | ✅ **Real (v1.27.0)**: `Activity`/`Enrollment`, cupo agregado con lock + índice único parcial, instructor por propiedad de fila, ambas vías de inscripción. | Nada — cerrado. |
| **Comunicación interna** (staff↔staff) | `communication` | ✅ **Real (v1.20.0)**: `Conversation`/`ConversationParticipant`/`Message`, canales + DM. | Nada — cerrado (fan-out 1:1, threading, tags, tiempo real diferidos, ver §6). |
| **Comunicación externa** (colegio↔acudiente) | `communication` | ✅ **Real (v1.19.0/v1.20.0)**: `Announcement` (org-wide) + `parent_thread` vía `Conversation` (participante `institution_user` **o** `guardian`, CHECK exactamente-uno). Superficie en el portal del cuidador. | Nada — cerrado. |
| **Asignaciones académicas** (tareas, trabajos grupales) | `assignments` (addon) | ✅ **Real, track completo (v1.21.0–v1.26.0)**, pero **más angosto que lo propuesto**: tarea por `subject_id` (nunca `kind`/`target_*` genérico), fecha, entrega (texto+adjuntos, individual y grupal), rúbricas. **Salidas pedagógicas y consentimiento bloqueante NO se construyeron** — ver §4.3/§9-1. | Nada del alcance realmente construido — cerrado (submission workspace de archivos colaborativos sigue diferido). |
| **Calendario compartido con cuidadores** | `calendar` (addon) | ✅ **Real (v1.27.0)**: eventos con audiencia por scope (institución-wide/grado/grupo); el acudiente ve los de sus hijos + los del colegio, con los vencimientos de `assignments` fusionados en el portal. | Nada — cerrado. |
| **Notas / calificaciones** | `schedules` (libreta) | ✅ **Real (v1.14.0 libreta + v1.17.0 boletines)**: `Subject`/`Enrollment`/`Assessment` + agregación en `report_cards` (snapshot congelado al publicar), visible en el portal del cuidador. | Nada — cerrado (asistencia en el boletín y escala Decreto 1290 diferidos). |
| **Asistencia** | `attendance` (dominio propio) | ✅ **Real (v1.16.0)**: diaria por homeroom, dominio propio addon-gated, decisión §9 resuelta a favor de (c). | Nada — cerrado (por-materia diferido). |
| **Pagos (manual, tesorería)** | `finance` | ✅ **Real (v1.18.0)**: UI de tesorería sobre los 5 modelos ya reales — registrar cargo/pago manual. Sin pasarela (post-MVP, confirmado no-goal en `OPEN_PROCESS.md`). | Nada — cerrado. |
| **(Dependencia dura) Matrícula / término** | `core` + `group_management` + `schedules` | ✅ **Real (v1.15.0)**: `Schedules::ActiveTermEnrollmentScope` cierra el join `enrollments`↔`academic_terms` (B2/Cav.) — el resolver canónico de "matriculado en el término activo", consumido por `attendance`/`report_cards`/`assignments`. | Nada — cerrado, fue el desbloqueo de casi todo. |
| **(Reutilizado) Acceso del cuidador** | `core` (`GuardianScope`) | ✅ Real (v1.9.0) | Nada — es la base sobre la que se cuelga todo lo externo. |
| **(Reutilizado) Alta de personas / roster CSV** | `identity_access`/`core` | ✅ Real | Nada. |

---

## 4. Dominios / conceptos nuevos (forma propuesta — aburrida, tenant-scoped, RLS)

> Formas de referencia, no esquema final. Cada una se recon-ea contra el disco al construirse y
> respeta: `institution_id` + RLS FORCE, UUIDv7, sin `default_scope`, dinero en `*_cents` si aplica.

### 4.1 `extracurriculars` (addon) — ✅ construido (v1.27.0)
- **`activities`**: `kind` (`sport`/`art`/`tutoring`), `name`, `academic_term_id` (FK real — cierra
  parte de B2), `capacity`, `instructor_staff_member_id` (FK a StaffMember, nullable), `fee_cents`
  (nullable — actividad puede ser gratuita), lugar/horario simple **propio** (no depender de
  `schedules`, que no tiene tablas reales).
- **`activity_enrollments`**: estudiante ↔ actividad, `status`. Inscripción con cupo (rechaza sobre
  capacidad). **Consentimiento del acudiente** como responsabilidad/anuncio, no como columna suelta.
- **RBAC**: instructor ve el roster de **su** actividad (scope); coordinador de extracurriculares ve
  todas. Roles nuevos: `activity_coordinator`, `activity_instructor` (o reusar staff + permiso
  `activity.manage`).
- **Portal del cuidador**: el acudiente ve las actividades de su hijo + horario; inscribir/desinscribir
  puede ser acción del acudiente o del colegio — **decisión a confirmar**.

> **Cómo quedó construido**: forma real muy cercana a la propuesta — `Activity`/`Enrollment`
> (`activity_enrollments`, soft active/withdrawn, `enrolled_via` staff/guardian). Cupo resuelto como
> invariante agregado (`activity.lock!` + `COUNT`, nunca CHECK declarativo) respaldado por índice
> único parcial. La sub-decisión de scope del instructor (§9-3) se resolvió por **propiedad de fila**
> (`Extracurriculars::ActivityScope` filtra por `instructor_staff_member_id`), no un `scope_type`
> nuevo — `activity.manage` (institución-wide) vs. `activity.instruct` (propia). Ambas vías de
> inscripción quedaron dentro (§9-2 resuelta). Ver `HISTORIA.md` v1.27.0.

### 4.2 `calendar` (addon) — ✅ construido (v1.27.0)
- **`calendar_events`**: `title`, `starts_at`/`ends_at`, `kind` (`school_event`/`activity`/`deadline`/
  `term`), `visibility`/audiencia (institución-wide / por grado / por grupo / por actividad), FK
  opcional a `activity`/`assignment`/`academic_term`.
- **Visibilidad para el cuidador por relación**, no por RBAC: un acudiente ve los eventos institución-
  wide + los del grado/grupo/actividades **de sus hijos** — resuelto con el mismo patrón que
  `GuardianScope` (un `Core::Access::…Scope` propio del calendario), sin buscador.
- **Staff** crea/edita eventos (RBAC + scope). Los vencimientos de `assignments` y los horarios de
  actividades se **derivan** en el calendario en vez de duplicarse.

> **Cómo quedó construido**: `Calendar::Event` con audiencia por **dos columnas de scope mutuamente
> exclusivas** (`scope_grade_level_id` XOR `scope_group_id`, ambas null ⇒ institución-wide) — mismo
> idioma que `role_assignments.scope_*`, sin la columna `kind` propuesta arriba (los "deadlines" se
> derivan en memoria vía `Calendar::Timeline`, nunca como fila). Solo `assignments` se deriva hoy
> (`attendance`/`extracurriculars` como fuentes de fecha quedan diferidas — sin consumo real). Ver
> `HISTORIA.md` v1.27.0.

### 4.3 `assignments` — asignaciones académicas (addon) — **DECISIÓN RESUELTA** — ✅ construido, track completo (v1.21.0–v1.26.0)
Cubre tareas, trabajos grupales, salidas pedagógicas "y otras" — todas comparten *fecha + materiales +
a-quién-se-asigna*, así que un solo dominio con discriminador de `kind`, no varios. **Es dominio propio**
(no faceta de `communication`) por la riqueza que trae la aclaración: tipos, targeting, materiales,
consentimiento y seguimiento.

- **`assignments`**: `kind` (`homework`/`group_work`/`field_trip`/`other`), `title`, `description`,
  `due_on` (tarea/trabajo) **o** `event_on` (salida), `materials` (texto; tabla hija solo si crece),
  `requires_consent` (bool — `true` por defecto en `field_trip`), `created_by_staff_member_id`.
- **A quién se asigna — columnas de scope explícitas y nullables** (mismo idioma que
  `role_assignments.scope_*` y `conversation_participants`, nada polimórfico): `target_student_id` /
  `target_group_id` / `target_grade_level_id`. Un trabajo grupal apunta a un `group`; una tarea a un
  grupo/clase o a un estudiante; una salida a un grado/grupo.
- **Seguimiento/consentimiento — `assignment_acknowledgments`**: por estudiante (y/o su acudiente para
  consentimiento), `status` (`pending`/`submitted`/`done`/`consented`). **Regla de negocio**: una salida
  pedagógica sin consentimiento del acudiente **bloquea** la participación del menor (auditado).
- **RBAC + scope (cae en el molde #4)**: un docente crea/gestiona asignaciones **de sus propios grupos**
  (`authorize! assignment.manage` + descriptor de scope, exactamente como el caso de María); un jefe de
  área, las de su departamento. Permiso nuevo `assignment.manage`.
- **Portal del cuidador (relación)**: el acudiente ve las asignaciones de su hijo con fecha y materiales,
  y **da el consentimiento** de las salidas; nunca ve las de otros menores, sin buscador.
- **Calendario**: la fecha (`due_on`/`event_on`) se **deriva** al `calendar` (§4.2) — no se duplica.
- **Fuera del MVP**: espacio de colaboración/entrega de archivos del trabajo grupal (submission
  workspace) — el MVP rastrea "asignado + estado", no una superficie de subida de entregables.

> **Cómo quedó construido — más angosto que la forma propuesta, por decisión real de alcance**:
> `Assignments::Assignment` (`assignments`: `subject_id`, `title`, `instructions`, `due_date`,
> `status`, `group_work` boolean, `evaluation_method` direct/rubric) — **sin** columna `kind`, **sin**
> `target_student_id`/`target_group_id`/`target_grade_level_id` (el targeting es implícito: el roster
> de la MATERIA vía `Schedules::ActiveTermEnrollmentScope` ∩ scope RBAC del docente, no columnas de
> scope explícitas propias), y **sin `requires_consent`/`field_trip`/salidas pedagógicas** — grep
> contra `db/structure.sql` confirma que esa columna nunca existió (un slice posterior, v1.39.0,
> encontró la misma referencia rota al citar este molde y lo documentó como corrección). El dominio
> quedó acotado a *tareas de una materia* (homework/coursework), no al superset "tareas + trabajos
> grupales + salidas" de la propuesta original. La nota vive SOLO en `schedules::Assessment`
> (`assignment_id` nullable, aditivo) — publicar hace fan-out de una fila `Assessment` por matrícula
> del roster; calificar actualiza esa misma fila, nunca un almacén paralelo. Cuatro slices reales:
> entrega de texto (v1.22.0, ingresable por estudiante o acudiente), entregas grupales (v1.23.0,
> `Submission` XOR `SubmissionGroup`), adjuntos de entrega (v1.24.0, docx/pdf/jpg/png ≤10MB), y
> **rúbricas** (v1.26.0, no estaba en la forma original — biblioteca reutilizable normalizada,
> congelada como snapshot jsonb al publicar, calcula la nota vía `GradeRecorder`/`GroupGrader` sin
> tocarlos). El submission workspace de archivos colaborativos sigue diferido, tal cual se previó.
> Ver `HISTORIA.md` v1.21.0–v1.26.0 y v1.39.0 (hallazgo de la referencia rota).

### 4.4 `communication` (activar el stub) — ✅ construido, ambos subsistemas (v1.19.0/v1.20.0)
- Migrar el diseño ya bosquejado (§8 magro): `conversations` (`kind` direct/channel/parent_thread/
  announcement), `conversation_participants` (institution_user **o** guardian, CHECK exactamente-uno),
  `messages`, `tags`, `mentions`, faceta notificaciones.
- **Interna (estilo Campfire, dos vías)**: `channel` (rooms de staff, chat simple 37signals-like) +
  `direct` (DM entre staff). RBAC para quién ve/postea en cada room.
- **Externa (dos vías)**: `announcement` (anuncios públicos del colegio) + `parent_thread` (los
  "correos" internos colegio↔acudiente — bandeja tipo inbox, **no** email real). Superficie en el
  portal del cuidador (relación), participante = `institution_user` **o** `guardian` (CHECK
  exactamente-uno, ya diseñado).
- **Tiempo real diferido** (sin Turbo Streams/Cable en el MVP — UI con refresh, como ya prevé el §8).
  Campfire es chat en vivo por naturaleza, así que **el real-time es el follow-up natural** de este
  dominio, no parte del MVP. Los correos de sistema (OTP/invitación) siguen por `ApplicationMailer`,
  no por este dominio.
- **Nota de frontera con `assignments`**: la comunicación *notifica* sobre una asignación (anuncio "hay
  salida el viernes"), pero el ítem asignable, su vencimiento, materiales y consentimiento viven en
  `assignments` — no se mezclan. Un anuncio puede *enlazar* a una asignación.

### 4.5 `attendance` — asistencia (addon) — **net-new, checkpoint de diseño** — ✅ construido (v1.16.0)
No existe en el mapa de dominios (v1.14.0): cero tablas, es modelado nuevo. Forma propuesta (a
validar en el checkpoint):
- **`attendance_records`**: `student_id`, `date`, `status` (`present`/`absent`/`late`/`excused`),
  `recorded_by_staff_member_id`, `group_id` (asistencia **diaria por homeroom**, recomendado para
  K-12) — con nota opcional. Un registro por `(student, date[, session])`.
- **Dónde vive — decisión abierta (§9)**: (a) `schedules` (por materia/sesión, típico de superior),
  (b) `group_management` (diaria por homeroom), o (c) dominio `attendance` propio. **Recomendado:**
  diaria por homeroom como dominio propio; por-materia diferido.
- **RBAC + scope (molde #4)**: el docente registra asistencia de **sus grupos**; coordinación ve todo.
- **Portal del cuidador (relación)**: el acudiente ve la asistencia de su hijo. Ausencias pueden
  *derivar* una notificación (`communication`) — sin acoplar los dominios.

> **Cómo quedó construido**: decisión §9-5 resuelta a favor de **(c) dominio `attendance` propio**,
> diaria por homeroom, tal como recomendaba esta guía. `AttendanceRecord` único por
> `(institution_id, student_id, date)`, consume `Schedules::ActiveTermEnrollmentScope` (nunca re-deriva
> el join a término). Por-materia sigue diferido. Ver `HISTORIA.md` v1.16.0.

### 4.6 Notas / boletines — **NO es dominio nuevo: `schedules` ya tiene la libreta** — ✅ boletines construidos (`report_cards`, v1.17.0)
v1.14.0 dejó `Subject`/`Enrollment`/`Assessment` reales con registro de nota en `schedules`. El MVP
**no construye la libreta**, construye encima:
- **Agregación → boletines**: promedios/consolidado por estudiante/término a partir de `Assessment`.
- **Mostrar en el portal del cuidador**: el acudiente ve las notas de su hijo (relación, sin buscador).
- No inventar un dominio `grades` paralelo — la libreta vive en `schedules`, aunque el nombre chirríe.

> **Cómo quedó construido**: `ReportCards` es dominio propio addon-gated que **lee** `schedules` por
> FK (nunca posee `Subject`/`Enrollment`/`Assessment`) — `ReportCard` único por
> `(institution_id, student_id, academic_term_id)`, snapshot congelado al publicar
> (`lines_snapshot`+`overall_average`, nunca recomputado). Portal solo ve publicados. Asistencia en el
> boletín y escala Decreto 1290 quedan diferidas. Ver `HISTORIA.md` v1.17.0.

### 4.7 `finance` — pago manual en tesorería — **model-ready, falta UI** — ✅ UI construida (v1.18.0)
v1.14.0: modelos reales (`Charge`/`Payment`/`PaymentPlan`/`Installment`/`StudentAccount`), cero vista.
- **UI de tesorería**: listar cargos/estado de cuenta por estudiante, **registrar un pago manual**
  contra un cargo (efectivo/transferencia registrada a mano). **Sin pasarela** — post-MVP.
- **Actividad extracurricular paga** = un `Charge` en `finance` (no un cobro propio de
  `extracurriculars`).
- Es construir desde cero (rutas/controller/nav/vistas) sobre modelos que ya existen — no swap de stub.
  RBAC: rol de tesorería/administración; dato financiero, cuidado con exposición.

---

## 5. Roles y permisos nuevos (sobre el catálogo existente) — ✅ todos construidos

| Rol / permiso | Para qué | Notas |
|---|---|---|
| `activity_coordinator` / `activity.manage` | Gestiona el catálogo de actividades y todas las inscripciones | Scope institución-wide. ✅ Real (v1.27.0). |
| `activity_instructor` / `activity.instruct` | Ve/gestiona el roster de su actividad | ✅ **Resuelto**: propiedad de fila (`instructor_staff_member_id`), no un `scope_type` nuevo — ver §4.1/§9-3. |
| `announcement.send` (permiso) | Enviar anuncios/hilos a acudientes | Coordinación/homeroom/dirección. ✅ Real (v1.19.0). |
| `calendar.manage` (permiso) | Crear/editar eventos del calendario | Con scope (un homeroom publica a su grupo; dirección, institución-wide). ✅ Real (v1.27.0), tres ramas de `authorize!`. |
| `assignment.manage` (permiso) | Crear/gestionar asignaciones académicas (tareas/trabajos/salidas) | Docente sobre **sus grupos** (scope, molde #4); jefe de área, su departamento. ✅ Real (v1.21.0+). |
| `attendance.record` (permiso) | Registrar asistencia | Docente/homeroom sobre **sus grupos** (scope, molde #4); coordinación ve todo. ✅ Real (v1.16.0). |
| `grades.manage` / `report_card.view` / `report_card.publish` (permisos) | Registrar notas / ver-publicar boletines | Docente sobre sus materias/grupos. ✅ Real (v1.14.0/v1.17.0). |
| `finance.read` / `finance.write` (permisos) | Registrar pagos manuales, ver estados de cuenta | Rol de tesorería/administración; dato financiero, exposición cuidada. ✅ Real (v1.18.0) — nombre final distinto del `treasury.manage` propuesto aquí, ya existían y los reusaba `Cafeteria::BalancesController`. |

> Los acudientes/estudiantes **no** reciben roles nuevos: acceden por relación (portal). Invariante
> del proyecto — no agregar un rol "para que el portal funcione". Se cumplió en todos los slices.

---

## 6. Alcance del MVP: dentro vs. diferido

### DENTRO — ✅ los 10 ítems cerrados (camino crítico completo desde v1.29.0)
- ~~**Matrícula / término**: cerrar el join `enrollments`↔`academic_terms` (B2/Cav.) — parcial hoy
  (`students.section_id` ya escribe real). Dependencia dura de casi todo lo demás.~~ ✅ **v1.15.0**.
- ~~**Asistencia** (`attendance`, net-new): registro diario + visible al cuidador.~~ ✅ **v1.16.0**.
- ~~**Notas / boletines**: agregación sobre la libreta ya real de `schedules` + mostrarla al
  cuidador.~~ ✅ **v1.17.0**.
- ~~**Pago manual en tesorería** (`finance`, model-ready): UI de registrar pago. Sin pasarela.~~
  ✅ **v1.18.0**.
- ~~**`communication`** dos vías: interna Campfire (rooms + DM) + externa (anuncios + "correos" al
  acudiente).~~ ✅ **v1.19.0/v1.20.0**.
- ~~**`assignments`** (asignaciones académicas): tareas, trabajos grupales y salidas pedagógicas con
  fecha, materiales, targeting por scope y seguimiento/consentimiento.~~ ✅ **v1.21.0–v1.26.0**, pero
  **acotado a tareas por materia** (`subject_id`, sin `kind`/targeting genérico); track completo
  incluyendo rúbricas (no previstas en el diseño original) y entregas individuales/grupales. **Salidas
  pedagógicas y consentimiento bloqueante NUNCA se construyeron** — ver §4.3/§9-1.
- ~~**`calendar`** con visibilidad relación-gated para el cuidador.~~ ✅ **v1.27.0**.
- ~~**`extracurriculars`** (deportes/artes/refuerzo): catálogo, inscripción con cupo, instructor,
  horario propio; actividad paga = un `Charge` en `finance`.~~ ✅ **v1.27.0**.
- ~~**Portal del cuidador ampliado**: notas, asistencia, actividades, calendario, asignaciones (con
  consentimiento de salidas) y mensajes de sus hijos.~~ ✅ **v1.28.0** — sin el consentimiento de
  salidas, que nunca se construyó (ver arriba).
- ~~**Provisioning de instituciones** (crear el tenant del colegio desde el control plane) — hoy
  read-only.~~ ✅ **v1.29.0** — `Provisioning::ProvisionInstitution` crea la institución Y su primer
  `institution_admin`.
- ~~**Proveedor de correo real** (para que invitaciones/anuncios/OTP lleguen).~~ ✅ **v1.29.0** —
  SMTP genérico vía credentials/ENV.

### DIFERIDO — qué sigue diferido vs. qué se construyó después como trabajo post-MVP

**Se construyó después (Fase D y otras, fuera del alcance de este MVP pero ya real en el repo):**
- ~~Asistencia **por materia/sesión**~~ — sigue diferida (el MVP hace diaria por homeroom, sin cambios).
- `schedules` como **timetabling** general (rooms/patrones) — ✅ real desde **v1.50.0**
  (`Schedules::Room`/`MeetingPattern`; conflicto de salón calculado en lectura, nunca bloqueado en BD).
- `student_support` (convivencia + historia médica/alergias/acomodaciones) — ✅ real desde
  **v1.45.0/v1.48.0**.
- `cafeteria` (menú/compra/saldo + bloqueo por alérgeno) — ✅ real desde **v1.47.0/v1.51.0**.
- `transportation` (rutas/paradas/pasajeros/abordaje) — ✅ real desde **v1.49.0**.
- `library` y `admissions` — dominios greenfield que no estaban ni contemplados en este documento,
  ✅ reales desde **v1.54.0/v1.55.0/v1.56.0**.
- Metering real por dominio (S3b/M1) — ✅ cableado para la mayoría de dominios de negocio
  (v1.30.0/v1.52.0); queda abierto solo para `student_support`/`counseling`/`analytics_bi`/
  `schedules`-timetable (sin evento de negocio claro todavía).
- `analytics_bi` — ✅ construido como iniciativa propia (8 lentes del "Sistema de Posicionamiento
  Humano", v1.34.0–v1.46.0), fuera del alcance original de este documento — ver `BI_DOCUMENT.md`
  (manda sobre este documento para ese dominio).

**Sigue genuinamente diferido / confirmado como no-goal:**
- **Tiempo real** (Turbo Streams/Cable) en comunicación (Campfire en vivo) y transporte — sigue
  ⛔ gateado, sin driver real todavía (ver `OPEN_PROCESS.md` #2).
- **Pasarela de pago** (integración de cobro automático) — no-goal confirmado, tanto en `finance`
  (tenant) como en billing de plataforma; el registro **manual** de un abono sí es real
  (`ControlPlane::Payment`, v1.59.0).
- MFA fuerte — sigue sin construir.

> El resto de la evolución post-MVP (RBAC intra-plano del control plane, schedule recurrente,
> hardening de billing, `BillingPeriod`, batch-invite de onboarding) vive fuera del alcance de este
> documento — ver `PROJECT_STATE.md` (metadatos de versión) y `OPEN_PROCESS.md` para el backlog vivo.

---

## 7. Camino crítico (orden sugerido de slices)

> Reordenado con v1.14.0 (notas medio hecha, matrícula parcial, finance model-ready) y las decisiones
> de asistencia/notas/pago manual/Campfire.

1. ~~**Matrícula / término**~~ — ✅ **cerrado (v1.15.0)**: cerró el join `enrollments`↔`academic_terms`
   (B2/Cav., mitad de modelo) vía `Schedules::ActiveTermEnrollmentScope`. Ver `PROJECT_STATE.md`/`HISTORIA.md`.
2. ~~**Asistencia**~~ (`attendance`, net-new + checkpoint de diseño) — ✅ **cerrado (v1.16.0)**: el
   loop diario, dominio propio addon-gated. Ver `PROJECT_STATE.md`/`HISTORIA.md`.
3. ~~**Notas → boletines + portal**~~ (`report_cards`, net-new) — ✅ **cerrado (v1.17.0)**: dominio
   propio addon-gated que lee `schedules` por FK; snapshot congelado al publicar; portal solo
   publicados. Ver `PROJECT_STATE.md`/`HISTORIA.md`.
4. ~~**Pago manual en tesorería**~~ (`finance`) — ✅ **cerrado (v1.18.0)**: UI real sobre los 5
   modelos ya existentes (lectura + registrar pago/cargo, dos superficies); planes de pago diferidos.
   Ver `PROJECT_STATE.md`/`HISTORIA.md`.
5. ~~**`communication`**~~ — ✅ **completo (ambos subsistemas).** Anuncios (subsistema A, difusión
   org-wide) ✅ **cerrado (v1.19.0)**. Mensajería (subsistema B: conversaciones multiparte,
   auditoría confidencial-pero-auditable) ✅ **núcleo cerrado (v1.20.0)** — cuatro caminos de
   acceso (compose RBAC / bandeja-participación / responder-participación / auditoría RBAC).
   Diferidos anotados (fan-out 1:1 a todos los cuidadores, threading, tags, acudiente-inicia) — ver
   `PROJECT_STATE.md` §8.2/`HISTORIA.md`.
6. **`assignments`** (tareas académicas) — ✅ **TRACK COMPLETO, slices 1–4/4.** ~~Publicar +
   ver + calificar directo~~ ✅ **cerrado (v1.21.0)**. ~~Entrega de texto~~ ✅ **cerrado (v1.22.0)**.
   ~~Entregas grupales~~ ✅ **cerrado (v1.23.0)**: `group_work` toggle por-tarea, `Submission`
   generalizada a estudiante XOR grupo, nota grupal = bulk-set per-student + override individual
   (sin almacén grupal aparte), entrega compartida editable por cualquier integrante. ~~Adjuntos de
   entrega~~ ✅ **cerrado (v1.24.0)**: docx/pdf/jpg/png (≤10MB, ≤5) sobre una `Submission` ya
   existente, tabla puente tenant-scoped (Active Storage crudo sin RLS), content-type real vía
   Marcel, tres controllers de servicio (nunca las rutas firmadas default). ~~Materiales del
   docente~~ ✅ **cerrado (v1.25.0)**: mismo molde de tabla puente, dueño `Assignment`; escritura
   gateada por RBAC (`assignment.manage`, 403 sin permiso) en vez de relación de portal; lectura de
   portal sin cambios (borrador/archivada inalcanzables gratis). ~~Rúbricas~~ ✅ **cerrado (v1.26.0)**:
   biblioteca reutilizable normalizada, asociada vía `evaluation_method` (freeze molde `group_work`),
   estructura congelada como snapshot jsonb al publicar (molde `price_tiers_snapshot`); calificar
   por rúbrica calcula y escribe la nota vía `GradeRecorder`/`GroupGrader` sin cambios — la rúbrica
   nunca almacena la nota; portal ve nivel+descriptor por criterio, sin RBAC. Roadmap completo en
   `HISTORIA.md` v1.21.0–v1.26.0. ~~**Siguiente ítem del camino crítico**: `calendar` (net-new) o
   `extracurriculars`~~ → `calendar` **✅ cerrado (v1.27.0)**; sigue `extracurriculars` — ver `OPEN_PROCESS.md`.
7. ~~**`calendar`** + scope de visibilidad del cuidador (consume fechas de `assignments`, `attendance`,
   `extracurriculars`).~~ ✅ **cerrado (v1.27.0)** — audiencia por dos columnas de scope (institución-wide/
   grado/grupo, sin `kind`), tres ramas de `authorize!` sobre `calendar.manage`, merge de los `due_date`
   de `assignments` SOLO en el portal (`Calendar::Timeline`). `attendance`/`extracurriculars` como fuentes
   de fecha quedan diferidos (assignments es el único consumo real hoy). Ver `HISTORIA.md` v1.27.0.
8. ~~**`extracurriculars`**~~ ✅ **cerrado (v1.27.0)** — ver `OPEN_PROCESS.md`/`HISTORIA.md`.
9. ~~**Portal del cuidador ampliado**~~ ✅ **cerrado (v1.28.0)**: un recon confirmó que
   notas/actividades/calendario/asignaciones/mensajes ya colgaban reales del portal desde sus propios
   slices (v1.17.0–v1.27.0) — el único hueco real era `attendance` (v1.16.0), cerrado con
   `Attendance::StudentView` + los controllers de portal correspondientes. Ver `HISTORIA.md` v1.28.0.
10. ~~**Provisioning de instituciones** + proveedor de correo real (habilitan el alta del colegio piloto).~~
    ✅ **cerrado (v1.29.0) — CAMINO CRÍTICO DEL MVP COMPLETO.** `Provisioning::ProvisionInstitution`
    (un solo flujo) crea la institución Y bootstrapea su primer `institution_admin` real
    (`IdentityAccess::Bootstrap::FirstAdmin`); correo real vía SMTP genérico (credentials/ENV, sin
    gema de proveedor). Ver `HISTORIA.md` v1.29.0.

> Cada uno es un slice con recon-first; los dominios net-new (`attendance`, `assignments`, `calendar`,
> `extracurriculars`), con checkpoint de diseño (como CHECKPOINT E). Los sensibles siguen aparte.

---

## 8. Consideraciones legales (Colombia — menores, Habeas Data) — reforzadas para este MVP

- **Comunicación con acudientes** sobre menores: relación-gated (solo sobre sus hijos), auditada, sin
  exponer directorios ni permitir contactar a acudientes de otros menores.
- **Calendario y asignaciones**: la visibilidad del cuidador se resuelve por relación
  (`guardian_students`), nunca por búsqueda; el evento/asignación de un menor no es enumerable
  por quien no es su acudiente.
- ~~**Consentimiento de salidas pedagógicas** — `assignments.requires_consent` + acuse por acudiente,
  no un flag silencioso; sin consentimiento se **bloquea** la participación del menor; queda registro
  auditable.~~ ❌ **Nunca construido** — `assignments` quedó acotado a tareas por materia (ver §4.3/
  §9-1); no hay ninguna columna de consentimiento ni bloqueo de salidas en el repo real. El único
  primitivo de consentimiento real del codebase es `AnalyticsBi::CharacterProgramConsent` (v1.39.0,
  consentimiento para el instrumento de carácter/pares, dominio distinto). Si el colegio necesita
  consentimiento bloqueante de salidas pedagógicas, sigue siendo trabajo por diseñar.
- **PII mínima** en toda superficie del cuidador; `national_id` nunca en vista (regla vigente).

---

## 9. Decisiones a confirmar antes de modelar

1. ~~**Forma de "responsabilidades"**~~ — ✅ **Resuelto:** asignaciones académicas (tareas, trabajos
   grupales, salidas pedagógicas) como **dominio propio `assignments`** con fecha/materiales/targeting/
   seguimiento (§4.3). Sub-decisiones que quedan de este dominio:
   - ~~**Nombre del dominio**: `assignments` vs. otro (p. ej. `coursework`/`academics`) — confirmar.~~
     ✅ **Resuelto en la práctica**: quedó `assignments`, y el modelo real es `Assignments::Assignment`.
   - ~~**Profundidad del trabajo grupal**: ¿solo "asignado a un grupo + estado", o hace falta espacio
     de entrega/colaboración?~~ ✅ **Resuelto, más rico que el mínimo recomendado**: v1.22.0–v1.24.0
     construyeron entrega de texto + adjuntos (individual y grupal), no solo tracking de estado — el
     submission workspace de colaboración en vivo sigue diferido.
   - ~~**Consentimiento bloqueante**~~: ❌ **NUNCA se construyó** — el dominio real quedó acotado a
     *tareas por materia* (`Assignments::Assignment.subject_id`), sin `kind`, sin `field_trip`, sin
     `requires_consent`. `grep requires_consent` contra `db/structure.sql` no devuelve nada (confirmado
     por el propio repo en v1.39.0, al citar por error este molde como precedente). Si "salidas
     pedagógicas + consentimiento del acudiente" sigue siendo un requisito de negocio, es un slice
     nuevo por diseñar — no algo que este documento pueda dar por hecho.
2. ~~**Inscripción a actividades** — ¿la hace el acudiente desde el portal, o solo el colegio?~~
   ✅ **Resuelto: ambas vías** (`Extracurriculars::Enrollment.enrolled_via` staff/guardian). Ver v1.27.0.
3. ~~**Scope del instructor de actividad** — ¿nuevo tipo de alcance `scope_activity_id` en
   `role_assignments`, o per-row `can?` sobre las actividades que instruye?~~ ✅ **Resuelto: per-row**
   — `Extracurriculars::ActivityScope` filtra directo por `instructor_staff_member_id`, nunca un
   `scope_type` nuevo en `role_assignments`. Ver v1.27.0.
4. ~~**Actividades pagas**~~ — ✅ **Resuelto:** **todo pago es manual en tesorería** (`finance`
   model-ready, sin pasarela); actividad paga = un `Charge`. Pasarela de pago, post-MVP.
5. ~~**Asistencia y notas**~~ — ✅ **Resuelto: ambas DENTRO.** Notas = agregación sobre la libreta ya
   real de `schedules` (§4.6). Asistencia = dominio net-new (§4.5). **Nueva sub-decisión abierta:**
   - **Dónde vive la asistencia**: (a) `schedules` por materia/sesión, (b) `group_management` diaria
     por homeroom, o (c) dominio `attendance` propio. **Recomendado (c) diaria por homeroom**;
     por-materia diferido. Confirmar en el checkpoint de diseño del slice.
6. ~~**Alcance de "comunicación interna"**~~ — ✅ **Resuelto: dos vías, estilo Campfire** — interna =
   rooms (`channel`) + DM (`direct`); externa = anuncios públicos (`announcement`) + "correos"
   internos al acudiente (`parent_thread`, bandeja, no email real). Tiempo real diferido (follow-up).

---

## 10. Encaje con lo ya construido — estructura final lograda (MVP cerrado en v1.29.0)

> Reescrita a estado final. La versión original de esta sección (encaje con v1.14.0) queda superada
> por el hecho de que los 10 ítems del camino crítico ya cerraron — ver §7.

- **Reutilizado tal cual, sin cambios:** identidad (login/MFA/invitaciones), roster CSV (estudiantes +
  acudientes), RBAC+scope (`PermissionCheck`), entitlement (encender los addons de este colegio),
  portales de persona (`GuardianScope`/`StudentSelfScope`), staff generalizado (instructores),
  autoservicio de staff, auditoría append-only, y el molde de vistas de negocio §6.6 reusado por
  todos los dominios nuevos.
- **Construido encima de lo medio-hecho de v1.14.0:** **notas → boletines** (`report_cards`, v1.17.0,
  lee `schedules::Assessment` por FK); **matrícula → término** (`Schedules::ActiveTermEnrollmentScope`,
  v1.15.0, cierra el join `enrollments`↔`academic_terms`); **pago manual** (UI de tesorería sobre los
  modelos `finance` ya existentes, v1.18.0).
- **Activado de stub a real:** `communication`, ambos subsistemas (anuncios v1.19.0, mensajería
  v1.20.0).
- **Creados net-new (esquema nuevo, con checkpoint de diseño), los 4 dominios previstos:**
  `attendance` (v1.16.0), `calendar` (v1.27.0), `extracurriculars` (v1.27.0), y `assignments`
  (v1.21.0–v1.26.0) — este último **más angosto** que la forma propuesta (tareas por materia, sin
  salidas pedagógicas ni consentimiento bloqueante — ver §4.3/§9-1/§8).
- **Habilitada la operación del SaaS:** provisioning de instituciones + correo real (v1.29.0) — cierre
  del camino crítico completo del MVP.
- **Lo que este documento marcaba "Clase C, diferido sin costo" se construyó igual, como trabajo
  post-MVP** (Fase D, fuera del alcance de este perfil de cliente pero ya real en el repo):
  `student_support` (v1.45.0/v1.48.0), `cafeteria` (v1.47.0/v1.51.0), `transportation` (v1.49.0),
  timetable de `schedules` (v1.50.0). Además, dos dominios greenfield que no estaban ni contemplados
  aquí: `library` (v1.54.0) y `admissions` (v1.55.0/v1.56.0). Todo esto vive fuera del perfil de
  cliente de este documento — ver `PROJECT_STATE.md`/`HISTORIA.md` para el detalle.
