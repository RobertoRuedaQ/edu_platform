# Lineamientos de MVP — Colegio K-12 (extracurriculares · comunicación · responsabilidades · calendario del cuidador)

> **Qué es este documento.** Fija el **alcance y los lineamientos** de un primer MVP de `edu_platform`
> para un perfil de cliente concreto. Traduce cada función pedida a la arquitectura ya existente,
> propone la forma de los dominios nuevos (respetando los invariantes del proyecto), y separa lo que
> entra del MVP de lo diferible. **No es un prompt de implementación** — es la guía que alimenta los
> slices siguientes. Cada dominio nuevo, cuando se construya, sigue igual la disciplina recon-first.
>
> Se apoya en el estado `v1.12.0`+ (identidad, RBAC+scope, entitlements, portales de persona, staff
> generalizado, auditoría — todo real). Ante discrepancia con el magro/`HISTORIA.md`, gana el repo.

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
| **Extracurriculares** (deportes/artes/refuerzo) | `extracurriculars` (nuevo, addon) | No existe | Dominio nuevo: actividades, inscripción de estudiantes, instructor (StaffMember), horario/cupo. |
| **Comunicación interna** (staff↔staff) | `communication` | Diseño en stub (§8 magro) | Migrar `conversations`/`messages`/`participants`; canales/directos internos. |
| **Comunicación externa** (colegio↔acudiente) | `communication` | Diseño en stub | `parent_thread` + `announcement`; participante = `institution_user` **o** `guardian` (ya diseñado, CHECK exactamente-uno). Superficie en el portal del cuidador. |
| **Asignaciones académicas** (tareas, trabajos grupales, salidas pedagógicas) | `assignments` (nuevo, addon) | No existe | Dominio propio: item con `kind`, fecha, materiales, a-quién-se-asigna (columnas de scope explícitas), y seguimiento/consentimiento. Ver §4.3. |
| **Calendario compartido con cuidadores** | `calendar` (nuevo, addon) | No existe | Eventos con audiencia/visibilidad; el acudiente ve los relativos a sus hijos + los del colegio. |
| **Notas / calificaciones** | `schedules` (libreta) | ⚠️ **Medio construido** (v1.14.0): `Subject`/`Enrollment`/`Assessment` reales con registro de nota | **No construir de cero.** Falta: agregación → **boletines** + **mostrar en el portal del cuidador**. (Naming: la libreta vive en `schedules`, es lo que hay en disco.) |
| **Asistencia** | `attendance` (nuevo) **o** `group_management`/`schedules` | ❌ **Net-new** — no está en el mapa, cero tablas | Slice de **modelado con checkpoint de diseño**. Dónde vive = decisión §9. |
| **Pagos (manual, tesorería)** | `finance` | ⚠️ **Model-ready** (v1.14.0): `Charge`/`Payment`/`PaymentPlan`/`Installment`/`StudentAccount` reales, **cero vista** | Construir **UI de registrar pago manual** (no swap de stub, es desde cero). Sin pasarela (post-MVP). Actividad paga = un `Charge`. |
| **(Dependencia dura) Matrícula / término** | `core` + `group_management` + `schedules` | ⚠️ **Parcial** (v1.14.0): `students.section_id` (asignación a grupo) ya escribe real; existe `Schedules::Enrollment`; falta el join `enrollments`↔`academic_terms` (B2/Cav.) | **Cerrar el vínculo con `academic_terms`** ("el estudiante en este término" first-class). Menos greenfield de lo asumido — no es construir matrícula de cero. Sigue siendo el desbloqueo de casi todo. |
| **(Reutilizado) Acceso del cuidador** | `core` (`GuardianScope`) | ✅ Real (v1.9.0) | Nada — es la base sobre la que se cuelga todo lo externo. |
| **(Reutilizado) Alta de personas / roster CSV** | `identity_access`/`core` | ✅ Real | Nada. |

---

## 4. Dominios / conceptos nuevos (forma propuesta — aburrida, tenant-scoped, RLS)

> Formas de referencia, no esquema final. Cada una se recon-ea contra el disco al construirse y
> respeta: `institution_id` + RLS FORCE, UUIDv7, sin `default_scope`, dinero en `*_cents` si aplica.

### 4.1 `extracurriculars` (addon)
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

### 4.2 `calendar` (addon)
- **`calendar_events`**: `title`, `starts_at`/`ends_at`, `kind` (`school_event`/`activity`/`deadline`/
  `term`), `visibility`/audiencia (institución-wide / por grado / por grupo / por actividad), FK
  opcional a `activity`/`assignment`/`academic_term`.
- **Visibilidad para el cuidador por relación**, no por RBAC: un acudiente ve los eventos institución-
  wide + los del grado/grupo/actividades **de sus hijos** — resuelto con el mismo patrón que
  `GuardianScope` (un `Core::Access::…Scope` propio del calendario), sin buscador.
- **Staff** crea/edita eventos (RBAC + scope). Los vencimientos de `assignments` y los horarios de
  actividades se **derivan** en el calendario en vez de duplicarse.

### 4.3 `assignments` — asignaciones académicas (addon) — **DECISIÓN RESUELTA**
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

### 4.4 `communication` (activar el stub)
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

### 4.5 `attendance` — asistencia (addon) — **net-new, checkpoint de diseño**
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

### 4.6 Notas / boletines — **NO es dominio nuevo: `schedules` ya tiene la libreta**
v1.14.0 dejó `Subject`/`Enrollment`/`Assessment` reales con registro de nota en `schedules`. El MVP
**no construye la libreta**, construye encima:
- **Agregación → boletines**: promedios/consolidado por estudiante/término a partir de `Assessment`.
- **Mostrar en el portal del cuidador**: el acudiente ve las notas de su hijo (relación, sin buscador).
- No inventar un dominio `grades` paralelo — la libreta vive en `schedules`, aunque el nombre chirríe.

### 4.7 `finance` — pago manual en tesorería — **model-ready, falta UI**
v1.14.0: modelos reales (`Charge`/`Payment`/`PaymentPlan`/`Installment`/`StudentAccount`), cero vista.
- **UI de tesorería**: listar cargos/estado de cuenta por estudiante, **registrar un pago manual**
  contra un cargo (efectivo/transferencia registrada a mano). **Sin pasarela** — post-MVP.
- **Actividad extracurricular paga** = un `Charge` en `finance` (no un cobro propio de
  `extracurriculars`).
- Es construir desde cero (rutas/controller/nav/vistas) sobre modelos que ya existen — no swap de stub.
  RBAC: rol de tesorería/administración; dato financiero, cuidado con exposición.

---

## 5. Roles y permisos nuevos (sobre el catálogo existente)

| Rol / permiso | Para qué | Notas |
|---|---|---|
| `activity_coordinator` | Gestiona el catálogo de actividades y todas las inscripciones | Scope institución-wide. |
| `activity_instructor` | Ve/gestiona el roster de su actividad | Scope por actividad (nuevo tipo de alcance) **o** reusar staff + per-row `can?`. **Decisión de scope a confirmar.** |
| `announcement.send` (permiso) | Enviar anuncios/hilos a acudientes | Coordinación/homeroom/dirección. |
| `calendar.manage` (permiso) | Crear/editar eventos del calendario | Con scope (un homeroom publica a su grupo; dirección, institución-wide). |
| `assignment.manage` (permiso) | Crear/gestionar asignaciones académicas (tareas/trabajos/salidas) | Docente sobre **sus grupos** (scope, molde #4); jefe de área, su departamento. |
| `attendance.record` (permiso) | Registrar asistencia | Docente/homeroom sobre **sus grupos** (scope, molde #4); coordinación ve todo. |
| `grades.manage` / `report_cards.view` (permisos) | Registrar notas / ver boletines | Ya hay superficie de nota en `schedules`; el permiso de boletín es nuevo. Docente sobre sus materias/grupos. |
| `treasury.manage` (permiso) | Registrar pagos manuales, ver estados de cuenta | Rol de tesorería/administración; dato financiero, exposición cuidada. |

> Los acudientes/estudiantes **no** reciben roles nuevos: acceden por relación (portal). Invariante
> del proyecto — no agregar un rol "para que el portal funcione".

---

## 6. Alcance del MVP: dentro vs. diferido

### DENTRO
- **Matrícula / término**: cerrar el join `enrollments`↔`academic_terms` (B2/Cav.) — parcial hoy
  (`students.section_id` ya escribe real). Dependencia dura de casi todo lo demás.
- **Asistencia** (`attendance`, net-new): registro diario + visible al cuidador.
- **Notas / boletines**: agregación sobre la libreta ya real de `schedules` + mostrarla al cuidador.
- **Pago manual en tesorería** (`finance`, model-ready): UI de registrar pago. Sin pasarela.
- **`communication`** dos vías: interna Campfire (rooms + DM) + externa (anuncios + "correos" al acudiente).
- **`assignments`** (asignaciones académicas): tareas, trabajos grupales y salidas pedagógicas con
  fecha, materiales, targeting por scope y seguimiento/consentimiento.
- **`calendar`** con visibilidad relación-gated para el cuidador.
- **`extracurriculars`** (deportes/artes/refuerzo): catálogo, inscripción con cupo, instructor, horario
  propio; actividad paga = un `Charge` en `finance`.
- **Portal del cuidador ampliado**: notas, asistencia, actividades, calendario, asignaciones (con
  consentimiento de salidas) y mensajes de sus hijos.
- **Provisioning de instituciones** (crear el tenant del colegio desde el control plane) — hoy read-only.
- **Proveedor de correo real** (para que invitaciones/anuncios/OTP lleguen).

### DIFERIDO (post-MVP, sin culpa)
- Asistencia **por materia/sesión** (el MVP hace diaria por homeroom); registro académico avanzado.
- `schedules` como **timetabling** general (rooms/patrones — Clase C; las actividades usan horario propio simple).
- **Tiempo real** (Turbo Streams/Cable) en comunicación (Campfire en vivo) y transporte — follow-up natural.
- **Pasarela de pago** (integración de cobro automático) — explícitamente después del MVP.
- `student_support`/`counseling`/`cafeteria`/`transportation` reales (este perfil no los pide; el
  bloqueo por alérgeno de cafetería dependería de `student_support`, que es Clase C).
- Riel de pago del control plane, metering real (S3b/M1), MFA fuerte, `analytics_bi`.

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
5. **`communication`** (Campfire interno: rooms + DM; externo: anuncios + "correos" al acudiente).
   Columna vertebral de las notificaciones (asistencia/asignaciones derivan avisos de aquí).
   **Siguiente ítem del camino crítico.**
6. **`assignments`** (tareas/trabajos/salidas) — depende de matrícula y `group_management` (targeting
   por grupo); molde #4 para el scope del docente. Fechas se derivan al calendario.
7. **`calendar`** + scope de visibilidad del cuidador (consume fechas de `assignments`, `attendance`,
   `extracurriculars`).
8. **`extracurriculars`** (depende de matrícula/término; actividad paga = `Charge` en `finance`, de #4).
9. **Portal del cuidador ampliado** (colgar notas, asistencia, actividades, calendario, asignaciones,
   mensajes) — pequeño porque `GuardianScope` ya existe.
10. **Provisioning de instituciones** + proveedor de correo real (habilitan el alta del colegio piloto).

> Cada uno es un slice con recon-first; los dominios net-new (`attendance`, `assignments`, `calendar`,
> `extracurriculars`), con checkpoint de diseño (como CHECKPOINT E). Los sensibles siguen aparte.

---

## 8. Consideraciones legales (Colombia — menores, Habeas Data) — reforzadas para este MVP

- **Comunicación con acudientes** sobre menores: relación-gated (solo sobre sus hijos), auditada, sin
  exponer directorios ni permitir contactar a acudientes de otros menores.
- **Calendario y asignaciones**: la visibilidad del cuidador se resuelve por relación
  (`guardian_students`), nunca por búsqueda; el evento/asignación de un menor no es enumerable
  por quien no es su acudiente.
- **Consentimiento de salidas pedagógicas** — `assignments.requires_consent` + acuse por acudiente,
  no un flag silencioso; sin consentimiento se **bloquea** la participación del menor; queda registro
  auditable.
- **PII mínima** en toda superficie del cuidador; `national_id` nunca en vista (regla vigente).

---

## 9. Decisiones a confirmar antes de modelar

1. ~~**Forma de "responsabilidades"**~~ — ✅ **Resuelto:** asignaciones académicas (tareas, trabajos
   grupales, salidas pedagógicas) como **dominio propio `assignments`** con fecha/materiales/targeting/
   seguimiento (§4.3). Sub-decisiones que quedan de este dominio:
   - **Nombre del dominio**: `assignments` vs. otro (p. ej. `coursework`/`academics`) — confirmar.
   - **Profundidad del trabajo grupal**: ¿solo "asignado a un grupo + estado", o hace falta espacio de
     entrega/colaboración? (Recomendado: solo tracking en el MVP; el submission workspace, diferido.)
   - **Consentimiento bloqueante**: confirmar que una salida sin consentimiento del acudiente
     efectivamente impide la participación del menor (regla de negocio propuesta).
2. **Inscripción a actividades** — ¿la hace el acudiente desde el portal, o solo el colegio?
3. **Scope del instructor de actividad** — ¿nuevo tipo de alcance `scope_activity_id` en
   `role_assignments`, o per-row `can?` sobre las actividades que instruye?
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

## 10. Encaje con lo ya construido (para no rehacer)

- **Reutilizar tal cual:** identidad (login/MFA/invitaciones), roster CSV (estudiantes + acudientes),
  RBAC+scope (`PermissionCheck`), entitlement (encender los addons de este colegio), portales de
  persona (`GuardianScope`/`StudentSelfScope`), staff generalizado (instructores), autoservicio de
  staff, auditoría append-only, y el molde de vistas de negocio §6.6 (para las vistas internas de los
  dominios nuevos).
- **Construir encima de lo medio-hecho (v1.14.0):** **notas** (la libreta `Schedules::Assessment` ya
  es real → falta boletines + portal); **matrícula** (`students.section_id` ya escribe → falta el join
  con `academic_terms`, B2); **pago manual** (`finance` model-ready → falta solo la UI de tesorería).
- **Activar:** `communication` (de stub a real, dos vías Campfire).
- **Crear (esquema nuevo, checkpoint de diseño):** `attendance` (asistencia), `assignments`
  (asignaciones académicas), `calendar`, y `extracurriculars`.
- **Habilitar operación del SaaS:** provisioning de instituciones + correo real.
- **No aplica a este perfil (Clase C, diferido sin costo):** `student_support` (médico/alérgenos),
  `cafeteria`, `transportation`, timetable de `schedules`.
