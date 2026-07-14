# edu_platform — HISTORIA (archivo append-only)

> Archivo append-only del proyecto `edu_platform`. Changelog completo + narrativas de slices +
> decisiones cerradas/supersedidas. El estado vivo está en `PROJECT_STATE.md`. Se carga solo cuando
> hace falta el *por qué* de algo — no para decidir el próximo slice.
>
> **Nada aquí se reescribe ni se resume respecto al doc de origen** (`PROJECT_STATE.md` v1.5.0, antes
> del split editorial v1.5.1) — es copia literal, archivada porque es narrativa/histórica, no porque
> se haya "mejorado". Si algo contradice el repo, gana el repo; esto documenta intención y contexto
> pasado, no el estado actual del código.

---

## Changelog completo (v1.0.0 → v1.14.0)

> Copiado verbatim de §14 de `PROJECT_STATE.md` v1.5.0, antes de que el split editorial (v1.5.1)
> moviera el changelog fuera del doc magro. Las entradas v1.6.0+ se escribieron directamente aquí,
> ya con el split vigente.

### v1.14.0 — 2026-07-14 — #4 barrido: el molde de teacher_management aplicado a todos los dominios cableables

**Barrido de cierre del backlog #4.** Con el molde canónico ya probado en `teacher_management`
(v1.13.0), este slice lo aplicó, dominio por dominio, a todo lo que el disco realmente soportaba —
con un STOP de triage obligatorio antes de tocar código, y una pausa adicional cuando el usuario
decidió incluir dominios sensibles fuera del default del prompt.

**Triage (STOP #1/#2) — la tabla real, no la asumida:**

| Dominio | Clase | Por qué |
|---|---|---|
| `core` | N/A | Sin controllers propios — sus recursos de negocio ya viven en otros dominios. |
| `group_management` | **A** | `Section`/`Student` reales, `grade_level_id`/`section_id` ya reales. |
| `schedules` (calificaciones) | **A** | `Subject`/`Enrollment`/`Assessment` reales, `grade_level_id` real. |
| `schedules` (horario/timetable) | **C** | Cero tabla real (`rooms`/`meeting_patterns` no existen) — mismo hallazgo que v1.10.0/v1.12.0. |
| `cafeteria` | **C** | Solo `DietaryRestriction` es real; menú/checkout/saldo no tienen tabla propia. |
| `transportation` | **C** | Cero modelos reales — ni un archivo en `models/`. |
| `finance` | **A, pero distinto** | Modelos reales (`Charge`/`Payment`/`PaymentPlan`/`Installment`/`StudentAccount`), **cero controller/ruta/vista** — construir desde cero, no swapear un stub. Diferido. |
| `student_support` | **C (corregido)** | Ver hallazgo abajo — el recon inicial lo marcó "S" por error. |
| `counseling` | **S → incluido a pedido del usuario** | Real (`counseling_cases`/`session_notes`/`referrals`), con caso de seguridad dedicado. |

**El hallazgo que corrigió el triage a mitad de slice:** el recon inicial (§1) asumió que
`student_support` era Clase S (sensible pero cableable) porque tiene `queries/disciplinary_log_scope.rb`,
`services/{accommodation,disciplinary_log,medical_history}_roster.rb` con nombres que sonaban a
"casi reales". Un `grep create_table` exhaustivo contra **todas** las migraciones reveló que
**ninguna de las tres tablas (`disciplinary_logs`, `medical_history`, `accommodations`) existe en
absoluto** — ni siquiera parcialmente. Solo `guardian.rb`/`student_guardian.rb` (relación con
acudientes, no las tres superficies sensibles) son reales en ese dominio. Esto se comunicó
explícitamente al usuario a mitad de ejecución (tras haber preguntado si incluir "student_support Y
counseling") y se corrigió el alcance: `student_support` pasó a Clase C (no cableable sin inventar
esquema, mismo trato que `transportation`), `counseling` (que SÍ tiene tablas reales) se cableó como
se había pedido. **Lección durable**: la señal de "tiene modelos reales" es `grep create_table` en
`db/migrate/`, nunca la presencia de un archivo de query object — un dominio entero puede estar
100% en stub con una fachada de nombres que sugiere lo contrario.

**`group_management` (Clase A):**
- `Section#group_id` (alias `id`) y `Student#group_id` (alias `section_id`, ya real) — mismo truco
  que `StaffManagement::Department#department_id`. `grade_level_id` ya era real, cero código extra.
- `GroupScope`/`StudentScope` reescritos sobre `Section`/`Student` reales, per-row `can?`, igual
  patrón que `TeacherScope`.
- **`MembershipsController#update` pasó a ser una escritura REAL** (`students.section_id`), no solo
  el gate — a diferencia de `teacher.evaluate` (v1.13.0), acá el target SÍ existe. Estudiantes
  marcados quedan en el grupo; los que estaban y se desmarcan vuelven a `section_id: nil` (nunca se
  quedan "pegados" a un grupo del que se les removió).
- Vistas: se retiraron "Director de grupo"/"Horario" (sin FK real — mismo hallazgo de siempre: no
  hay vínculo profesor↔grupo en el esquema, y `schedules` no tiene timetable real) en favor de
  "Grado"/"Año"/"Estudiantes" (reales).
- `GroupManagement::GroupRoster` se **redujo a solo sus constantes** (`SECTION_9A_ID` etc.) — siguen
  siendo load-bearing (`grant_role!` las usa para crear `Section`s reales; `cafeteria`/
  `student_support`/el `schedules` stub de horario las siguen usando como valor fijo). `StudentRoster`
  **se dejó 100% intacto** — `cafeteria`/`student_support` (ambos Clase C, no tocados) todavía la
  consumen para su propia búsqueda de "un estudiante" vía `find`.

**`schedules` — solo la mitad de calificaciones (Clase A):**
- `SubjectScope` reescrito sobre `Subject` real. **Hallazgo que contradijo el stub**: el
  `SubjectRoster` retirado escalaba por `group_id` (sección), pero el `Subject` real no tiene NINGÚN
  vínculo a sección — solo a `grade_level`/`program`. El scope real es por `grade_level`, no por
  grupo; se siguió el esquema real, no el supuesto de diseño del stub.
- **`GradeEntriesController#create` pasó a crear un `Enrollment`+`Assessment` real** (el target ya
  existía) — busca al estudiante por `student_code`, hace `find_or_create_by!` del `Enrollment`, crea
  el `Assessment`. Error amable (422, no 500) si el código no corresponde a ningún estudiante real.
- La mitad de horario/timetable (`RoomsController`/`TimetablesController`/`ScheduleEventRoster`) **no
  se tocó** — Clase C confirmada, cero tabla real.
- `SubjectRoster`/`GradeEntryRoster` retirados (cero otros consumidores, confirmado por grep).

**`counseling` (Clase S, incluida a pedido explícito + caso de seguridad dedicado):**
- `Case#group_id` delega a `student.group_id` (mismo dimensión que el stub `CaseRoster` ya asumía,
  ahora real gracias al trabajo de `group_management` en este mismo slice — dependencia de orden
  intencional). `Case#student_name` es un método de una línea.
- `CaseScope`/`CasesController` reales; el show ahora también renderiza `Referral`s reales (el
  partial `_referral_row` existía sin consumidor desde antes de este slice) además de
  `SessionNote`s reales (vía el partial `_session_note`, también preexistente y sin usar).
- **Caso de seguridad dedicado** (a pedido explícito del usuario, más allá del mini-caso estándar):
  aislamiento cross-tenant verificado con una query real a nivel de MODELO (no solo HTTP) que pide
  explícitamente `institution_id: J` bajo el GUC de I y confirma cero filas — probando que RLS
  bloquea de verdad, no solo el filtro `institution_id` de la app. Se verificó lo mismo para
  `session_notes` (no solo `counseling_cases`), ya que el README del dominio señalaba que la
  auditoría de RLS de esta tabla específicamente era "planned, not yet implemented".
- Los tests de counseling, que vivían dentro de `student_support_test.rb` desde antes de que
  `counseling` se separara como dominio propio, se extrajeron a `test/integration/counseling_test.rb`.

**Efectos secundarios encontrados y corregidos en la verificación (ningún cambio de producto, solo
tests obsoletos apuntando a stubs retirados):**
- `student_support_test.rb` tenía un test que navegaba a `/group_management/students/s-1` (el id
  stub) para verificar que las pestañas Convivencia/Acomodaciones aparecen — con `students#show`
  ahora leyendo un `GroupManagement::Student` real, "s-1" da 404. Se corrigió sembrando un estudiante
  real en la sección correcta.
- El mismo archivo tenía un test de `support_dashboard` que esperaba "1 caso abierto" contando sobre
  el `CaseRoster` retirado — se corrigió sembrando un `Counseling::Case` real.

**Resultado:** 387 runs / 1402 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
377 tras v1.13.0). `bin/rails zeitwerk:check` verde. **Cero migraciones** — cada dominio cableado ya
tenía su descriptor de scope real desde antes de este slice.

**Archivos por dominio:**
- `group_management`: modelos (`section.rb`, `student.rb`), queries (`group_scope.rb`,
  `student_scope.rb`), controllers (`students_controller.rb`, `groups_controller.rb`,
  `memberships_controller.rb`), vistas (students/groups index+show, memberships/edit), servicios
  (`group_roster.rb` reducido, `student_roster.rb` con comentario actualizado). Tests:
  `group_management_test.rb` reescrito.
- `schedules`: query (`subject_scope.rb`), controllers (`subjects_controller.rb`,
  `grade_entries_controller.rb`), vistas (subjects index+show, grade_entries/new). Retirados:
  `subject_roster.rb`, `grade_entry_roster.rb`. Tests: `schedules_test.rb` reescrito (solo la parte
  de calificaciones; horario/rooms/timetable sin cambios).
- `counseling`: modelo (`case.rb`), query (`case_scope.rb`), controller (`cases_controller.rb`),
  vista (`cases/show.html.erb`, referrals agregadas). Retirado: `case_roster.rb`. Tests: nuevo
  `counseling_test.rb`; `student_support_test.rb` con la sección de counseling removida y dos tests
  corregidos.

Con esto, el backlog #4 queda cerrado para todo lo que el esquema real soporta hoy. Lo que resta —
`cafeteria`, `transportation`, `student_support`, la mitad de horario de `schedules` — necesita un
slice de MODELADO primero (no de vistas), y `finance` necesita su propio slice de construcción de
vista/controller desde cero. Ninguno de los dos es "#4 de nuevo" en el mismo sentido que este slice.

### v1.13.0 — 2026-07-14 — #4 slice 1: `teacher_management` como referencia canónica + directorios de staff

**Primer slice del backlog #4** (vistas de negocio por dominio, dominio por dominio). El objetivo no
era "terminar `teacher_management`" — era **probar el molde de los cinco esqueletos (§6.5/§6.6) UNA
vez**, sobre el único dominio donde el descriptor de scope ya era real (P1, el caso de María), para
que los otros seis dominios lo copien después. De paso, cablea los directorios
`StaffManagement::StaffRoster`/`TeacherManagement::TeacherRoster`/`DepartmentRoster` que CHECKPOINT
E (v1.12.0) dejó model-ready pero con la vista en stub.

**Recon: hallazgos reales:**
- El caso de María (§6.4) ya era real a nivel de `authorize!`/`role_assignments` desde P1
  (`test/integration/teacher_management_test.rb`), pero corría enteramente contra los rosters en
  memoria (`TeacherManagement::TeacherRoster`/`DepartmentRoster`, ids fijos tipo `"t-1"` y UUIDs
  hardcodeados) — nunca contra una fila real de `teachers`/`departments`.
- `TeacherManagement::TeacherScope`/`DepartmentScope` ya tenían la FORMA correcta (per-row `can?`
  vía `.select`, sin `default_scope`) — solo la fuente de datos era stub. No hubo que rediseñar el
  patrón, solo cambiar qué relation resuelven.
- **`teacher.evaluate` no tiene modelo destino** — `TeacherEvaluationsController#create` seguía
  siendo un `flash` sin persistencia (confirmado, ningún `TeacherManagement::Evaluation` existe).
  Por BV6, este slice solo cablea el GATE real (per-row, sobre un `Teacher` real) — construir el
  CRUD de evaluación es follow-up explícito, no parte de #4 slice 1.
- Todos los permisos necesarios (`teachers.view`, `teacher.evaluate`, `departments.view`,
  `staff.read`) ya estaban en `IdentityAccess::SeedPermissions::CATALOG` desde antes — cero permisos
  nuevos.
- `StaffManagement::StaffController#index` corría con `authorize!("staff.read")` **sin ningún
  Query object** — "nada especificado para scopear", según su propio comentario. Este slice le dio
  el mismo tratamiento per-row que `teacher_management` (`StaffManagement::StaffScope`, nuevo).

**El descriptor de scope real, cableado esta vez de punta a punta:**
- `TeacherManagement::Teacher#department_id`/`#status` — `delegate ... to: :staff_member,
  allow_nil: true`. Un `Teacher` sin `staff_member_id` poblado (la transición aditiva de D1) nunca
  matchea un grant scoped a departamento — comportamiento correcto (no vinculado ⇒ fuera de
  cualquier alcance de supervisión todavía), no un bug, y se dejó un test unitario que lo prueba
  explícitamente.
- `StaffManagement::Department#department_id` — método que aliasa `id` (mismo truco que el `Row`
  del roster retirado usaba, ahora sobre el modelo real) — es lo que
  `Authorization::Assignment::SCOPE_READERS` necesita para decidir si un departamento cae dentro
  del alcance de un `area_lead`.
- `StaffManagement::StaffMember#name` — un método de una línea (`institution_user.user.name`); el
  nombre de la persona vive en `Core::User`, nunca duplicado en `staff_members`.
- `TeacherManagement::Teacher#subjects` — real, vía `teaching_assignments -> Schedules::Subject`
  (FK cross-dominio ya existente, no inventada).

**Lo que NO se inventó (fiel a los datos reales, no a la forma del stub retirado):** el show de un
docente tenía "Cualificaciones" (array) y un stat de "grupos asignados" en el stub — ninguno de los
dos tiene columna/asociación real (no existe ningún vínculo docente↔grupo en el esquema, el mismo
hallazgo ya documentado desde el autoservicio de staff en v1.10.0). Se **retiraron** ambos del show
real en vez de fabricar un valor; el stat de "materias asignadas" (real, vía `subjects`) ocupa el
lugar del de grupos.

**Bug encontrado en la verificación (no en el código de este slice, en un test viejo):**
`test/integration/transportation_test.rb` tenía dos tests que aserteaban contra el nombre
hardcodeado del `StaffRoster` retirado (`"Rosa Elena Duarte"`), colgados ahí desde el commit
original que cerró el nav huérfano de `staff_management` (`7de5891`, muy anterior a este slice y a
CHECKPOINT E). Al volverse real el directorio, esos dos tests fallaron — correctamente, porque esa
persona nunca existió en ninguna tabla real. Se retiraron (la cobertura real y mejor de
`staff_management` ya vive en `test/integration/staff_directory_test.rb`, con datos sembrados de
verdad e institución propia).

**Caso de aceptación de María, ahora contra vistas reales:** índice de `teacher_management` para
María (`area_lead` de Matemáticas) muestra a su colega de Matemáticas, nunca a la docente de
Sociales; `evaluate` da 200 sobre el colega de Matemáticas y 403 sobre la de Sociales, con `can?`
reflejando lo mismo en el botón "Nueva evaluación"; un `secretary` de solo lectura ve el estado sin
el botón. Un docente SIN `area_lead` (solo `teachers.view` scoped a su propio grupo) llega al índice
(la puerta de capacidad pasa) pero lo ve **vacío** — ningún `Teacher` responde a `:group_id`, así que
el filtro per-row excluye a todos: ni 403 ni 500, la ausencia real del vínculo docente↔grupo se
manifiesta como "no superviso a nadie", no como un error. `StaffManagement::StaffScope`: un
`institution_admin` institución-wide ve TODO el staff (docente, cocina, y el que no tiene
departamento asignado); un `area_lead` scoped a Matemáticas ve solo su propio departamento — nunca
cafetería, nunca el staff sin asignar (`department_id` nulo nunca matchea un scope de departamento
específico, solo uno institución-wide). Aislamiento cross-tenant verificado con datos reales
sembrados en una segunda institución bajo su propio GUC, nunca visibles desde la primera.

**Resultado:** 377 runs / 1350 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
369; +8 netos: teacher_management_test.rb pasó de 8 a 12 casos, +4 nuevos en
staff_directory_test.rb, +4 nuevos en teacher_scope_test.rb —unitario, la referencia limpia que los
próximos seis dominios pueden copiar—, -2 retirados de transportation_test.rb). `bin/rails
zeitwerk:check` verde. Sin migraciones.

**Archivos retirados** (reemplazados por lo real, cero referencias remanentes verificadas antes de
borrar): `app/domains/teacher_management/services/{teacher_roster,department_roster}.rb`,
`app/domains/staff_management/services/staff_roster.rb`.

**Archivos nuevos/editados por rol:**
- Query objects: `teacher_management/queries/{teacher_scope,department_scope}.rb` (reescritos),
  `staff_management/queries/staff_scope.rb` (nuevo).
- Modelos: `teacher_management/models/teacher.rb` (+`department`/`department_id`/`status`
  delegados, +`subjects`), `staff_management/models/department.rb` (+`department_id`),
  `staff_management/models/staff_member.rb` (+`name`).
- Controllers: `teachers_controller.rb`, `departments_controller.rb`,
  `teacher_evaluations_controller.rb`, `staff_management/staff_controller.rb` — todos ahora contra
  modelos reales.
- Vistas: `teachers/{index,show}`, `departments/{index,show}`, `teacher_evaluations/new`,
  `staff_management/staff/index` — todas ajustadas a la forma real de los modelos (sin
  "cualificaciones"/"grupos asignados" fabricados).
- Helper: `teacher_management_helper.rb` (`teacher_status_badge` nil-safe para un docente sin
  vincular).
- Tests: `test/integration/teacher_management_test.rb` (reescrito con datos reales, +4 casos),
  `test/integration/staff_directory_test.rb` (nuevo), `test/models/teacher_management/
  teacher_scope_test.rb` (nuevo, unitario), `test/integration/transportation_test.rb` (-2 tests
  obsoletos).

**Lección durable para los seis dominios que siguen en #4:** el molde de §6.6 no es "elegí un query
object cualquiera" — es específicamente per-row `can?` sobre una relation real con `institution_id`
explícito, sin `default_scope`, sin forzar `scope_for`. Copiarlo literalmente (cambiando el modelo y
el permiso, no la forma) es el punto de este slice.

### v1.12.0 — 2026-07-14 — CHECKPOINT E cerrado (D1): staff generalizado, docente como especialización

**El borde de arquitectura abierto desde el arranque del proyecto** — dónde vive el personal no
docente (cocina, transporte, enfermería, etc.) — se atacó como si fuera un refactor fundacional
pendiente, con recon pesado y una pausa de diseño obligatoria antes de tocar la BD (§2 del prompt).
El recon cambió el problema por completo.

**El hallazgo del recon (STOP #1):** D1 — "un solo hogar de staff, docente como especialización" —
**ya estaba resuelto en el esquema desde el primer commit** (`637a998 Add staff_management domain
(departments, staff_members, HR)`), muchísimo antes de que el track de onboarding (P1→v1.11.0)
siquiera empezara:

- `staff_members` (migración `20260706000001_create_staff_management.rb`) ya es el backbone de
  empleo generalizado para TODO el personal: `staff_category IN ('teaching','kitchen','transport',
  'maintenance','security','admin','other')`, `department_id` **nullable**, tenant-scoped + RLS.
- `departments.kind IN ('academic','operational')` — ya generalizado más allá de "departamento
  académico"; es la misma tabla que `role_assignments.scope_department_id` referencia por FK real
  desde P1.
- `teachers.staff_member_id` (migración `20260706000002_link_teachers_to_staff_members.rb`) es un FK
  **nullable, aditivo** que liga `TeacherManagement::Teacher` (la especialización docente) a
  `StaffManagement::StaffMember` (la base generalizada). El comentario de esa migración ya lo decía
  textualmente: *"D1 additive link: a teacher is a staff_member with a teaching extension."*
- `Core::Access::StaffProfileScope` (v1.10.0) **ya lee `StaffManagement::StaffMember` directamente**
  — nunca `Teacher` — así que el autoservicio de staff YA resolvía a un docente y a un no-docente de
  forma idéntica, sin ninguna rama especial, desde que ese scope se escribió.
- Cero FK cruza desde `schedules`/`group_management` hacia `teachers`/`teacher_management` — no había
  nada que un rename hubiera podido romper, ni falta que hacía.

**Lo que sí faltaba (el gap real, no el que el prompt asumía):**
- `TeacherManagement::TeacherRoster`/`DepartmentRoster` y `StaffManagement::StaffRoster` son STUBS en
  memoria, completamente desconectados de las tablas reales — `db/seeds.rb` nunca crea una fila de
  `Teacher`, `StaffMember` ni `Department`.
- Ningún camino de alta real (`Core::People::Resolver`/`PeopleController`) crea un `StaffMember` al
  contratar a alguien — solo existe si se crea a mano (como ya hacían los tests de v1.10.0).
- `PROJECT_STATE.md` describía CHECKPOINT E como abierto y a `staff_management` como "un stub que
  solo cierra un nav huérfano" — cierto de la VISTA, falso del MODELO. El documento nunca se
  reconcilió contra el disco tras el commit `637a998`.

**Checkpoint de diseño (STOP #2):** con este hallazgo en mano, se presentó al usuario la propuesta de
**no hacer ningún rename ni migración** — tratar la forma ya existente (dos dominios, uno generalizado
+ uno especializado vía FK nullable) como la respuesta correcta y definitiva a D1, y limitar el slice
a verificación + corrección de documentación. Se preguntó explícitamente: (1) la forma de D1 (aceptar
la existente vs. renombrar `teacher_management`→`staff_management` vs. otra forma), (2) si wirear los
directorios stub a datos reales entraba en este slice o era backlog #4, (3) si ampliar el enum de
`staff_category` para roles de bienestar/registro (hoy caen en `'other'`), y (4) el bump de versión.
**El usuario aprobó las cuatro recomendaciones**: aceptar la forma existente, dejar los directorios
como backlog #4 (el propio prompt ya los listaba como fuera de alcance), no tocar el enum (YAGNI —
`'other'` ya cubre el caso sin bloquear nada), y `v1.12.0` (MINOR, no MAJOR — no hay reestructuración
real del mapa de dominios en este slice, solo confirmación de una que ya existía).

**Trabajo real ejecutado:** un test de integración nuevo (`self_service_test.rb`) que siembra un
`cafeteria_staff` — categoría `kitchen`, departamento **operacional** ("Cafetería"), **cero filas**
`TeacherManagement::Teacher` en la institución — y verifica que `/mis_datos` lo resuelve exactamente
igual que a un docente: perfil completo, número de empleado, departamento, sin ningún empty state de
"perfil no vinculado". Esto prueba, de punta a punta (no solo por inferencia desde los tests unitarios
de `StaffProfileScope`, que ya usaban categorías no-docentes incidentalmente), que E5 (no romper
v1.10.0) y el caso de aceptación del prompt (staff no docente con perfil, `department` nullable,
resuelto por identidad igual que un docente) se sostienen. **Cero migraciones. Cero cambios a
`StaffProfileScope`/`StaffRoleAssignmentsScope`/nav** — no hicieron falta.

**Resultado:** 369 runs / 1311 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
368; 1 test nuevo). `bin/rails zeitwerk:check` verde (sin renames, no había nada que romper). Sin
migraciones.

**Documentos actualizados:**
- `PROJECT_STATE.md` → v1.12.0: §4 (mapa de dominios corregido: `staff_management` sale de "Tier C
  candidato" y entra como dominio real generalizado; `teacher_management` re-descrito como su
  especialización docente), §10 (CHECKPOINT E ✅ cerrado), §11.2 (tachado), guardrails (regla nueva
  sobre el hogar único de staff).
- `CONCEPTOS_TECNICOS.md` → nuevo concepto: "Staff generalizado / docente como especialización" (ver
  ese archivo para el bloque completo: definición, rationale D1 vs. D2, dónde vive en código,
  invariantes).

**Lección durable para futuros slices de "cerrar un checkpoint arquitectónico":** el recon SIEMPRE
va antes que la propuesta, incluso (especialmente) cuando el prompt ya asume una forma concreta de
solución (acá, una migración de rename) — el estado real del código puede haber superado al
documento vivo sin que nadie lo haya notado. Reconciliar `PROJECT_STATE.md` contra el disco no es
opcional ni un paso burocrático: en este caso evitó una migración innecesaria sobre una tabla
fundacional y un rename de dominio con cero beneficio funcional.

### v1.11.0 — 2026-07-14 — Onboarding: visor de `audit_events` + bandeja de discrepancias

**Quinto y último slice regular del track de onboarding** (queda solo el disparador opcional de
`Expirer`/`BounceHandler`, #1.5). El más barato de los que faltaban: los datos ya se escribían desde
v1.6.0 (`IdentityAccess::Audit.log`) — este slice solo construye las superficies de LECTURA sobre
ellos. A diferencia de los tres slices anteriores (portales de persona v1.9.0, autoservicio de staff
v1.10.0), que se gatean por identidad/relación sin `authorize!`, este es el caso opuesto a propósito:
una superficie **administrativa**, gateada por **RBAC**.

**Recon: hallazgos reales:**
- `IdentityAccess::AuditEvent` (tabla `audit_events`): `institution_id`, `actor_institution_user_id`
  (nullable — eventos de sistema/job sin actor humano), `action` (string libre por convención, greppable
  y con puntos: `"invitation.sent"`), `target_type`/`target_id` (columnas sueltas, no una asociación
  polimórfica real de Rails), `metadata` (jsonb), `ip`, y **solo** `created_at` (`record_timestamps =
  false`) — el `REVOKE UPDATE, DELETE ON audit_events FROM edu_app_runtime` de la migración original
  confirma el append-only a nivel de rol de BD, no solo de convención de app.
- **El set real de acciones**, grepeado de cada call site de `Audit.log`/`IdentityAccess::Audit.log`
  en `identity_access` (nueve en total, ninguna inventada): `invitation.sent`, `invitation.bounced`,
  `invitation.completed`, `invitation.discrepancy_reported`, `person.created`, `person.suspended`,
  `person.reactivated`, `roster_import.validated`, `roster_import.commit_enqueued`. Este set se
  convirtió literalmente en `IdentityAccess::AuditEventIndex::ACTIONS` — el filtro de acción es un
  `<select>` sobre este hash, nunca un input de texto libre.
- **El marcador de discrepancia**, confirmado en `Invitations::DiscrepancyReporter`:
  `action: "invitation.discrepancy_reported"`. El propio comentario de esa clase ya documentaba la
  intención — "reuses audit_events as the inbox instead of inventing a new table; a future 'bandeja
  de discrepancias' view is just a filtered audit_events#index" — así que la bandeja de este slice es,
  literalmente, `AuditEventIndex.call(action: DISCREPANCY_ACTION)`, sin tabla nueva.
- **Ningún permiso de auditoría existía.** Se agregó `audit_events.read` a
  `IdentityAccess::SeedPermissions::CATALOG` (estilo `.read`, igual que `students.read`/
  `finance.read`/`counseling.read`). Recon adicional: no existe HOY ningún mecanismo de seed
  automático que conceda un permiso del catálogo a `institution_admin` (u otro rol) por institución
  — cada `RolePermission` real se crea ad hoc vía la superficie admin de roles/asignaciones (o
  `grant_role!` en test). Esto es cierto para TODOS los permisos existentes, no una carencia nueva de
  este slice — se documenta en vez de inventar infraestructura de seeding fuera de alcance.
- **Gap real de índice, confirmado contra `db/structure.sql`:** los dos índices existentes de
  `audit_events` son `(institution_id, action)` y `(institution_id, target_type, target_id)` — ninguno
  soporta una lectura `institution_id`-leading ordenada por `created_at`. Sobre una tabla append-only
  que crece sin cota, paginar "más reciente primero" sin ese índice degrada a un sort completo por
  página a medida que crece. Única migración del slice: `add_index :audit_events, [:institution_id,
  :created_at]` (orden `created_at DESC`) — corrida en dev y test vía `bin/migrate`.
- `shared/_audit_entry_row` ya existía (con un TODO literal pidiendo un modelo real) pero no tenía
  ningún consumidor — este slice es su primer uso real; el TODO se retiró.
- `identity_access` es un dominio fundacional (no addon-gated) — el visor no tiene ninguna compuerta
  de entitlement, solo RBAC.

**`IdentityAccess::AuditEventIndex`** — query object explícito (no `default_scope`): scope de
tenant + filtros opcionales (`actor_institution_user_id`, `action` ∈ `ACTIONS`, `from`/`to`) + orden
`created_at desc, id desc` + paginación (`PER_PAGE = 25`, `limit`/`offset`, `Data.define` `Page` con
`events`/`page`/`total_pages`/`total_count`). Un valor de `action` fuera del set conocido se ignora
silenciosamente (nunca un error, nunca SQL crudo) — es la defensa real contra que el filtro derive en
un buscador de texto libre.

**`IdentityAccess::AuditEventsController`** — `authorize!("audit_events.read")` al inicio de
`#index` y `#discrepancies` (las únicas dos acciones; ninguna acción de mutación existe). El actor
en el filtro es un `<select>` sobre el staff de la propia institución (`institution.memberships.
active`) — no es un buscador de personas/menores, es la misma superficie ya visible en "Personas".
`AuditEvent#actor_label`/`#target_label` (nuevos métodos del modelo) resuelven una referencia mínima
y no-navegable al target (nombre de un `Core::User`, o "Carga de <kind>" para un
`Core::RosterImportBatch`) — nunca un link a un directorio.

**Caso de aceptación, verificado end-to-end:** admin A con `audit_events.read` ve exactamente los
eventos de su institución I (nunca los de J, verificado con query real bajo RLS, no con
`current_setting()`); filtrar por actor/acción/fecha de forma independiente y compuesta reduce
correctamente el set; la bandeja de discrepancias muestra exactamente el evento marcado por
`DiscrepancyReporter`, ninguno más; un staff S sin `audit_events.read` recibe 403 en ambas rutas
(la puerta dura SÍ está — a diferencia de los portales/autoservicio); un filtro sin resultados
muestra el empty state, nunca un error; ninguna vista tiene `input[type=search]`/`input[name=q]`
dentro de `#main`; no existe ninguna ruta ni método de controller para actualizar/borrar un evento.
Paginación verificada con 30+ eventos (25 en la página 1, el resto en la 2, sin solapamiento de ids).

**Resultado:** 368 runs / 1303 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
356; 12 tests nuevos: 7 de unidad del query object, 5 de integración del visor/bandeja/RBAC/cross-
tenant/Habeas Data). `bin/rails zeitwerk:check` verde. Una migración (índice nuevo), corrida en dev
y test.

**Archivos creados/editados por rol:**
- Query object (nuevo): `app/domains/identity_access/services/audit_event_index.rb`.
- Modelo (editado): `app/domains/identity_access/models/audit_event.rb` (+`actor_label`/
  `target_label`).
- Controller + rutas + nav (nuevos/editados): `app/controllers/identity_access/
  audit_events_controller.rb`, `config/routes.rb`, `config/navigation/identity_access.rb`.
- Vistas (nuevas): `app/views/identity_access/audit_events/{index,discrepancies,_events_table}.
  html.erb`; `app/views/shared/_audit_entry_row.html.erb` (comentario TODO retirado).
- Estilos (editado): `app/assets/stylesheets/components.css` (`.audit-filters`, `.audit-log`).
- Permiso (editado): `app/domains/identity_access/services/seed_permissions.rb` (+`audit_events.
  read`).
- Migración (nueva): `db/migrate/20260714000001_add_institution_and_created_at_index_to_audit_
  events.rb`.
- Tests (nuevos): `test/models/identity_access/audit_event_index_test.rb`,
  `test/integration/audit_events_test.rb`.

Con este slice, el track de onboarding queda cerrado salvo el disparador opcional de
`Expirer`/`BounceHandler` (#1.5, no bloqueante). Candidatos siguientes: CHECKPOINT E
(`staff_management` vs. `human_resources`) o vistas de negocio por dominio con scope (#4) — a
decidir con el usuario.

### v1.10.0 — 2026-07-10 — Onboarding: autoservicio de staff ("mis datos")

**Cuarto slice del track de onboarding.** Construye "mis datos" para personas de staff (docente,
coordinador, director, cualquier rol) sobre datos reales, resuelto por identidad — el análogo, para
staff, de lo que v1.9.0 hizo para estudiante/acudiente. A diferencia de ese slice, **no existía
ningún stub que retirar**: el `DashboardController` ya real (Fase 0) es el landing de atajos
**RBAC-gateado** (otra cosa por completo — supervisión, no autoservicio); esta sección es enteramente
nueva.

**Recon: hallazgos reales:**
- Confirmado el molde: `GuardianScope`/`StudentSelfScope`/`EntitledAddonKeys` viven en
  `services/access/`, `module_function`, `.for(user, institution: Current.institution)`. Los dos
  self-scopes de staff replican esta forma exactamente.
- **La cadena de identidad real del staff:** `Core::User` → `Core::InstitutionUser` →
  `StaffManagement::StaffMember` (opcional) → `TeacherManagement::Teacher` (opcional, vía
  `staff_member_id` nullable — frecuentemente sin poblar incluso para docentes reales, limitación ya
  documentada desde P1/RosterImport). **`sections` no tiene ninguna columna `homeroom_teacher_id`** —
  no hay ningún vínculo directo profesor↔grupo en el esquema. "Mis grupos" y "mi departamento" se
  resuelven por lo tanto **directamente desde los `scope_group_id`/`scope_department_id` de los
  propios `role_assignments` vigentes del actor** (`.effective_now`, real desde P1) — no desde la
  cadena `Teacher→StaffMember→department`, que además suele estar vacía en la práctica.
- **Hallazgo que contradijo una premisa del prompt:** "mi horario" se asumía filtrable por un FK real
  a `academic_terms` en `schedules`. El recon confirmó que **`schedules` no tiene ninguna tabla real
  en absoluto** — ni siquiera parcial, a diferencia de `teachers`/`students` — solo `enrollments`/
  `subjects`/`assessments` (notas), sin ningún componente temporal. El único FK real a
  `academic_terms` en todo el esquema es el de `roster_import_batches`. Se presentó la discrepancia
  al usuario: **decisión tomada — incluir el tile de horario reusando el `ScheduleEventRoster`/stub
  ya existente, filtrado por identidad (los propios grupos del actor, nunca por `can?`/RBAC) y
  marcado explícitamente "vista previa"** en vez de omitirlo. No se inventó ninguna tabla.
- No existía ninguna entrada de navegación identity-gated — `Navigation::Registry` filtra TODA
  entrada por `can?(item.permission)`, así que forzar "mis datos" ahí habría violado SS2 (se vería
  como RBAC-gateado sin serlo). Se agregó un enlace persistente en el header del shell
  (`shared/_self_service_link`), visible para cualquier staff autenticado, fuera del registry.

**`Core::Access::StaffProfileScope`** — hermano de `StudentSelfScope`: un `StaffManagement::
StaffMember` o `nil` (no todo staff tiene fila de perfil — estado vacío normal, no error).
**`Core::Access::StaffRoleAssignmentsScope`** — hermano de `GuardianScope`: una relation componible
de `role_assignments.effective_now` del actor — el límite de seguridad real sobre el que se derivan
"mis grupos"/"mi departamento" (mapeando sus columnas de scope a `Section`/`Department`).

**`SelfServiceController#show`** (`/mis_datos`) — **sin `authorize!`** en ninguna acción (SS2): los
self-scopes SON la puerta. Tabs (reusa `shared/tabs`, mismo patrón que `teachers#show`): Perfil, Mis
roles, Mis grupos, Mi departamento, y Mi horario (solo si `schedules` está entitled — mismo memo
`Current.entitled_addon_keys` que la nav, sin reimplementar el chequeo). Empty states amables en
cada tab cuando no aplica (SS8), nunca 403 ni error.

**Caso de aceptación, verificado end-to-end:** docente T con un `role_assignment` vigente
`(teacher, group:10-A)`, uno **expirado** `(teacher, group:9-C)`, y uno de departamento
`(area_lead, department:Matemáticas)`; un segundo docente U con su propio grupo en la MISMA
institución; los mismos datos de T replicados en una institución J distinta. Actuando como T bajo el
GUC de I: aparecen perfil, "10°A", "Matemáticas" — **nunca** "9°C" (expirado), **nunca** el grupo de
U, **nunca** el departamento de J. El tile de horario, filtrado por el grupo real de T (mismo id
canónico que usa `GroupManagement::GroupRoster`), muestra el evento stub de "Cálculo" (etiquetado
con esa misma sección) pero no "Sociología" (etiquetado con otra). Verificado también: identity-
gating (un actor con **cero `RolePermission`** en toda la institución llega igual a su autoservicio
completo), un coordinador con solo un rol institución-wide sin grupos ve empty states (no error), y
el tile de horario desaparece por completo cuando la institución no tiene `schedules` entitled.

**Resultado:** 356 runs / 1239 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
342; 14 tests nuevos: 10 de unidad de los dos self-scopes, 4 de integración —incluido el caso de
aceptación completo—). `bin/rails zeitwerk:check` verde. Sin migraciones.

**Archivos creados/editados por rol:**
- Self-scopes (nuevos): `app/domains/core/services/access/{staff_profile_scope,
  staff_role_assignments_scope}.rb`.
- Controller/rutas: `app/controllers/self_service_controller.rb` (nuevo), `config/routes.rb`
  (+`resource :self_service`).
- Vistas: `app/views/self_service/show.html.erb` (nueva), `app/views/shared/
  _self_service_link.html.erb` (nueva), `app/views/layouts/application.html.erb` (+enlace en el
  header).
- Tests: `test/models/core/access/{staff_profile_scope,staff_role_assignments_scope}_test.rb`,
  `test/integration/self_service_test.rb` (caso de aceptación + identity-gating + empty states +
  entitlement).

**Forward notes (backlog):** (a) visor de `audit_events` + bandeja de discrepancias es lo siguiente
(#1.4); (b) vistas de negocio por dominio con scope (supervisión — ver a OTRAS personas dentro del
propio alcance RBAC) sigue siendo #4, dominio por dominio, sin contaminar esta sección de
autoservicio; (c) "mi horario" sigue siendo vista previa hasta que `schedules` tenga tablas reales
— cuando eso pase, el tile se recablea sin tocar el resto de esta sección; (d) filtro por término
lectivo para grupos/matrícula sigue diferido a B2.

### v1.9.0 — 2026-07-10 — Onboarding: `Core::Access::GuardianScope` + portales sobre datos reales

**Tercer slice del track de onboarding.** Construye `Core::Access::GuardianScope` (resuelve "mis
acudidos" contra `guardian_students` real) y cablea los portales de acudiente y estudiante,
existentes desde antes pero 100% stub, a datos reales de relación. Slice de solo lectura: sin
migraciones, sin formularios, sin tocar RBAC/entitlement/control plane.

**Recon: hallazgos reales, resueltos por disco:**
- **Corrección de ubicación (GS1):** el prompt asumía `app/domains/core/queries/access/
  guardian_scope.rb`, pero `Core::Access::EntitledAddonKeys` (el query object de referencia a
  espejar) en realidad vive en `app/domains/core/services/access/`, no en `queries/access/` — ese
  directorio ni existe. Zeitwerk colapsa ambos exactamente igual (`services`/`queries` son
  intercambiables en la colapsación), así que el nombre de constante no cambia, pero se puso
  `guardian_scope.rb` junto a su hermano real por consistencia, no en un directorio nuevo.
- **`guardian_students.status`**: confirmado `active`/`revoked` (CHECK), default `active`,
  `scope :active` ya existe en el modelo — coincide exactamente con GS2/GS7, sin sorpresas.
- **El GUC ya estaba fijado en las rutas de portal** — `TenantScoped#within_tenant` es un
  `around_action` en `ApplicationController`, heredado por `Portals::*` sin nada especial que hacer.
  `GuardianScope` confía en RLS como backstop, con scoping explícito (`institution_id` +
  `guardian_user_id` + `status`) como primario — nunca `default_scope`.
- **Hallazgo que exigió una adición de superficie real:** `resource :guardian, only: :show` era un
  recurso **singular** — no existía ninguna URL direccionable por-hijo. El caso de aceptación exige
  poder "intentar la URL de S3 → no encontrado", lo cual requiere una ruta real. Se agregó
  `resources :students, only: :show, controller: "guardian_students"` anidada bajo `/portal/guardian`,
  resuelta siempre a través de `GuardianScope.for(...).find(id)` — un estudiante fuera del scope
  activo del llamante (link revocado, otro acudiente, otro tenant) da `ActiveRecord::RecordNotFound`
  automático → 404 (confirmado `config.action_dispatch.show_exceptions = :rescuable` en test, sin
  necesitar un `rescue_from` custom).
- El portal de estudiante (`resource :student, only: :show`, singular, sin `:id`) ya tenía la
  garantía "no alcanzable la URL de otro estudiante" **estructuralmente** — no hay parámetro que
  aceptar. Se verificó (no se construyó) con un test que confirma que una URL con un id cualquiera
  simplemente no matchea ninguna ruta (404, vía el mismo `:rescuable`).
- Los 4 controllers de sub-portal (`{guardian,student}_{cafeteria,transport}`, explícitamente FUERA
  de este slice — backlog #4) solo usaban `Portals::{Guardian,Student}Dashboard.stub.{guardian,
  student}_name` para UNA línea (el nombre en el header) — se cambió esa línea a `Current.user.name`
  en los 4 (mecánico, no toca su dato por-dominio, que sigue stub a propósito) para poder retirar
  limpiamente las clases stub `Portals::GuardianDashboard`/`Portals::StudentDashboard` (eliminadas).

**`Core::Access::GuardianScope`** (`app/domains/core/services/access/guardian_scope.rb`) — módulo
plano, `module_function`, mismo estilo que `EntitledAddonKeys`. `.for(user, institution:
Current.institution)` devuelve una relation de `GroupManagement::Student`, componible, NUNCA un
Array. Filtro explícito `institution_id` + `guardian_user_id` + `status: "active"` en el join — sin
parámetro de búsqueda en la firma (GS4, verificado con un test que inspecciona
`method(:for).parameters` directamente, no solo probado a mano). GS3 (sin filtro de término
lectivo) documentado como reversible cuando cierre B2, mismo criterio que
`Core::Headcount::Snapshotter`.

**`Core::Access::StudentSelfScope`** (GS5) — hermano simétrico, mismo módulo/patrón, devuelve UN
registro (`find_by`) o `nil`, no una relation (self es uno-o-ninguno por definición).

**Portales cableados:**
- `Portals::GuardianPortalController#show` — `@children = GuardianScope.for(Current.user)`; sin
  `authorize!` (GS6 — cero permisos RBAC, el scope ES la puerta); vista con tabla real (nombre,
  código, grado, grupo) enlazando a `/portal/guardian/students/:id`; empty state amable si no hay
  acudidos activos (GS9).
- `Portals::GuardianStudentsController#show` (nuevo) — resumen de solo lectura de un hijo, resuelto
  SIEMPRE a través de `GuardianScope.for(...).find(id)` — nunca `GroupManagement::Student.find`
  directo. `national_id` nunca se muestra.
- `Portals::StudentPortalController#show` — `@student = StudentSelfScope.for(Current.user)`; resumen
  propio o empty state si la cuenta no tiene un registro de estudiante vinculado.

**Caso de aceptación de seguridad (§5), verificado end-to-end:** instituciones I y J, acudiente G
(mismo `Core::User` global) con membresías activas en ambas, links activos a S1/S2 en I, link
revocado a S3 en I, link activo a S4 en J. Actuando como G bajo el GUC de I: el portal muestra
exactamente S1/S2; S3 (revocado) y S4 (otro tenant) no aparecen en la lista NI son alcanzables por
URL directa (`/portal/guardian/students/:id` → 404 para ambos). Cero campos de búsqueda en la
página (`input[type=search]`, `input[name=q]`, `form[action*=search]` — los tres verificados
ausentes). Empty states verificados para acudiente sin links y estudiante sin registro propio.

**Resultado:** 342 runs / 1187 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
329; 13 tests nuevos: 9 de unidad de `GuardianScope`/`StudentSelfScope`, 4 de integración —incluido
el caso de aceptación completo—). `test/integration/portals_test.rb` (heredado de fases anteriores,
aserciones sobre el stub) se reescribió para el nuevo comportamiento real (empty state para el actor
genérico de `sign_in_as_member`, que no tiene relación de acudiente/estudiante) — el resto de tests
de portales por-dominio (`cafeteria_test.rb`/`transportation_test.rb`, fuera de este slice) siguieron
verdes sin tocar su aserción de datos, solo se confirmó que no dependían de las clases retiradas.
`bin/rails zeitwerk:check` verde. Sin migraciones — todo el esquema necesario ya existía.

**Archivos creados/editados por rol:**
- Query objects (nuevos): `app/domains/core/services/access/{guardian_scope,student_self_scope}.rb`.
- Rutas: `config/routes.rb` (+`resources :students` anidado bajo `/portal/guardian`).
- Controllers: `app/controllers/portals/{guardian_portal,student_portal}_controller.rb` (real),
  `app/controllers/portals/guardian_students_controller.rb` (nuevo), los 4 controllers de
  sub-portal por-dominio (ajuste mecánico de una línea cada uno).
- Vistas: `app/views/portals/guardian_portal/show.html.erb` (real),
  `app/views/portals/guardian_students/show.html.erb` (nueva),
  `app/views/portals/student_portal/show.html.erb` (real).
- Eliminados: `app/models/portals/{guardian,student}_dashboard.rb` (stub retirado).
- Tests: `test/models/core/access/{guardian_scope,student_self_scope}_test.rb`,
  `test/integration/guardian_scope_test.rb` (caso de aceptación + empty states),
  `test/integration/portals_test.rb` (reescrito para el comportamiento real).

**Forward notes (backlog):** (a) vistas de autoservicio de docente/coordinador/director es lo
siguiente (#1.3); (b) visor de `audit_events` sigue pendiente (#1.4); (c) datos por-dominio dentro
del portal (saldo de cafetería, rutas de transporte reales, horario) siguen fuera — el portal ya
queda listo para colgarlos, cada uno detrás de su propio entitlement + lectura scoped (backlog #4);
(d) filtro por término lectivo sigue diferido a B2, sin inventar el join `enrollments`↔
`academic_terms`.

### v1.8.0 — 2026-07-10 — Onboarding: RosterImport de acudientes (alta batch + `guardian_students`)

**Segundo slice del track de onboarding.** Extiende `Core::RosterImport` (real para estudiantes desde
v1.7.0) al kind `guardians`: crea `Core::User` (login) vía `Core::People::Resolver` + membresía +
vínculo `guardian_students` con upsert aditivo/no-destructivo. Reusa toda la maquinaria de v1.7.0
(tres fases, `CommitJob` bajo GUC, `Cipher`, no-persistencia del CSV).

**G7 — estrategia por-kind, extraída sin romper comportamiento.** `Parser`/`Validator`/`Committer`
(v1.7.0) estaban 100% hardcodeados a estudiantes — cero seam por-kind. Se extrajo
`Core::RosterImport::Strategy.for(kind, institution:)` → `Strategies::{Students,Guardians}`, cada
una encapsulando: `expected_headers`, `required_fields`, `sensitive_fields`, `collision_key(plain)`,
`business_errors(plain)`, `existing_record?(plain)`, `commit_row!(plain)`, `preview_columns(plain)`/
`preview_headers`. Los tres orquestadores y el controller/vista quedaron **kind-agnósticos** — nunca
ramifican por kind, solo delegan al strategy. **Los 28 tests de estudiantes de v1.7.0 siguen verdes
sin ninguna edición de comportamiento** tras la extracción (confirmado corriendo la suite completa).

**Recon: hallazgos reales, resueltos por disco:**
- **El más crítico, confirma G3 sin ambigüedad:** `SessionsController#authenticate_credentials`
  exige literalmente `user.memberships.active.exists?(institution_id:)` para autenticar. Sin la
  membresía `institution_users` que crea `Resolver`, un acudiente **nunca podría loguear**, ni
  siquiera después de completar su invitación. La membresía no es solo "consistente" — es lo que
  hace posible el login futuro.
- **El portal de acudiente sigue 100% stub** (`Portals::GuardianDashboard.stub`) — no resuelve nada
  real todavía (ni por `institution_users` ni por `guardian_students`). No había nada real con qué
  ser consistente; eso es exactamente el slice siguiente (`GuardianScope`).
- `roster_import_batches.kind` ya admitía `'guardians'` en su CHECK desde que se creó la tabla — sin
  migración para eso. `guardian_students` ya tenía el índice único exacto necesario para el link:
  `(institution_id, guardian_user_id, student_id)` — sin migración tampoco.
- **Reinterpretación necesaria del enum fijo de `roster_import_rows.status`** (`valid/duplicate/
  collision/error`, igual para ambos kinds): para acudientes, que el mismo `guardian_national_id` se
  repita en el CSV es **normal** (un acudiente con N hijos = N filas) — nunca colisión. La colisión
  real es el **par** `(guardian_national_id, student_national_id)` repetido. "duplicate" pasó a
  significar "el LINK ya existe" (no simplemente "el acudiente ya existe") — un acudiente existente
  ganando un hijo nuevo sigue siendo "valid" (link nuevo), solo re-afirmar un link YA existente es
  "duplicate". `resolved_record_id` de una fila de acudiente apunta al **link**, no al `Core::User`
  (1 fila = 1 relación, coherente con G1).
- `guardian_students.relationship` **no tiene CHECK en BD** — se definió el vocabulario a nivel
  Validator (`padre/madre/acudiente/tutor`), coincidiendo con la convención ya usada en
  `db/seeds.rb` ("padre"/"madre").

**Commit de un acudiente:** `Core::People::Resolver.call(email:, name:, national_id:, institution:,
role: "guardian")` — el mismo `Resolver` de siempre, que **nunca** crea ningún
`IdentityAccess::RoleAssignment` (confirmado en el recon de P1 y re-confirmado aquí con un test
directo) — cero permisos RBAC por construcción, sin código extra para "evitar" otorgarlos.
`role: "guardian"` se pasa al campo libre `institution_users.role` (P2, sin lectores reales, solo
valor cosmético/greppable). El link se resuelve con `find_or_create_by!` sobre la llave única real;
si existe con `relationship`/`status` distintos, se actualizan esos campos — **nunca se borra** un
link ausente del CSV (test corona: un acudiente con un link a un estudiante NO mencionado en el CSV
conserva ese link intacto tras el commit, verificado a nivel de estrategia y de punta a punta por
HTTP). Un link `revoked` se reactiva si una fila lo vuelve a mencionar (una fila del roster solo
afirma, nunca revoca).

**Cifrado y máscara centralizados en `Cipher`** (antes vivían parcialmente en el helper de vista):
`Cipher.decrypt_row(raw, sensitive_fields)` (descifra todas las claves sensibles de una fila de una
vez, usado por `Validator`/`Committer`/el controller) y `Cipher.mask(plain)` (la regla "revela como
máximo la mitad", movida desde `IdentityAccessHelper#mask_national_id`, que se eliminó — cada
strategy decide qué se enmascara en su propio `preview_columns`, así que la vista nunca decide qué
es sensible). El controller computa el preview (fila descifrada + columnas) **en el controller**, no
en la vista, para que el valor descifrado/enmascarado nunca pase por un helper reusable sin querer.

**Resultado:** 329 runs / 1149 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
312; 17 tests nuevos: 14 de la estrategia de acudientes, 2 de aceptación end-to-end vía HTTP, 1 de
`CommitJob` bajo GUC para el kind `guardians`). Sin migración — ambas piezas de esquema que este
slice necesitaba ya existían. `bin/rails zeitwerk:check` verde.

**Archivos creados/editados por rol:**
- Estrategia (nuevo): `app/domains/core/services/roster_import/strategy.rb`,
  `app/domains/core/services/roster_import/strategies/{students,guardians}.rb`.
- Orquestación (refactor kind-agnóstico, sin nueva migración):
  `app/domains/core/services/roster_import/{parser,validator,committer,cipher}.rb`.
- Controller/vistas: `app/controllers/identity_access/roster_imports_controller.rb` (+parámetro
  `kind`, preview computado ahí), `app/views/identity_access/roster_imports/{new,show}.html.erb`
  (kind-agnósticas vía `preview_columns`/`preview_headers`), `app/helpers/identity_access_helper.rb`
  (`mask_national_id` eliminado, movido a `Cipher.mask`).
- Tests: `test/models/core/roster_import/strategies/guardians_test.rb` (14),
  `test/integration/roster_imports_guardians_test.rb` (2), `test/models/core/roster_import/
  commit_job_test.rb` (+1, GUC para `guardians`), `test/integration/roster_imports_test.rb` (ajuste
  mecánico: los POSTs existentes ahora pasan `kind: "students"` explícito, sin cambio de aserciones).

**Forward notes (backlog):** (a) `Core::Access::GuardianScope` + portales reales sobre
`institution_users`/`guardian_students` es el slice siguiente — el portal de acudiente sigue 100%
stub; (b) batch-invite de los acudientes recién creados es ahora relevante (no pueden loguear hasta
ser invitados) — sigue sin construirse; (c) desvincular una relación vía import sigue sin
construirse (el import es aditivo por diseño, desvincular es una acción explícita aparte).

### v1.7.0 — 2026-07-10 — Onboarding: RosterImport de estudiantes (alta batch por CSV)

**Cierra el primer ítem del backlog de onboarding (§9.1.1 de v1.6.0):**
`Core::RosterImport::{Parser,Validator,Committer}` — las tablas y modelos ya existían
(`Core::RosterImportBatch`/`Core::RosterImportRow`) pero ningún servicio leía un CSV. Corte
deliberado: **solo estudiantes** en este slice — acudientes (`Core::User` + `guardian_students`) es
el slice siguiente, reusando esta misma maquinaria (Parser/Validator/Committer/vistas).

**Recon: discrepancias reales contra el prompt, resueltas por disco:**
- `roster_import_batches.academic_term_id` es **`NOT NULL`** con FK a `academic_terms` — no
  mencionado en el prompt. Resuelto tomando el término activo con el mismo patrón de
  `Core::Headcount::Snapshotter` (`Core::AcademicTerm.active.find_by(institution_id:)`); sin
  término activo, la creación del batch falla con un error amable.
- Los enums reales difieren de los asumidos: `roster_import_batches.status` es
  `uploaded/validated/previewed/committed/failed` (no `pending/...`); `roster_import_rows.status`
  es `valid/error/duplicate/collision` (no `create/update/skip/error`). Mapeo adoptado: `valid`=
  fila nueva (crea), `duplicate`=coincide con un `Student` existente por `national_id` (actualiza),
  `collision`=dos filas del MISMO CSV comparten `national_id` (problema del archivo, no de una fila
  sola), `error`=campo requerido faltante o referencia (`grade_level`/`section`) inexistente. El
  batch usa `uploaded` (tras parse) → `validated` (tras validar — este ES el estado que el preview
  muestra) → `committed`/`failed`; `previewed` no se usa (no hacía falta un estado extra solo para
  "el usuario ya vio la página").
- **El hallazgo más importante: `Core::People::Resolver` NO aplica a estudiantes.** Resuelve
  `Core::User`+`Core::InstitutionUser` (identidad global con login) — un estudiante K-12
  típicamente no tiene `user_id` (nullable por diseño: la persona-estudiante accede por relación,
  no por cuenta). Usarlo aquí habría creado `Core::User`, violando el guardrail explícito del mismo
  prompt ("no tocar `Core::User`"). El `Committer` hace **upsert directo** de
  `GroupManagement::Student` por `national_id` — mismo espíritu aditivo/no-destructivo de J2, sin
  pasar por `Resolver`. `Resolver` queda correctamente reservado para el slice de acudientes.
- `Core::RosterImportBatch` ya declaraba `has_one_attached :file` (comentario: "rides on
  ActiveStorage") — contradice J6 (no persistir el CSV crudo) directamente. Además, `active_storage_
  blobs`/`attachments` son tablas **globales sin RLS** — adjuntar ahí el CSV de un tenant habría
  sido una fuga real de aislamiento entre instituciones, no solo una cuestión de estilo. Se
  **eliminó** `has_one_attached :file` del modelo; el archivo se lee en memoria en el controller y
  nunca se persiste.
- `roster_import_rows.raw` es un único `jsonb NOT NULL` (no columnas separadas por campo). El
  cifrado determinístico de `national_id` (mismo patrón que `GroupManagement::Student#national_id`)
  se implementó con la API de bajo nivel de Rails (`ActiveRecord::Encryption.encryptor.encrypt/
  decrypt`, ver `Core::RosterImport::Cipher`) para cifrar SOLO ese valor antes de insertarlo dentro
  del hash jsonb — sin migración, sin depender de la macro declarativa `encrypts` (que opera sobre
  un atributo entero, no sobre una clave dentro de un jsonb).
- Faltaba una columna real: `roster_import_rows` no tenía cómo enlazar una fila commiteada con el
  `Student` resultante. Única migración del slice: `resolved_record_id` (uuid, nullable, sin FK —
  el slice de acudientes apuntará la misma columna a otra tabla).
- `students.student_code` es `NOT NULL` + único por institución, sin autogeneración hoy — se
  decidió **exigirlo en el CSV** en vez de autogenerar (más simple, no inventa una convención de
  negocio no pedida). `entry_year` es `NOT NULL` en BD sin validación en el modelo — si falta en el
  CSV, se **defaultea al año actual** en el Committer (evita un `NotNullViolation` crudo).

**Bug real encontrado durante la verificación (no solo de test):** el controller inicialmente
encolaba `CommitJob` y LUEGO escribía un `Audit.log` en la misma acción. Bajo el adaptador de test
de ActiveJob (`perform_enqueued_jobs`), `.enqueue_for` corre el job **sincrónicamente**, y el
`ensure` de `ApplicationJob#around_perform` **resetea incondicionalmente el GUC del tenant** al
terminar — así que el `Audit.log` posterior corría sin ningún GUC fijado y fallaba RLS sobre
`audit_events`, incluso dentro de la MISMA request. No es un artefacto de test: cualquier adaptador
de cola que ejecute inline (o un futuro modo síncrono) expondría el mismo problema. Arreglado
reordenando: auditar **antes** de encolar, nunca después — un job cuyo timing de ejecución depende
del adaptador no debe ser una dependencia implícita de código que corre después en el mismo action.

**Segundo bug real: máscara de `national_id` en el preview.** La primera versión de
`mask_national_id` mostraba los últimos 4 caracteres sin condición — para un id de 4 caracteres o
menos (como los usados en tests), esto revelaba el documento COMPLETO en claro. Corregido para
revelar como máximo la mitad de los caracteres (`[length/2, 4].min`), nunca el valor completo.

**Servicios (`Core::RosterImport::*`):** `Cipher` (cifra/descifra un valor suelto para el jsonb),
`Parser` (CSV stdlib → filas crudas, sin escribir en `students`, BOM-safe), `Validator` (por-fila:
`valid`/`duplicate`/`collision`/`error`, cero escrituras reales, contadores en `batch.summary`),
`Committer` (upsert idempotente — resuelve contra `students` reales AL MOMENTO DEL COMMIT, no
contra el status ya guardado de la fila, así que un segundo commit del mismo batch se comporta como
update aunque la fila diga "valid"; aditivo — un campo vacío en el CSV nunca borra un valor
existente). `Core::RosterImport::CommitJob` — el **segundo job real** que ejercita el mecanismo de
GUC de `ApplicationJob` (el primero fue `Core::Headcount::SnapshotJob`, S3a); verificado sin fuga
con una query real bajo RLS (no una relectura de `current_setting()`), mismo protocolo que S3a.

**Controller + vistas:** `IdentityAccess::RosterImportsController` (`index`/`new`/`create`/`show`/
`commit`), gateado por `people.manage` real (P1). Cap de filas síncrono (`MAX_ROWS = 2_000`,
documentado, full-async es hardening). El preview nunca muestra un documento completo (enmascarado)
ni funciona como directorio navegable de estudiantes — solo las filas de ESTE batch recién subido.
Enlazada desde `identity_access/people#index` ("Cargar roster (CSV)") — ni `people` ni
`roster_imports` tienen entrada en `Navigation::Registry` (el mismo patrón que ya regía para
`people` antes de este slice).

**Resultado:** 312 runs / 1068 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
era 284; 28 tests nuevos: 24 de motor + 4 de integración). `bin/rails zeitwerk:check` verde.

**Verificación de seguridad/privacidad explícita:**
(a) el CSV crudo nunca se persiste — se lee en memoria (`file.read`) y se descarta; sin
`has_one_attached`, sin Active Storage.
(b) `national_id` cifrado determinísticamente dentro de `roster_import_rows.raw` — confirmado con
test que el ciphertext no contiene el valor plano.
(c) el preview enmascara el documento (nunca el valor completo).
(d) el `CommitJob` no filtra el GUC — confirmado con una query real bajo RLS tras el job, no con
`current_setting()`.
(e) upsert aditivo/no-destructivo confirmado: un campo vacío en un re-import no borra un valor
existente; re-commitear el mismo batch no duplica estudiantes.
(f) gate real: un actor sin `people.manage` recibe 403 en `index`/`create`.

**Archivos creados/editados por rol:**
- Migración: `db/migrate/20260710152925_add_resolved_record_id_to_roster_import_rows.rb`.
- Gemfile: `gem "csv"` (stdlib bundled desde Ruby 3.4, ya no default — declaración mecánica, no una
  dependencia nueva en espíritu).
- Modelo: `app/domains/core/models/roster_import_batch.rb` (se quitó `has_one_attached :file`).
- Servicios: `app/domains/core/services/roster_import/{cipher,parser,validator,committer}.rb`.
- Job: `app/domains/core/jobs/roster_import/commit_job.rb`.
- Controller: `app/controllers/identity_access/roster_imports_controller.rb`.
- Helper: `app/helpers/identity_access_helper.rb` (badges de estado + `mask_national_id`).
- Vistas: `app/views/identity_access/roster_imports/{index,new,show}.html.erb`;
  `app/views/identity_access/people/index.html.erb` (enlace nuevo).
- Rutas: `config/routes.rb` (`identity_access/roster_imports`).
- Tests: `test/models/core/roster_import/{parser,validator,committer,commit_job}_test.rb`,
  `test/integration/roster_imports_test.rb`.

**Forward notes (backlog):** (a) slice de **acudientes** (`Core::User` + `guardian_students`,
upsert-que-no-rompe-vínculos) es el siguiente, reusa Parser/Validator/Committer/vistas; (b)
batch-invite, full-async de parse+validar, y purga de `roster_import_rows` post-commit quedan como
hardening documentado, no construido.

### v1.6.0 — 2026-07-10 — P1: RBAC real (`IdentityAccess::PermissionCheck` reemplaza el stub)

**Cierra el borde P1 (§10/§11 de v1.5.1).** La segunda compuerta (RBAC con scope) deja de resolver
contra `Authorization::StubResolver`/`StubAssignments` y pasa a resolver contra `role_assignments`
reales. Real-only, fail-closed: sin `RoleAssignment` que aplique, cero permisos — ya no hay
persona stub genérica de respaldo.

**Recon: discrepancias reales encontradas contra el doc/prompt originales, antes de codear:**
- `roles` y `role_permissions` son **tenant-scoped con RLS** en el esquema real
  (`institution_id NOT NULL` + `FORCE ROW LEVEL SECURITY`) — el doc v1.5.1 (§5) decía que eran
  "GLOBAL, sin RLS" junto a `permissions`. Solo `permissions` es global de verdad. Implicación: el
  catálogo de roles se siembra **por institución** (bajo GUC), no una sola vez.
- `roles.assignable_scope_types` **no existe como columna real** — es un concepto solo del stub de
  UI (`IdentityAccess::RoleRoster`, panel admin de `identity_access`, que sigue siendo decorativo y
  no se tocó). No se agregó columna para esto (no bloqueaba P1).
- **`role_assignments` no tenía columnas de fechado** (`valid_from`/`valid_until`) — el esquema real
  no las tenía en absoluto, pese a que R5 y el caso de aceptación las dan por sentadas. Se agregó
  una migración (`20260710144823_add_dating_to_role_assignments`, corrida en dev y test) —
  exactamente la excepción que los guardrails ya preveían ("si el recon revela que falta una
  columna"). `valid_from` no-nulo (default `CURRENT_DATE`), `valid_until` nullable (abierto), CHECK
  `valid_until >= valid_from`.
- **`scope_department_id`/`scope_grade_level_id`/`scope_group_id` SÍ tienen FK reales** (a
  `departments`/`grade_levels`/`sections` respectivamente, `ON DELETE CASCADE`) — el doc decía
  "columnas de alcance explícitas (no polimórfico)", lo cual se leyó al principio como "sin FK
  alguna"; en realidad solo significa "no polimórfico", no "sin FK". Esto obligó a que cualquier
  siembra de un `role_assignment` con scope real cree primero la fila real de
  `Department`/`Section`/`GradeLevel` que referencia (ver más abajo, infra de tests).
- El panel admin de `identity_access` (`RolesController`/`AssignmentsController`/`UsersController`)
  es **enteramente decorativo** — corre contra sus propios Data-class stubs
  (`RoleRoster`/`RoleAssignmentRoster`/`UserRoster`, con `role_key: "area_head"` inconsistente con
  el `"area_lead"` que usa el resto del código) y no toca ni `IdentityAccess::Role` ni
  `RoleAssignment` reales. Confirmado explícitamente fuera de alcance de P1 (no se tocó).
- `teacher_management` (el dominio del caso de aceptación) corre enteramente sobre
  `TeacherRoster`/`DepartmentRoster` (Data-class stubs) con campos que no existen en el esquema real
  (`qualifications`, `status`, `group_ids`, `department_name`, `subjects`) — convertir esas vistas a
  AR real es la iteración #4 del backlog (vistas de negocio por dominio), explícitamente diferida.
  **Decisión, confirmada con el usuario:** P1 hace real el lado de las ASIGNACIONES (rol+scope vía
  `role_assignments` reales) probado contra los recursos del dominio tal como existen hoy (el stub
  roster), sin convertir el catálogo de recursos de `teacher_management` a AR — eso sigue siendo
  backlog #4. El único cambio en los rosters de `teacher_management` fue de VALOR, no de forma:
  los ids de scope pasaron de strings arbitrarios (`"dept-matematicas"`) a constantes con formato
  UUID válido (`TeacherManagement::DepartmentRoster::MATEMATICAS_ID`, etc.), porque
  `scope_department_id` es ahora una columna `uuid` real con FK — el descriptor de scope
  (`resource.department_id`) ya existía desde antes de P1 en el stub, solo cambió el VALOR.

**El motor: `IdentityAccess::PermissionCheck`** (`app/domains/identity_access/services/
permission_check.rb`). `.for(institution_user_id:)` → objeto memoizado con `can?(permission_key,
resource = nil)` y `scope_for(permission_key)`. Carga los `role_assignments` vigentes del actor
(`.effective_now`, nuevo scope en el modelo) → `roles` → `role_permissions` → `permissions`, bajo
el GUC de la request (ya activo por `TenantScoped`). Reutiliza `Authorization::Assignment` (el
value object del stub — institución-wide/recurso-nil/`SCOPE_READERS`) para no duplicar la lógica de
cobertura de scope; lo que cambió es de DÓNDE vienen los grants, no cómo se evalúan. Sin fallback:
`institution_user_id` en blanco o sin `RoleAssignment` aplicable → `[]` → cero permisos, siempre.

**El seam:** `Authorization::Controller#build_authorization_context` ya tenía el
`if defined?(IdentityAccess::PermissionCheck)` esperando desde antes de P1 — no se rediseñó nada,
solo se agregó el archivo. Verificado con `rails runner` que `defined?(...)` resuelve a `"constant"`
(Zeitwerk autoload), así que la rama real SIEMPRE se toma ahora — el fallback a
`StubResolver`/`AssignmentSource`/`StubAssignments` queda muerto en runtime (nunca alcanzable),
confirmado explícitamente, no solo inferido. Esas tres clases se conservaron (comentarios
actualizados marcándolas retiradas) en vez de borrarse: `StubResolver` sigue siendo útil como
contexto fijo en memoria para el único escenario que la vida real de `role_assignments` no puede
representar (ver infra de tests, `:route`).

**Descriptor de scope (R6):** ya existía como convención antes de P1 (`Authorization::Assignment::
SCOPE_READERS`, `resource.respond_to?(:department_id)` etc.) — P1 no inventó el patrón, lo
alimentó con datos reales. `scope_for` es nuevo (§4.1 del prompt): devuelve institución-completa o
los ids de scope que el actor sostiene por permiso, para que un Query object de dominio filtre
directo en vez de recorrer+`can?` fila por fila — ningún dominio lo consume todavía (adopción
incremental, backlog #4); `TeacherManagement::TeacherScope`/`DepartmentScope` siguen con el patrón
per-row `can?`, igual de válido, sin cambios.

**Caso de aceptación María (§6.5), real de punta a punta:** `test/integration/
teacher_management_test.rb#as_maria` pasó de monkeypatchear `Authorization::StubAssignments.all` a
sembrar `role_assignments` reales vía el helper compartido `with_grants` (ver infra de tests).
`authorize! teacher.evaluate` sobre un docente de Matemáticas → permitido; sobre uno de Sociales →
403; el índice de docentes solo muestra Matemáticas. 10 tests, contra datos reales.

**Infra de tests — el radio de impacto real fue MÁS ANCHO de lo anticipado.** No bastaba con
arreglar `sign_in_as_member`: **14 archivos** de test construían su propia persona vía
`Authorization::Assignment.new(...)` + `StubAssignments.define_singleton_method(:all)` (no solo
`teacher_management_test.rb` — también `student_support`, `group_management`, `schedules`,
`cafeteria`, `transportation`, `analytics_bi`, `people_management`, `identity_access`,
`entitlement_gate`, `dashboard`). Todos dejan de tener efecto alguno en cuanto
`IdentityAccess::PermissionCheck` existe (la rama `if defined?` no distingue "hay stub" de "no hay
real" — simplemente ya no consulta el stub nunca). Solución uniforme, no archivo por archivo:
- **`test_helper.rb`**: `sign_in_as_member(grant_default_role: true)` siembra un
  `RoleAssignment` real institución-wide con el MISMO conjunto de permisos que la vieja persona
  stub combinada (`students.read grades.read grades.write counseling.read staff.read`) — elegido
  institución-wide a propósito, porque `covers?` ignora el scope del recurso por completo cuando
  `scope_type == :institution`, así que autoriza across cualquier dominio sin tener que tocar el
  roster de CADA dominio (evita expandir la adopción de descriptor fuera de `teacher_management`).
  `grant_default_role: false` para el escenario "actor sin ningún grant".
- **`grant_role!(user, institution:, role_key:, permission_keys:, scope_type:, scope_id:)`**: siembra
  un `Role`+`RolePermission`(s)+`RoleAssignment` real bajo el GUC del tenant. Mismo shape que el
  viejo `Authorization::Assignment.new(role_key:, permission_keys:, scope_type:, scope_id:)`, así
  que convertir un archivo fue casi mecánico. Cuando el scope es department/grade_level/group,
  primero hace `find_or_create_by!(id: scope_id)` de la fila real correspondiente
  (`StaffManagement::Department`/`GroupManagement::GradeLevel`/`GroupManagement::Section`) —
  descubierto necesario en la marcha por el FK real de esas columnas (ver recon arriba). Seguro
  reutilizar el mismo id fijo entre archivos de test distintos porque cada test corre en su propia
  transacción, que Rails revierte al terminar (fixtures transaccionales) — no hay colisión entre
  tests aunque compartan el "mismo" departamento/sección constante.
- **`with_grants(*assignments, &block)`** (compartido, en `test_helper.rb`): reemplaza CADA
  definición local de `with_grants` en los 7 archivos que la duplicaban. Revoca primero todo
  `RoleAssignment` existente del actor (replicando la semántica REEMPLAZAR de la vieja técnica de
  monkeypatch — los grants reales solo SUMAN, no se sustituyen entre sí como sí hacía swapear
  `StubAssignments.all`) y siembra los nuevos vía `grant_role!`.
- **`with_raw_grants`** (escape hatch, solo `transportation_test.rb`): el scope `:route` (docente↔
  su propia ruta) NUNCA tuvo columna real en `role_assignments` — es un scope inventado solo en la
  capa `Authorization::Assignment` para ese escenario, y agregar `scope_route_id` real sería
  ramificar RBAC en un dominio fuera del alcance de P1 (R7 restringe el wiring real a
  `teacher_management`). Se mantiene el mecanismo viejo (`Authorization::StubResolver` con un
  contexto fijo, igual que el probe controller de `authorization_gate_test.rb`) para ESE archivo
  únicamente — no un fallback runtime, un override de test explícito y documentado.
- **`revoke_all_role_assignments!`**: para el único escenario que necesita "cero grants" sobre la
  MISMA institución ya configurada (el test de orden de compuertas de `entitlement_gate_test.rb`,
  que necesita conservar la revocación de entitlement de `transportation` hecha en el `setup`).
- Los ids de scope compartidos entre dominios (`"stub-section-9a/10a/11b"`, usados por
  `group_management`, `schedules`, `student_support`, `counseling`, `teacher_management`) se
  centralizaron como constantes UUID en `GroupManagement::GroupRoster::SECTION_9A_ID` (etc.) — antes
  eran strings arbitrarios duplicados en 7 archivos; ahora un solo dueño canónico, referenciado por
  los demás. Mismo tratamiento para los departamentos de `teacher_management`
  (`TeacherManagement::DepartmentRoster::MATEMATICAS_ID`, etc.), locales a ese dominio.

**Resultado:** 284 runs / 982 assertions / 0 failures / 0 errors / 1 skip preexistente (suite
completa, en serie — `PARALLEL_WORKERS=1`, la paralelización por fork sigue crasheando el proceso
en esta máquina). 272 tests preexistentes ajustados (ninguno test-por-test en su lógica de
aserciones — el ajuste fue mecánico: `setup` captura `@user, @institution`; se borra la definición
local de `with_grants`; los ids de scope pasan a referenciar la constante compartida) + 12 tests
nuevos del motor (`test/models/identity_access/permission_check_test.rb`: fail-closed sin actor,
fail-closed sin `RoleAssignment`, institución-wide cubre todo, scope de departamento cubre/deniega,
permiso no otorgado se deniega igual dentro de scope, recurso sin descriptor no cubierto por grant
scoped, recurso sin descriptor SÍ cubierto por grant institución-wide, dating vencido/futuro/
abierto, `scope_for` institución-wide y `scope_for` con ids scoped).

**Verificación de seguridad explícita (§8.4 del prompt):**
(a) Sin fallback runtime a `StubAssignments` — confirmado con `rails runner`:
`defined?(IdentityAccess::PermissionCheck)` → `"constant"` siempre, la rama del stub en
`Authorization::Controller#build_authorization_context` es inalcanzable.
(b) Sin `RoleAssignment` = cero permisos — `IdentityAccess::PermissionCheckTest` lo cubre
directamente a nivel de motor.
(c) Suspensión = cero permisos — gratis por construcción: `Current#resolve_institution_user` ya
solo resuelve membresías `active` desde antes de P1; sin `institution_user_id`, `PermissionCheck`
nunca llega a cargar ningún `role_assignment`.
(d) Orden compuerta #1 (entitlement) → compuerta #2 (RBAC) intacto — verificado por
`entitlement_gate_test.rb` (sin tocar `ApplicationController`), incluyendo el test específico "gate
order: entitlement wins over RBAC" con cero grants reales de por medio.

**Archivos creados/editados por rol:**
- Migración: `db/migrate/20260710144823_add_dating_to_role_assignments.rb`.
- Motor: `app/domains/identity_access/services/permission_check.rb` (nuevo);
  `app/domains/identity_access/models/role_assignment.rb` (+ scope `effective_now`).
- Seam (comentarios, sin cambio de comportamiento): `app/controllers/concerns/authorization/
  controller.rb`, `app/models/authorization/{stub_assignments,assignment_source}.rb`.
- Descriptor de scope + valores UUID (solo `teacher_management`, más los ids de sección
  compartidos que otros dominios ya referenciaban): `app/domains/teacher_management/services/
  {teacher_roster,department_roster}.rb`, `app/domains/group_management/services/
  {group_roster,student_roster}.rb`, `app/domains/schedules/services/
  {schedule_event_roster,subject_roster}.rb`, `app/domains/student_support/services/
  {accommodation_roster,disciplinary_log_roster,medical_history_roster}.rb`,
  `app/domains/counseling/services/case_roster.rb`.
- Infra de tests: `test/test_helper.rb` (`grant_role!`, `with_grants`, `with_raw_grants`,
  `revoke_all_role_assignments!`, `sign_in_as_member(grant_default_role:)`); 12 archivos de test
  integration ajustados mecánicamente (ver arriba); `test/models/identity_access/
  permission_check_test.rb` (nuevo, 12 tests).

**Confirmado: el descriptor de scope real solo se cableó en `teacher_management`** (el dominio del
caso de aceptación) — el resto de dominios tocados (group_management, schedules, student_support,
counseling) solo recibieron el cambio MECÁNICO de valor de id (string arbitrario → constante UUID
compartida) para que sus tests preexistentes de scope siguieran pasando contra `role_assignments`
reales; ninguno adoptó `scope_for` ni convirtió su roster a AR real. Eso sigue siendo backlog #4,
dominio por dominio, sin tocar en P1.

### v1.5.0 — 2026-07-10
- **Plano de control · Slice S4 (invoices + corte de periodo → factura borrador): ejecutado.** Cierra
  el track de billing del plano de control iniciado en S1 (S1→S2a→S2b→S3a→S4). Dos migraciones
  nuevas (`invoices`, `invoice_line_items` — `20260710120001-2`; nota de numeración abajo), globales,
  sin RLS/policy/FORCE, mismo patrón que `subscriptions`/`usage_*`. Modelos `ControlPlane::{Invoice,
  InvoiceLineItem}`: `Invoice` con ciclo de vida `draft`/`finalized`/`void` (`finalize!` congela
  `subtotal_cents` + `finalized_at`, solo desde `draft`; `void!` rechazado desde `finalized`; único
  no-void por `(institution, period_start, period_end)`, con validación de app espejo del índice
  parcial — se me olvidó al principio, la propia suite de tests lo atrapó, ver más abajo).
  `InvoiceLineItem` con `readonly? = persisted?` (permite el insert inicial, bloquea
  update/destroy individual) y CHECK de coherencia `kind`↔`addon_id`.
- **`ControlPlane::Billing::PriceResolver`** — resolución **plana** de tiers (H4): todo el headcount
  al `price_per_student_cents` del tier de `price_tiers_snapshot` cuyo rango `[min_students,
  max_students)` lo contiene (semántica de rango exacta a la que `ControlPlane::PlanPriceTier` ya usa
  en su propio chequeo de solapamiento — floor inclusivo, techo exclusivo); si ninguno cubre, usa
  `subscription.base_price_per_student_cents`. Puro, sin BD, unit-testeado con casos de borde.
- **`ControlPlane::Billing::PeriodCut`** — el orquestador. Guarda de contrato (H9: sin `subscriptions`
  activa que solape el periodo, rechaza — chequeado también en cada re-corte, no solo al crear);
  línea `base_seats` del snapshot de headcount más reciente ≤ `period_end` (si falta, omite la línea
  y deja flag en `notes`, H2); una línea `addon_fee` por cada entitlement activo que solape el
  periodo, con `coalesce(override_monthly_fee_cents, addon.monthly_fee_cents)` (**aquí los overrides
  de S2a se aplican por primera vez**, H3); una línea `usage_overage` por addon medido cuando
  `sum(usage_daily_rollups.total_quantity) − cupo (override o catálogo) > 0` (H7 — hoy da cero/ausente
  porque no hay emisión real hasta S3b, probado con rollups sintéticos). Idempotente (H1):
  re-cortar un `draft` reemplaza sus líneas en sitio vía `delete_all` (bulk SQL que bypasea
  deliberadamente el `readonly?` de `InvoiceLineItem` — una regeneración completa del borrador no es
  lo mismo que editar una línea suelta); re-cortar una `finalized` se rechaza
  (`PeriodCut::AlreadyFinalized`). Un mismatch de moneda en un override se **marca en `notes`**, no
  se aplica silenciosamente (H5). `ControlPlane::Billing::PeriodCutJob` envuelve el corte para Solid
  Queue **sin fijar `institution_id`** — el wrapper de GUC de `ApplicationJob` queda inerte a
  propósito, porque `invoices`/`invoice_line_items` son tablas globales. Rake
  `control_plane:cut_invoices[period_start,period_end,institution_id?]`, síncrono. 272 tests / 0
  fallos / 1 skip preexistente (39 nuevos).
- **Vistas**: `invoices#index` (real ahora, cross-institución, alimenta el nav existente) +
  `new`/`show` anidados bajo `institutions` (mismo patrón que `subscriptions` de S2a) con acciones
  finalizar/anular/re-cortar; sección "Facturas" nueva en el hub de institución.
- **Gotcha de entorno nuevo (S4): timestamps de migración no pueden ser >24h futuros respecto al
  reloj real de la máquina.** El prompt sugería `20260711...` (mañana en la narrativa ficticia del
  proyecto), pero Rails 8 valida `version.to_i < (Time.now.utc + 1.day).strftime(...)` — un
  `InvalidMigrationTimestampError` real, no cosmético. Se usó `20260710120001-2` (mismo día que S3a,
  antes de la ventana de 24h) en su lugar. Para el próximo slice: generar el timestamp de migración
  con el reloj real de la máquina en el momento de escribir el archivo, no proyectando la fecha
  narrativa del documento.
- **Convenciones fijadas por S4** (cierran el track de billing): factura **borrador, nunca
  auto-emitida** — finalizar es acción humana auditada, finalizar ≠ cobrar; resolución de tiers
  **plana** (no graduada); overrides aplicados con `coalesce` campo por campo, nunca todo-o-nada;
  el corte lee el **snapshot inmutable** de la subscription, nunca el catálogo vivo; el corte **suma
  `usage_daily_rollups`**, nunca eventos crudos; sin prorrateo, sin edición manual de líneas, sin
  tabla de periodos explícita en v1; `readonly?` en modelos append-only bloquea mutación individual
  pero un servicio puede regenerar en bloque vía `delete_all` a propósito.
- **Reafirma la limitación conocida heredada de S3a** (no arreglada en S4): `base_seats` factura
  sobre `students` activos de la institución, no sobre matrícula en el término activo — ver §13.
- **Forward notes documentadas, no construidas en S4:** (a) S3b (emisión real, requiere M1)
  alimentará `usage_overage` sin tocar `PeriodCut`; (b) riel de pago fuera de alcance de v1; (c)
  hardening: exclusion constraints, prorrateo, edición manual, tabla `billing_periods`; (d) RBAC
  intra-plano y provisioning de instituciones siguen sin construirse; (e) schedule recurrente de
  los tres jobs de billing (`SnapshotJob`, `RollupJob`, `PeriodCutJob`) diferido.

### v1.4.0 — 2026-07-10
- **Plano de control · Slice S3a (headcount snapshots + pipe genérico de metering): ejecutado.**
  Tres migraciones nuevas (`student_headcount_snapshots`, `usage_events`, `usage_daily_rollups` —
  20260710000001-003), globales, sin RLS/policy/FORCE, mismo patrón que `subscriptions`/
  `institution_entitlements`. Modelos `ControlPlane::{StudentHeadcountSnapshot,UsageEvent,
  UsageDailyRollup}` con validaciones-espejo; `UsageEvent#readonly? = persisted?` (permite el insert
  inicial, bloquea cualquier update/destroy después — append-only también a nivel de AR, no solo de
  esquema). Un snapshot por `(institution_id, as_of_date)`; un rollup por
  `(institution_id, addon_id, unit, usage_date)`; un evento por
  `(institution_id, addon_id, idempotency_key)` — los tres únicos parciales/compuestos.
- **Headcount (único touch en `core`):** `Core::Headcount::Snapshotter.call(institution:, as_of:)`
  cuenta `GroupManagement::Student` con `status: "active"` de la institución — decisión explícita de
  S3a: `enrollments.term` es un string libre sin FK a `academic_terms`, así que "matrícula activa en
  el término activo" no es un join real en el esquema actual; `academic_term_label` es solo una
  etiqueta congelada del término activo, no un filtro. `Core::Headcount::SnapshotJob` (hereda
  `ApplicationJob`) es el **primer job real** que ejercita el mecanismo de réplica de GUC que
  `ApplicationJob` traía sin usar desde el commit inicial — ver el hallazgo de bug abajo. Disparo
  manual vía `bin/rails control_plane:snapshot_headcount[institution_id]` (síncrono, no requiere
  worker); schedule recurrente diferido.
- **Pipe de uso genérico (control plane, sin GUC):** `ControlPlane::Usage::Ingest.call(institution:,
  addon_key:, unit:, occurred_at:, idempotency_key:, quantity:, metadata:)` — idempotente (no-op en
  duplicado, nunca falla en re-emisión), valida que el addon exista y sea `metered: true`, **no**
  exige entitlement activo (el uso es un hecho; S4 reconcilia qué se cobra). `unit` se congela en el
  evento — string opaco, **M1 sigue sin cerrar**. `ControlPlane::Usage::RollupJob.perform_now(fecha)`
  agrega por bucket, **idempotente** (recomputa completo desde `usage_events`, nunca incrementa —
  re-correr no duplica ni dobla el conteo). Probado **solo** con llamadas sintéticas; **ningún
  dominio emite eventos reales todavía (S3b)**. Vistas read-only nuevas en el hub de institución de
  S2a (headcount + rollups). 233 tests / 0 fallos / 1 skip preexistente (31 nuevos).
- **Bug real encontrado y corregido al testear `SnapshotJob`, no solo happy-path:** el test de "el
  GUC no se filtra" (escrito contra una query real bajo RLS, no una relectura de `current_setting()`
  — esa relectura puede ser engañada por el query cache de AR dentro de una transacción, lección de
  v1.3.0) reveló que, dentro de un test de Minitest (que envuelve todo el test en una transacción
  englobante), el `ActiveRecord::Base.transaction do ... end` de `ApplicationJob#around_perform` se
  vuelve un SAVEPOINT, no una transacción de nivel superior — y Postgres **no** limpia un
  `SET LOCAL` al liberar un savepoint, solo al hacer COMMIT/ROLLBACK del nivel más externo. Un
  headcount de una institución previa aparecía visible sin ningún GUC fijado. **Corregido con un
  `ensure Tenant::Guc.reset!` explícito** en `ApplicationJob#around_perform` — un `RESET` inmediato
  que no depende de límites de transacción, blindando a cualquier job futuro que herede de
  `ApplicationJob`, no solo a `SnapshotJob`. Ver §9.7-7 (cerrado, primer caso real del patrón).
- **Discrepancia real resuelta en recon (con tu confirmación):** el prompt asumía "matrícula activa
  en el término activo" como si `enrollments` y `academic_terms` estuvieran conectados — no lo están
  (`enrollments.term` es un string libre, sin FK). Se decidió contar solo `students.status == "active"`
  en vez de asumir una convención de nombres no verificada en ningún otro lugar del código.
- **Convenciones fijadas por S3a:** todo job tenant-scoped nuevo hereda `ApplicationJob`, nunca
  reinventa el manejo del GUC; todo test de "no fuga de GUC" usa una query real bajo RLS, nunca una
  relectura de `current_setting()`; eventos de uso son idempotentes por no-op, rollups son
  idempotentes por recómputo completo (nunca incremento); el corte de periodo (S4) sumará rollups,
  nunca eventos crudos; el headcount es un número empujado bajo GUC, nunca una lectura cross-tenant
  del control plane.
- **Forward notes documentadas, no construidas en S3a:** (a) S3b (emisión real por dominio) requiere
  cerrar M1 primero y tocará `app/domains/*` transversalmente, mismo patrón "una sola pieza" que S2b;
  (b) schedules recurrentes de `SnapshotJob`/`RollupJob` diferidos; (c) S4 consumirá snapshots +
  rollups + overrides de entitlements + tiers de planes; (d) exclusion constraints de hardening
  siguen pendientes.

### v1.3.0 — 2026-07-09
- **Plano de control · Slice S2a (subscriptions + institution_entitlements): ejecutado.** Dos
  migraciones nuevas (`subscriptions`, `institution_entitlements` — 20260709000001-002), globales,
  sin RLS/policy/FORCE, `institution_id` como **FK a `institutions`, nunca tenancy** (mismo patrón
  que `addons`/`plans`/`platform_admins`). `ControlPlane::Subscription.sign!` congela un **snapshot
  inmutable** de la tarifa del plan (escalares + `price_tiers_snapshot` jsonb) al firmar — editar el
  plan vivo después no toca subscriptions ya firmadas. `ControlPlane::Entitlement` (table_name
  `institution_entitlements`, nombrado así para coincidir con el scaffolding stub previo, no
  `InstitutionEntitlement`) con `grant`/`revoke!`/`reactivate!`, fechado, y overrides negociados
  (almacenados, no aplicados hasta S4). Índices únicos parciales: una subscription activa por
  institución, un entitlement activo por institución+addon. Predicado
  `ControlPlane::Entitlements::Check.entitled?(institution:, addon_key:, at:)` — ignora overrides y
  `addon.status` a propósito. F10-bis cerrado: `AddonsController#retire` rechaza si hay entitlements
  activos dependientes. CRUD real bajo `/control_plane` (institutions read-only como hub;
  subscriptions anidadas; entitlements extendido de index-stub a CRUD completo), todo auditado. 192
  tests / 0 fallos / 1 skip preexistente (34 nuevos).
- **Plano de control · Slice S2b (gate de entitlement en el inquilino): ejecutado.** Primer slice que
  toca `app/domains/*` de forma transversal — con una sola pieza, no ramificación por dominio.
  `Core::Institution#entitled?(addon_key)` (delega en `ControlPlane::Entitlements::Check`);
  `Core::Access::EntitledAddonKeys.for(institution)` construye el Set de addons entitled;
  `Current.entitled_addon_keys` lo memoiza una vez por request (patrón `attribute` + `super ||
  self.attr = ...`, no un ivar plano, para que `CurrentAttributes#reset` lo limpie entre requests —
  un ivar plano habría sobrevivido al reset y filtrado entitlements revocados a la siguiente
  request). `Entitlement::Controller` (concern único, incluido una vez en `ApplicationController`)
  infiere el `addon_key` del namespace del controller (`Cafeteria::MenuController` → `"cafeteria"`) y
  corta con la página `errors/module_not_entitled` **antes** de que la acción llegue a `authorize!`.
  `Entitlement::Registry` (tenant-side, `config/entitlements/*.rb`, un archivo por dominio
  addon-gated, mismo patrón lazy-load que `Navigation::Registry`) es la lista que el runtime del
  inquilino consulta — **nunca** referencia `ControlPlane::AddonCatalog::DOMAIN_KEYS` en runtime, solo
  un test (`registry_consistency_test.rb`) cruza ambas listas para atrapar drift. `nav_items`
  (`ApplicationHelper`) filtra por el mismo memo antes del `can?` cosmético existente, reutilizando el
  `domain:` que `Navigation::Item` ya traía. Ningún archivo de dominio addon-gated
  (`cafeteria`/`transportation`/`schedules`/`student_support`/`counseling`/`finance`/`communication`/
  `analytics_bi`) fue tocado — el único touch en `app/domains/*` fue en `core` (dueño de identidad),
  exactamente como S2a lo había dejado pendiente. 202 tests / 0 fallos / 1 skip preexistente (10
  nuevos).
- **Dos bugs reales corregidos en S2b durante la verificación, no solo happy-path:**
  1. El diseño inicial usaba `prepend_before_action` para el gate (siguiendo la instrucción literal
     de "correr antes de `authorize!`") — pero `authorize!` se llama a mano dentro de cada acción, no
     es un `before_action`, así que prepender no aportaba nada para ese objetivo y en cambio saltaba
     por delante de `TenantScoped`'s `around_action`, rompiendo la propia resolución de
     `Current.institution` que el gate necesita. Corregido a `before_action` normal, incluido al
     final de `ApplicationController` (después de `TenantScoped` y `Authentication`).
  2. La página "módulo no habilitado" podía reventar (`NoMethodError` sobre `nil.name`) cuando
     disparaba con `Current.institution` nil (fail-closed, E6): `shared/_role_switcher` asume un
     actor autenticado con institución. Solución: usar el layout `auth` (el mismo de las pantallas
     pre-login) en ese caso específico, sin tocar `_role_switcher`.
  3. **Regresión real detectada en 27 tests preexistentes** (`cafeteria`, `transportation`,
     `student_support`, `schedules`, `analytics_bi`): con el gate activo, la institución efímera de
     `sign_in_as_member` no tenía ningún entitlement, así que todo dominio gateado empezó a responder
     "no habilitado" en tests escritos antes de que el gate existiera. Arreglado en el helper
     compartido (`grant_full_entitlements`, otorga los 8 dominios por defecto) — no archivo por
     archivo, manteniendo el "toque uniforme" también en infraestructura de test.
- **Reconciliación de discrepancia encontrada en recon:** S2a se había mergeado (commit `93cfdfd`)
  sin actualizar este documento — v1.2.0 seguía describiendo `institution_entitlements`/
  `subscriptions` como 🔴 pendientes. Este bump reconcilia ambos slices de una vez.
- **Convenciones fijadas por S2a/S2b** (aplican a cualquier gate futuro del control plane hacia el
  inquilino): snapshot inmutable de tarifa en `subscriptions`; `institution_id` como FK global
  no-tenancy en tablas de control plane; una subscription activa por institución, un entitlement
  activo por institución+addon; overrides almacenados-no-aplicados-hasta-S4; gate #1 (entitlement)
  siempre antes de gate #2 (RBAC), como una sola pieza incluida una vez; fundacionales nunca gatean
  por ausencia de registro, no por allowlist; el runtime del inquilino nunca referencia una constante
  del control plane, solo un test de consistencia.
- **Forward notes documentadas, no construidas en S2:** (a) verificar el orden entitlement→
  `authorize!` cuando P1 (RBAC real) cierre; (b) S3 (metering, arrastra M1) y S4 (invoices, aplica
  snapshot/overrides) siguen pendientes; (c) exclusion constraint `daterange`+GiST para periodos de
  entitlement, documentada no construida; (d) provisioning de instituciones (crear/editar desde el
  control plane) sigue sin existir; (e) RBAC intra-plano (`platform_admin`) sigue sin construirse.

### v1.2.0 — 2026-07-08
- **Plano de control · Slice S1 (catálogo de facturación): ejecutado.** Tres migraciones nuevas
  (`addons`, `plans`, `plan_price_tiers` — 20260708000016-018), globales, sin RLS, sin
  `institution_id`, siguiendo el patrón de `platform_admins`. Modelos `ControlPlane::{Addon,Plan,
  PlanPriceTier}` con validaciones-espejo de los CHECK de BD. CRUD completo (`new/create/edit/update`
  + retiro/reactivación suaves, nunca destroy) en `ControlPlane::{Addons,Plans,PlanPriceTiers}Controller`,
  todas las mutaciones auditadas vía `ControlPlane::Audit.log`. Seed idempotente
  (`ControlPlane::SeedCatalog` + `bin/rails control_plane:seed_catalog`). 158 tests / 0 fallos / 1
  skip preexistente (36 nuevos: modelo + integración).
- **Convenciones fijadas por S1** (aplican a cualquier billing futuro): dinero siempre en
  `*_cents bigint`, nunca float; `currency text` default `'COP'` con `CHECK (char_length = 3)`, sin
  FX ni impuestos; `addons.key` validado contra la lista canónica de dominios addon-able
  (`ControlPlane::AddonCatalog::DOMAIN_KEYS`, nueva — no existía ningún registro de dominios en
  código antes de esta versión); retiro suave (`status` active/retired) para entradas de catálogo;
  `plan_price_tiers` como tabla hija explícita (no JSONB), hard-deletable a diferencia de su plan.
- **Reconciliación de discrepancias encontradas en recon** (el repo iba adelante de este documento):
  1. **S0 (auth de `platform_admins` + MFA + gestión de administradores) ya estaba real** desde una
     iteración anterior no reflejada en v1.1.0 — este documento decía "sigue en fase de
     componentes/vistas stub" para todo el plano de control; ya no es cierto para S0 ni para S1.
  2. **S1 no partió de cero**: ya existía un scaffold stub previo (pre-S0) con
     `ControlPlane::{Addons,Plans}Controller#index` sirviendo `Stubs::Fixtures` y vistas con
     vocabulario de estado `available/beta/deprecated`. Se extendieron esos archivos in-place en vez
     de crear paralelos — el vocabulario de estado real es `active/retired` (F10); `_addon_card` se
     actualizó para aceptar ambos vocabularios sin romper `previews#index` (galería de componentes
     dev-only, que sigue usando los fixtures).
  3. **El stub anterior incluía addons para `staff_management` y `teacher_management`** — ambos
     excluidos del catálogo real por F14 (`teacher_management` es fundacional; `staff_management` es
     CHECKPOINT E, sin resolver). El seed real solo cubre los 8 dominios addon-able confirmados.
  4. **`plans`/`addons` dejaron de mostrarse cruzados en la misma pantalla** (el stub viejo
     renderizaba addon cards dentro de `plans#index`) — F9 los declara catálogos independientes sin
     FK entre sí, así que `plans#index` ya no referencia addons.
- **Gotcha operativo nuevo:** `bin/rails test` con paralelización por fork (`workers:
  :number_of_processors`, default cuando la suite pasa el umbral de 50 tests) **crashea el proceso
  Ruby** en esta máquina (YJIT + fork) — reproducido dos veces de forma independiente. Con
  `parallelize(workers: 1)` la suite completa corre limpia (158/0/0/1). No es un problema del código
  de S1 (confirmado corriendo la suite completa sin paralelizar); es un problema de entorno a
  investigar aparte — mientras tanto, correr la suite completa en serie si se sospecha de un fallo
  real, no asumir que un crash de proceso es un fallo de test.
- **Forward notes documentadas, no construidas en S1** (ver §12.5): (a) `retire!` de un addon deberá
  verificar entitlements activos cuando exista S2; (b) exclusion constraint `int4range`+GiST para
  no-solapamiento de tiers a nivel de BD (hoy solo se valida en la app); (c) `addons.unit` sigue
  provisional hasta cerrar **M1**; (d) RBAC intra-plano (roles/scopes de `platform_admin`) sigue sin
  construirse — cualquier platform_admin autenticado administra el catálogo completo.

### v1.1.0 — 2026-07-08
- **Módulo de autenticación/onboarding: cerrado parcialmente.** Se ejecutó la mayor parte del track de identidad sobre el prompt de la iteración 8: esquema completo (`national_id`×2, `academic_terms`, `guardian_students`, `invitations`, `email_otps`, `audit_events`, `roster_import_batches/rows`, `institution_users.status` — 11 migraciones, todas con RLS+policy+índice donde aplica), auth nativa Rails 8 + MFA por correo, registro por invitación (con resolución de tenant por subdominio del link, sin BYPASSRLS), auditoría append-only real (a nivel de rol de BD), `Core::People::Resolver`, y gestión de personas (crear/invitar/reenviar/suspender/reactivar) con permiso `people.manage` nuevo. 122 tests / 0 fallos.
- **⚠-1 y ⚠-2 cerrados** — ambos confirmados y validados directamente en código, no solo en diseño. Ver §9.5/§9.6/§11.
- **Pendiente explícito documentado** (§9.7, §12.1): `RosterImport::*` (CSV batch), `Core::Access::GuardianScope`, vistas de autoservicio de estudiante/acudiente/docente, visor de `audit_events`, bandeja de discrepancias.
- **Nuevo borde abierto P1**: el fallback de autorización a `StubAssignments` cuando `Current.institution_user` es `nil` (incluida una membresía recién suspendida) sigue dando la persona stub genérica en vez de cero permisos — elevado en prioridad en el backlog (§12.3) porque con login real ya wireado deja de ser un detalle de fase de vistas.
- **Nuevo borde abierto P2**: `institution_users.role` (string libre) no tiene lectores — posible fuente de confusión con el RBAC real (`role_assignments`).
- Correcciones a la Sección 3.3 con los nombres reales del repo (`Tenant::Resolver`/`Tenant::Guc` en vez de `CurrentTenant`; `edu_bi_reader` en vez de `edu_analytics`) y dos gotchas operativos nuevos: `EDU_MIGRATOR_PASSWORD` no vive en el repo (cómo resetearlo en dev local), y migrar `development` no migra `test`.
- Gotcha de diseño documentado en §9.4: `has_secure_password` por defecto es incompatible con "cuenta sin contraseña hasta completar invitación"; se corrigió con `validations: false` + validaciones explícitas — cualquier código futuro que toque `Core::User` debe saberlo.
- Sección 4 (mapa de dominios) actualizada para reflejar que `core` ahora posee la identidad (`Core::User`, `Core::InstitutionUser`, `Core::Session`), no un dominio de identidad aparte, y que `guardian_students` real coexiste con la legacy `student_support.student_guardians` sin haberla migrado.

### v1.0.0 — 2026-07-07
- Consolidación inicial. Se reúnen en un solo documento las 8 iteraciones de diseño previas: fundación de arquitectura, diagnóstico de permisos BD, roles y dominios, organización de dominios, prompt combinado identity/finance/counseling, vistas + roles, plano de control + billing, y módulo de autenticación/onboarding.
- Se fija la convención de versionado de este documento y el backlog de próximas iteraciones.
- Se registran los bordes abiertos ⚠-1, ⚠-2, CHECKPOINT E, y las decisiones menores B1/B2/M1.

---

## Matriz rol × dominio (§6.4 de v1.5.0)

> Copiada verbatim. El magro (`PROJECT_STATE.md`) conserva el caso de aceptación de referencia
> (§6.5) y un puntero aquí; esta tabla completa vive solo en HISTORIA.

| Rol | core | teacher_mgmt | group_mgmt | schedules | student_support | cafeteria | transportation | analytics_bi | identity_access |
|---|---|---|---|---|---|---|---|---|---|
| teacher | ✔ sus grupos | — | ✔ sus grupos | ✔ propio | — | — | — | — | — |
| area_lead | ✔ del área | ✔ **evalúa** su dpto | — | — | — | — | — | — | — |
| homeroom | ✔ su grupo | — | ✔ su grupo | ✔ | ✔ convivencia | — | — | — | — |
| counselor | ✔ lectura | — | — | — | ✔ counseling | — | — | — | — |
| medical_staff | ✔ lectura mín. | — | — | — | ✔ **dueño historia médica** | consulta alérgenos | — | — | — |
| academic_secretary | ✔ | ✔ lectura | ✔ | ✔ | — | — | — | — | — |
| registrar (HE) | ✔ | — | ✔ | ✔ | — | — | — | — | — |
| cafeteria_staff | — | — | — | — | bloqueo alérgenos (lectura) | ✔ **checkout/menú** | — | — | — |
| transport_coordinator | ✔ lectura mín. | — | — | ✔ ventanas ruta | — | — | ✔ | — | — |
| driver / route_monitor | — | — | — | — | — | — | ✔ **check-in/out** | — | — |
| bi_auditor | — | — | — | — | — | — | — | ✔ cross-tenant RO | — |
| institution_admin | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ **gestiona** |
| super_admin | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ cross-tenant |
| **student** (portal) | ✔ propio | — | ✔ sus grupos | ✔ propio | — | ✔ saldo propio | ✔ propio | — | — |
| **guardian** (portal) | ✔ sus hijos | — | — | ✔ hijos | ver alertas de hijos | ✔ saldo hijos | ✔ hijos | — | — |

---

## Narrativa detallada: modelo de datos del plano de control (§7.2 de v1.5.0, previo a compactación)

> Copiado verbatim. El magro reemplaza estos párrafos por una tabla de estado compacta
> (pieza | slice | estado | invariante clave) — el detalle de "cómo se construyó" cada pieza vive
> aquí.

- **`addons`** ✅ **migrado y con CRUD (S1)**. Catálogo. 1 addon = 1 dominio **addon-able** (F14 —
  fundacionales `core`/`teacher_management`/`group_management`/`identity_access` excluidos;
  `ControlPlane::AddonCatalog::DOMAIN_KEYS` es la lista canónica). `monthly_fee_cents` (bigint,
  nunca float), `metered`, y para medidos `included_quota` + `unit` + `overage_unit_price_cents`.
  Retiro suave (`status` active/retired), nunca hard-delete.
- **`plans`** ✅ **migrado y con CRUD (S1)** — tarifa base **por alumno** (`base_price_per_student_cents`)
  + brackets de volumen en **`plan_price_tiers`** (tabla hija explícita, no JSONB; hard-deletable,
  a diferencia de `plans`/`addons`). No hay FK entre `plans` y `addons` (F9, catálogos
  independientes). La tarifa se **congelará como snapshot** en `subscriptions` al firmar — **eso es
  S2a**, S1 solo almacenaba el pricing, no lo aplicaba a ningún headcount/factura.
- **`subscriptions`** ✅ **migrado y con CRUD (S2a)** — contrato institución↔plataforma. **Snapshot
  inmutable** al firmar (`plan_key`, `base_price_per_student_cents`, `currency` escalares +
  `price_tiers_snapshot` jsonb); `plan_id` es solo provenance (nullable). Una sola activa por
  institución (índice único parcial). `institution_id` aquí es **FK a la tabla global `institutions`,
  nunca tenancy** — sin RLS/policy/FORCE, sin GUC (mismo patrón que `platform_admins`/`addons`).
- **`institution_entitlements`** ✅ **migrado y con CRUD (S2a)** — institución × addon: conceder/
  revocar/reactivar, fechado (`valid_from`/`valid_until`), y **overrides negociados** (precio/cupo
  distinto al catálogo, **almacenados, no aplicados** hasta S4). Un solo entitlement activo por
  institución+addon (índice único parcial). El predicado de lectura,
  `ControlPlane::Entitlements::Check.entitled?(institution:, addon_key:, at:)`, ignora overrides y
  `addon.status` a propósito — retirar un addon con entitlements activos se **bloquea**
  (`ControlPlane::Addon#retire!`, F10-bis, cerrado en S2a). **S2b** conectó este predicado al lado
  del inquilino — ver §7.1 del magro.
- **`student_headcount_snapshots`** ✅ **migrado (S3a)** — headcount **empujado por el tenant** (no
  lectura viva del `students` del inquilino desde el control plane → boundary limpio + número
  defendible en factura). `Core::Headcount::Snapshotter` cuenta `GroupManagement::Student` con
  `status: "active"` para la institución (decisión de S3a: `enrollments.term` es un string libre sin
  FK a `academic_terms`, así que "matrícula activa en el término activo" no es un join real en el
  esquema actual — `academic_term_label` es solo una etiqueta descriptiva del término activo, no un
  filtro). Un snapshot por `(institution_id, as_of_date)` — re-correr actualiza, no duplica.
  `Core::Headcount::SnapshotJob` (hereda `ApplicationJob`) es el **primer job real** que fija y
  libera el GUC del tenant fuera de un request — ver la narrativa de §9.7-7 más abajo.
- **`usage_events` / `usage_daily_rollups`** ✅ **migrado, pipe genérico (S3a)** — metering
  agnóstico de dominio, **sin GUC** (tablas globales). `ControlPlane::Usage::Ingest` es idempotente
  por `(institution, addon, idempotency_key)` (no-op en duplicado, nunca falla) y valida que el addon
  exista y sea `metered: true` — **no** exige entitlement activo (el uso es un hecho, S4 reconcilia
  qué se cobra). `ControlPlane::Usage::RollupJob` agrega por `(institution, addon, unit, usage_date)`,
  **idempotente** (recomputa completo, nunca incrementa) — el corte de periodo de S4 sumó estos
  rollups, nunca eventos crudos. **Sin emisión real por ningún dominio todavía (S3b)** — probado solo
  con llamadas sintéticas a `Ingest`. `unit` es un string opaco; **M1 sigue sin cerrar**.
- **`invoices` / `invoice_line_items`** ✅ **migrado, con corte real (S4)** — cada línea con `kind` ∈
  (`base_seats`, `addon_fee`, `usage_overage`) + FK a su origen (`addon_id`, nulo solo para
  `base_seats`). `ControlPlane::Billing::PeriodCut` ensambla la factura **borrador** (`draft`) para
  un `(institution, period_start, period_end)`: `base_seats` = headcount del snapshot más reciente
  ≤ `period_end` (**limitación conocida heredada de S3a, no arreglada en S4**: ese headcount cuenta
  `students` activos, no matrícula en el término activo — ver Guardrails del magro) × precio resuelto
  por `ControlPlane::Billing::PriceResolver` (tier **plano** — `price_tiers_snapshot` de la
  subscription, **nunca** el catálogo vivo); `addon_fee` = una línea por cada entitlement activo que
  solape el periodo; `usage_overage` = `usage_daily_rollups` sumados del periodo menos cupo, si > 0.
  **Aquí los overrides negociados de S2a (`override_monthly_fee_cents`, `override_included_quota`,
  `override_unit_price_cents`) se aplican por primera vez** (`coalesce` sobre el catálogo) — hasta S4
  solo se almacenaban. Idempotente: re-cortar un `draft` reemplaza sus líneas (`delete_all`, que
  **bypasea** el `readonly?` de `InvoiceLineItem` — un borrado masivo deliberado no es lo mismo que
  editar una línea); re-cortar una `finalized` se rechaza. Sin subscription activa que solape el
  periodo → rechazo total (no se factura sin contrato); sin snapshot de headcount → borrador sin
  línea `base_seats` + flag en `notes`. Ciclo de vida `draft`/`finalized`/`void`: `finalize!` congela
  `subtotal_cents` y `finalized_at`, auditado con el `platform_admin` actuante; **finalizar ≠
  cobrar**, no hay riel de pago en v1. **Sin GUC** (tablas globales) — el corte nunca fija
  `app.current_institution_id`.
- **`platform_admins`** ✅ **migrado, con auth nativa + MFA por correo (S0, ya real desde antes de
  este documento)** — super-admins de plataforma aparte de `Core::User`, no un flag. El MFA propio
  (`ControlPlane::Otp::*`) se construyó independiente de `IdentityAccess::Otp::*` en vez de
  reutilizarlo — no hubo que adaptar la firma genérica, se duplicó el ~concern~ delgado.

---

## Narrativa detallada: módulo de autenticación / onboarding (§9.1–9.6 de v1.5.0)

> Copiado verbatim. El magro comprime esto a un párrafo de "qué existe" + la lista de pendientes
> (§9.7 original, que sigue vivo en el magro) + los puntos legales vigentes (§9.8 original).

### 9.1 Decisiones del modelo conceptual (sin cambios, ya implementadas)

- **Nadie se autorregistra.** La institución crea los registros (`Core::People::Resolver`, hoy solo
  desde la UI de "crear individual" — el batch CSV/roster **no existe todavía**, ver pendientes). La
  persona solo **completa** su cuenta vía **invitación** al correo registrado
  (`IdentityAccess::Invitations::Completer`).
- **El documento es un identificador conocible, no un secreto.** `national_id` vive cifrado
  (`encrypts ..., deterministic: true`) tanto en `Core::User` (global) como en
  `GroupManagement::Student` (tenant-scoped) — ver ⚠-2 cerrado más abajo. Resuelve *alcance*, nunca
  *identidad*; nunca se usó como credencial de acceso en ningún flujo construido.
- **Campos raíz de confianza son de solo lectura al completar la invitación.** La vista
  `invitations/edit.html.erb` muestra nombre/correo en solo lectura y solo permite fijar
  contraseña; existe un botón "reportar discrepancia"
  (`IdentityAccess::Invitations::DiscrepancyReporter`) que **audita** el reclamo (reutiliza
  `audit_events`, no crea una tabla nueva de tickets) en vez de dejar editar el dato.
- **Login único por subdominio + MFA por correo (OTP).** Implementado end-to-end y probado. MFA
  fuerte/biometría sigue pospuesto.
- **Usuarios internos: misma lógica.** Confirmado — no hay un segundo camino de auth para staff vs.
  personas externas; todos pasan por `SessionsController` + `EmailOtpsController`.

### 9.2 Cierre del "borde de acudientes" (⚠ CONFIRMAR-2 original)

**Cerrado y verificado en código.** `Core::GuardianStudent` (`guardian_user_id`, `student_id`,
`relationship`, `status`) es la relación real; `Core::User#guardian_links`/`#guarded_students` y
`GroupManagement::Student#guardian_students`/`#guardian_users` la exponen desde ambos lados. No hay
ningún rol RBAC `guardian` en el catálogo de permisos. Pendiente real: `Core::Access::GuardianScope`
(el query object que resuelve "mis acudidos del término activo") **no existe todavía** — los
portales de acudiente/estudiante que ya existían (commit anterior a este módulo) siguen sobre datos
stub para ese propósito específico.

### 9.3 Lo que quedó REAL en esta iteración (no solo diseñado)

| Pieza | Estado | Dónde |
|---|---|---|
| Esquema (`national_id`×2, `academic_terms`, `guardian_students`, `invitations`, `email_otps`, `audit_events`, `roster_import_batches/rows`, `institution_users.status`) | ✅ 11 migraciones aplicadas (dev y test), todas con RLS `ENABLE+FORCE`+policy+índice `institution_id`-leading donde aplica | `db/migrate/20260708000001..000011` |
| Auth nativa Rails 8 | ✅ | `Authentication` concern, `Core::Session`, `Current`, `SessionsController` |
| MFA por correo | ✅ (rate-limited, anti-enumeración, lockout a 5 intentos) | `IdentityAccess::Otp::{Issuer,Verifier,Result}`, `EmailOtpsController` |
| Registro por invitación | ✅ (link con subdominio embebido — sin BYPASSRLS ni token+institution_id) | `IdentityAccess::Invitations::{Issuer,Completer,DiscrepancyReporter}`, `InvitationsController` |
| Auditoría append-only | ✅ (`REVOKE UPDATE/DELETE` a nivel de rol de BD, no solo convención) | `IdentityAccess::Audit`, `IdentityAccess::AuditEvent` |
| Resolución de persona (evita duplicar `users`) | ✅ | `Core::People::Resolver` |
| Gestión de personas (crear/invitar/reenviar/suspender/reactivar) | ✅ | `IdentityAccess::PeopleController`, permiso `people.manage` |
| Suspensión con efecto real (no cosmético) | ✅ (bloquea login Y quita grants en la siguiente request de una sesión ya abierta) | `SessionsController#authenticate_credentials`, `Current#resolve_institution_user`, `Core::InstitutionUser#suspend!/#reactivate!` |
| Bounce handling | ✅ como unidad testeable | `IdentityAccess::Invitations::BounceHandler` — **NO conectado a ningún webhook real todavía** |
| Expiración de invitaciones vencidas | ✅ como barrido de bookkeeping | `IdentityAccess::Invitations::Expirer` — corre oportunísticamente desde `PeopleController#index`; **no hay job recurrente en Solid Queue todavía** |
| Tests | ✅ 122 runs / 0 fallos / 1 skip preexistente (incluye aislamiento cross-tenant por RLS del link de invitación) | `test/integration/{authentication,invitations,people_management}_test.rb` |

### 9.4 Gotcha real encontrado y corregido: `has_secure_password` y personas sin contraseña

`has_secure_password` (default de Rails) **exige `password_digest` presente incluso al crear**,
sin importar si el registro es nuevo. Esto es **incompatible** con "la institución crea la cuenta
sin contraseña; la persona la fija después" — con el default, `Core::People::Resolver` no podía
persistir un `Core::User` recién creado. Se corrigió con
`has_secure_password validations: false` + `validates :password, confirmation: true, allow_nil: true`
+ `validates :password, length: { maximum: ... }, allow_nil: true` en `Core::User`.
**Cualquier código futuro que cree un `Core::User` debe saber que un `password_digest` nulo es un
estado válido y esperado**, no un bug.

### 9.5 ⚠ CONFIRMAR-1 original (identidad global) — CERRADO

Validado por código, no solo por diseño: `Core::User` es global (`self.table_name = "users"`, sin
`institution_id`, sin RLS), `email` es único global (`citext` + `validates uniqueness: true`).
`SessionsController#authenticate_credentials` busca por `email` sin scope de tenant y luego
verifica membresía activa por separado. No se impuso "un correo = un tenant" en ningún punto.

### 9.6 ⚠ CONFIRMAR-2 original (dónde vive el documento) — CERRADO

`national_id` vive en **ambos** lados, cifrado deterministamente: `Core::User.national_id` (global,
único parcial global) para el humano con login, y `GroupManagement::Student.national_id`
(tenant-scoped, único parcial por `institution_id`) para el menor sin login. `Core::People::Resolver`
usa `national_id` como llave de resolución preferente sobre `email` quien lo tenga.

---

## Narrativa detallada: §9.7 punto 7 — job que reestablece el GUC de tenant (primer caso real)

> Copiado verbatim del punto 7 de §9.7 de v1.5.0. El magro conserva un resumen de una línea con
> puntero aquí; la regla durable (heredar `ApplicationJob`, verificar fuga con query real bajo RLS)
> ya vive, por separado, en Guardrails del magro.

**Job de Solid Queue que reestablece el GUC de tenant — ✅ CERRADO, primer caso real (S3a).**
`ApplicationJob` ya traía el mecanismo (`attr_accessor :institution_id` + `serialize`/`deserialize`
que lo transportan + `around_perform` que fija el GUC en una transacción) desde el commit inicial,
pero **nunca se había usado ni testeado** hasta que `Core::Headcount::SnapshotJob` lo heredó en
S3a. Al escribir el test de "el GUC no se filtra" (con una query real bajo RLS, no una relectura
de `current_setting()` — esa relectura puede ser engañada por el query cache de AR dentro de una
transacción, ver Changelog v1.3.0) **se encontró un bug real**: dentro de un test de Minitest
(que envuelve todo el test en una transacción englobante), el `ActiveRecord::Base.transaction do
... end` del job se vuelve un SAVEPOINT, no una transacción de nivel superior, y Postgres **no**
limpia un `SET LOCAL` al liberar un savepoint — solo al hacer COMMIT/ROLLBACK del nivel más
externo. Arreglado con un `ensure Tenant::Guc.reset!` explícito en `ApplicationJob#around_perform`
(un `RESET` inmediato, no dependiente de límites de transacción) — blinda a **cualquier** job
futuro que herede de `ApplicationJob`, no solo a `SnapshotJob`. **Patrón a copiar**: todo job
tenant-scoped nuevo debe heredar `ApplicationJob` (no reinventar el manejo de GUC) y su test debe
verificar la ausencia de fuga con una query real bajo RLS, nunca con una relectura de
`current_setting()`.

---

## Cambios ya implementados por iteración (§10 de v1.5.0, tabla histórica)

> Copiada verbatim. Estado acumulado si cada prompt generado fue ejecutado en Claude Code, marcado
> por iteración cronológica. Reemplazada en el magro por la tabla de estado de §7 (piezas actuales)
> más el Changelog completo (arriba).

| # | Iteración | Entregable | Estado asumido |
|---|---|---|---|
| 1 | **Fundación de arquitectura** | Stack bloqueado, tenancy row-level + RLS, identidad global, UUIDv7 nativo, roles PG, `app/domains/*` scaffold, config generators UUID, YJIT | ✅ Ejecutado |
| 2 | **Diagnóstico de permisos BD** | `bin/migrate` con `edu_migrator`, `CREATE` en las 3 bases Solid, `schema_format = :sql` entendido | ✅ Corregido |
| 3 | **Roles y dominios** | Catálogo `roles`/`permissions`/`role_permissions`, `role_assignments` con scope explícito, ERD de `identity_access` | ✅ Ejecutado (track esquema) |
| 4 | **Organización de dominios** | `dominios_edu_platform.md`, prompt de scaffold, `notifications` → `communication` | ✅ Ejecutado (scaffold + componentes) |
| 5 | **identity/finance/counseling** | Prompt combinado con modelos (migraciones + AR con guardrails) | ✅ Ejecutado (esquema + componentes) |
| 6 | **Vistas + roles** | Mapa maestro, Fase 0 (shell por rol + `can?`/`authorize!` + dashboard + portales + 403), prompts por dominio | ✅ Fase 0 + dominios ejecutados (todavía sobre `StubResolver`, ver bordes abiertos) |
| 7 | **Plano de control + billing** | Estructura `app/control_plane/`, auth de `platform_admins` + MFA (S0), catálogo `addons`/`plans`/`plan_price_tiers` con CRUD real (S1), `subscriptions`/`institution_entitlements` con CRUD real (S2a), gate de entitlement wireado en el inquilino (S2b), headcount snapshots + pipe genérico de metering (S3a), `invoices`/`invoice_line_items` con corte de periodo real (S4) | 🟡 **Track de billing completo (S0→S4).** Pendiente: emisión de eventos por dominio (S3b, requiere M1) y riel de pago (fuera de alcance de v1). |
| 8 | **Autenticación / onboarding** | Registro por invitación, login+MFA, roster import, vinculación, auditoría (externos e internos) | 🟡 **Parcialmente ejecutado.** Real: esquema, login+MFA, invitaciones, auditoría, gestión de personas, suspender/reactivar. Pendiente: roster import (CSV), `GuardianScope`, vistas de autoservicio de la persona, visores de auditoría/discrepancias. |
| 9 | **Plano de control · S1 (catálogo)** | Migraciones `addons`/`plans`/`plan_price_tiers`, modelos con validaciones-espejo de los CHECK, CRUD auditado, seed idempotente, tests | ✅ Ejecutado — ver Changelog v1.2.0 |
| 10 | **Plano de control · S2a (subscriptions + entitlements)** | Migraciones `subscriptions`/`institution_entitlements` (globales, sin RLS), modelos con snapshot inmutable y validaciones-espejo, CRUD auditado, predicado `ControlPlane::Entitlements::Check`, bloqueo de `retire!` con entitlements activos (F10-bis), tests | ✅ Ejecutado — ver Changelog v1.3.0 |
| 11 | **Plano de control · S2b (gate en el inquilino)** | `Core::Institution#entitled?`, `Current.entitled_addon_keys`, concern único `Entitlement::Controller` (antes de `authorize!`), nav filtrada, página "módulo no habilitado", `Entitlement::Registry` + test de consistencia vs. `DOMAIN_KEYS` | ✅ Ejecutado — primer slice que toca `app/domains/*` de forma transversal (una sola pieza + nav central). Ver Changelog v1.3.0 |
| 12 | **Plano de control · S3a (headcount + pipe de metering)** | Migraciones `student_headcount_snapshots`/`usage_events`/`usage_daily_rollups` (globales, sin RLS), `Core::Headcount::Snapshotter`/`SnapshotJob` (touch único en `core`, primer job real con GUC), `ControlPlane::Usage::Ingest`/`RollupJob` (pipe agnóstico de dominio, sin GUC), vistas read-only, tests | ✅ Ejecutado — cero cambios en dominios addon-gated; encontró y cerró un bug real de fuga de GUC en `ApplicationJob`. Ver Changelog v1.4.0 |
| 13 | **Plano de control · S4 (invoices + corte de periodo)** | Migraciones `invoices`/`invoice_line_items` (globales, sin RLS), `ControlPlane::Billing::PriceResolver` (tiers, puro), `ControlPlane::Billing::PeriodCut`/`PeriodCutJob` (corte idempotente, sin GUC, aplica overrides de S2a), ciclo de vida draft/finalized/void auditado, vistas (overview + hub), seed sintético, tests | ✅ Ejecutado — 100% control-plane, cero cambios en `app/domains/*`. Cierra el track de billing S0→S4. Ver Changelog v1.5.0 |

---

## Bordes cerrados (texto completo)

> Copiado verbatim de §11 de v1.5.0. El magro conserva solo una línea puntero para cada uno de
> estos — el razonamiento completo de por qué se cerraron vive aquí.

| # | Borde | Contexto | Estado |
|---|---|---|---|
| ⚠-1 | **Identidad global vs. un-correo-un-tenant** | El módulo de auth asume ceder a la identidad global ya construida. | ✅ **CERRADO.** Confirmado y validado en código — ver §9.5 (narrativa arriba). No re-abrir sin una razón de negocio explícita (implicaría reescribir `Core::User`/`Core::InstitutionUser`, fundacional). |
| ⚠-2 | **Dónde vive el campo de documento** | El esquema usa `student_code` como ID legible; no había campo de documento nacional. | ✅ **CERRADO.** `national_id` cifrado en `Core::User` (global) y `GroupManagement::Student` (tenant-scoped) — ver §9.6 (narrativa arriba). |
| **P1** | **`IdentityAccess::PermissionCheck` real** | Todo el gate de RBAC resolvía contra `StubResolver`/`StubAssignments` cuando no había `RoleAssignment` reales — sobre-otorgamiento a cualquier persona autenticada sin siembra. | ✅ **CERRADO** (v1.6.0) — ver narrativa completa arriba (Changelog v1.6.0). Motor real, fail-closed, caso María probado contra `role_assignments` reales, 14 archivos de test migrados del monkeypatch de `StubAssignments` a siembra real. Adopción del descriptor de scope sigue incremental (solo `teacher_management`; backlog #4 para el resto). |
| B1 | **Estudiantes sin login** | `students.user_id` nullable — un menor puede existir sin cuenta. | ✅ Confirmado como diseño, y ahora reforzado por la migración `add_user_id_to_students` (FK `on_delete: :nullify`). Falta documentar consistencia en portales cuando exista `GuardianScope`. |
