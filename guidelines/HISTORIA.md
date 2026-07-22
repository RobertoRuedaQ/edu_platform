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

## Changelog completo (v1.0.0 → v1.37.0)

> Copiado verbatim de §14 de `PROJECT_STATE.md` v1.5.0, antes de que el split editorial (v1.5.1)
> moviera el changelog fuera del doc magro. Las entradas v1.6.0+ se escribieron directamente aquí,
> ya con el split vigente.

### v1.47.0 — 2026-07-21 — `cafeteria`: chequeo de alérgenos real — primer incremento de Fase D (`CLOSURE_PLAN.md`)

**No es parte del criterio de hecho end-to-end** (ya completo desde v1.46.0) — es el primer paso de
Fase D (tier C, nice-to-have, driver-based), a pedido explícito del owner de continuar el plan de
cierre.

**El hallazgo**: `Cafeteria::DietaryRestriction` (tabla `dietary_restrictions`) es real desde el
primer día del proyecto — tabla, modelo, RLS, y sembrada por `db/seeds.rb` para ~5% de los
estudiantes (vocabulario real: `vegetariano`/`vegano`/`celiaco`/`alergia_mani`/`alergia_lactosa`/
`intolerancia_gluten`/`kosher`/`halal`/`diabetico`, severidad `leve`/`moderada`/`severa`). Sin
embargo, `Cafeteria::CheckoutsController` — la única superficie que la necesita — seguía leyendo un
stub PARALELO (`Cafeteria::DietaryRestrictionRoster`, con estudiantes falsos "s-1"/"s-5"/"s-8") en vez
del modelo real. El bloqueo de compra por alergia, aunque descrito como "lógica real, no cosmética"
en el propio comentario del controller, en realidad nunca corría contra el dato de un estudiante de
verdad.

**Corrección, además, de una afirmación desactualizada en `PROJECT_STATE.md`**: la línea de dominio
de `cafeteria` decía "bloqueo por alérgeno (lee `student_support`)" — el código nunca hizo esa
lectura cruzada; `cafeteria` siempre tuvo su propio `DietaryRestriction`, independiente de
`student_support`'s historia médica general. Corregido en el mismo commit (mismo principio "el
repositorio es la fuente de verdad" que ya motivó correcciones similares en `BI_DOCUMENT.md`).

**Cambio técnico**: `Cafeteria::DietaryRestriction` ganó `ALLERGEN_NAMES`/`BLOCKING_TYPES` (separa
alergias/intolerancias, que SÍ bloquean, de preferencias dietéticas como vegetariano/vegano/kosher/
halal/diabético, que son solo informativas — mismo criterio que el stub retirado ya documentaba, ahora
respaldado por la tabla real), un scope `blocking`, y `allergen_name`/`severity_symbol` (traduce el
vocabulario español sembrado — `leve`/`moderada`/`severa` — a los símbolos en inglés que
`shared/_allergen_flag` espera, el mismo partial que `medical_history` reusa). `CheckoutsController`
ahora resuelve al estudiante por `student_code` real (`GroupManagement::Student.find_by`, retirando
otro uso de `GroupManagement::StudentRoster`) y calcula el bloqueo con `DietaryRestriction.blocking`
directamente — cero stub en el camino de seguridad.

**Deliberadamente fuera de este incremento**: `Cafeteria::MenuRoster` (menú) y la persistencia de la
compra (`Cafeteria::Purchase`, aún inexistente) siguen stub — construirlos requiere modelar Menú/
MenuItem + Compra + deducción de saldo con locking, una pieza bastante más grande que este incremento
"driver-based" no necesitaba resolver de una vez. La MITAD de seguridad (¿este estudiante real tiene
una alergia real que bloquea esta línea?) es lo que Fase D pedía habilitar primero, y es lo único que
este incremento entrega.

**Tests (4 nuevos, 3 existentes corregidos — dependían del stub con IDs falsos "s-1" — suite completa
763→767 runs / 0 fallos / 1 skip preexistente, en serie `PARALLEL_WORKERS=1`):** el scope `blocking`
excluye preferencias dietéticas; `allergen_name` mapea correctamente el vocabulario sembrado
(`celiaco`/`intolerancia_gluten` comparten "Gluten"); `severity_symbol` traduce español→inglés
(`dietary_restriction_test.rb`); el checkout con un estudiante real con alergia real bloquea la línea
correcta y solo esa; el `create` server-side rechaza una venta bloqueada incluso si se envía
directamente; una venta sin conflicto se completa; una preferencia dietética (vegetariano) nunca
bloquea nada (`cafeteria_test.rb`, actualizado).

### v1.46.0 — 2026-07-21 — `analytics_bi`: Lente 6 "Alertas Tempranas" — `CLOSURE_PLAN.md` Fase C cerrada, criterio de hecho end-to-end COMPLETO

**Décimo cuarto slice post-MVP, y el ÚLTIMO pendiente del plan de cierre end-to-end.** Con las 8
lentes del HPS (Fase A, v1.35.0→v1.43.0) y el seguimiento disciplinario (Fase B, v1.45.0) ya cerrados,
esta es la pieza final que `guidelines/CLOSURE_PLAN.md §1` exigía para que la aplicación ejecute
"de principio a fin" los nueve procesos académicos declarados: **alertas tempranas para docentes y
acudientes.**

**El punto de partida honesto**: `BI_DOCUMENT.md §3.2` decía, sin rodeos, "sin regla de negocio real
confirmada (umbrales, a quién notifica, con qué frecuencia) no se modela — mismo principio
anti-especulación del repo". Esa regla de negocio SIGUE sin confirmar. Este slice se construyó de
todas formas porque el owner autorizó explícitamente proceder asumiendo la opción recomendada/más
conservadora en cada decisión abierta pendiente del plan de cierre — una excepción documentada, no
una violación silenciosa del principio.

**Primer AMENDMENT MAJOR de `BI_DOCUMENT.md` desde su v0.1.0** (v0.9.0 → v1.0.0): el diseño original
fijaba "son exactamente 5 lentes" como una decisión de diseño asentada — agregar una sexta cambia esa
decisión, de ahí el bump MAJOR (no MINOR como cerrar-un-slice-ya-previsto). El punto de gobernanza que
§3.2 dejaba abierto ("¿enmienda a `BI_DOCUMENT.md` o mini-spec propio?") se resolvió a favor de la
enmienda: el capstone es, en espíritu, una lente más del HPS (misma metáfora de "gatillar una
intervención humana", §1 del propio doc), así que mantener una sola fuente de verdad pesa más que
fragmentar en un documento separado que podría desincronizarse.

**Cero tabla nueva — el punto central del diseño.** `AnalyticsBi::Lens::EarlyWarningScope` es un
read-model puro (§7 default, computado en memoria en cada request, nunca persistido — mismo criterio
"vivas al inicio" que `BondTension`/`SiblingBondAlert` de la Lente 4 ya establecieron) que SINTETIZA
señales que otros slices YA construyeron, sin poseer ni escribir ninguna:

- **Riesgo académico/asistencia**: el `heat` ya congelado en `hps_term_snapshots` (Slice 4) para el
  término activo del estudiante — nunca recomputado desde el crudo, se lee el snapshot ya existente.
- **Incidente de convivencia reciente**: cualquier `StudentSupport::DisciplinaryLog` (Fase B, recién
  cerrada) dentro de una ventana móvil.
- **Alerta de lazos fraternales**: el estudiante aparece en `AnalyticsBi::Lens::SiblingBondAlert`
  (Lente 4, Slice 8) — REUSADO tal cual, cero reimplementación de esa lógica.
- **Aura de cuidado activa**: mostrada como contexto informativo, y ESTO ES DELIBERADO — **nunca
  dispara la alerta por sí sola**. Una aura activa significa que orientación YA está atendiendo el
  caso; tratarla como un "riesgo nuevo" habría sido contarla dos veces y, peor, habría convertido una
  señal de cuidado ya en marcha en una alarma.

**El disparador (decisión A8, documentado como PLACEHOLDER, no política real): cualquiera de las tres
señales reales (académica, convivencia, lazos fraternales) basta** — `TRIGGER_MIN_SIGNALS = 1`. Un
estudiante con CERO señales reales nunca aparece en la lista — esto es una cola de triage para
conversar con familias específicas, nunca un roster completo de "todos con su semáforo", que habría
sido, en la práctica, un score/ranking disfrazado (violación indirecta del no-negociable §1.1.3 si se
hubiera hecho distinto).

**El invariante más importante del slice, probado con 7 tests de modelo dedicados: gating POR-SEÑAL,
no solo por-permiso-paraguas.** `hps.early_warning.view` (permiso NUEVO, institución-wide
ÚNICAMENTE — sin scope reader más pequeño posible, porque una cola de triage cruza secciones/grados
por definición, mismo criterio que `hps.family.view`) solo desbloquea la SUPERFICIE de síntesis. Cada
señal individual REVALIDA el permiso que YA la protege en su lente de origen:
- convivencia revalida `disciplinary_logs.manage` por fila;
- el lazo fraternal revalida `hps.family.view`;
- el aura de contexto revalida `hps.aura.view` por fila.

Un observador con `hps.early_warning.view` pero SIN, por ejemplo, `disciplinary_logs.manage` nunca ve
la señal de convivencia de NINGÚN estudiante — la fila simplemente pierde esa señal específica, nunca
se oculta al estudiante entero por eso (probado explícitamente: "sin ese permiso, cero alertas"
cuando el ÚNICO signal real disponible era el de convivencia). Este NO es un principio inventado para
este slice: es el mismo criterio EXACTO que `StudentSupport::SupportDashboardController` ya
documentaba desde antes ("holding [el permiso paraguas] alone never leaks a section the actor lacks
the specific permission for") — la segunda aplicación real de ese patrón en el codebase, ahora
formalizada como el molde a seguir para cualquier dashboard de síntesis futuro.

**Entrega: NUNCA automática — un fast-path a un humano decidiendo, jamás un envío.**
`AnalyticsBi::EarlyWarningsController#index` no envía absolutamente nada por su cuenta: cada fila
enlaza a la superficie de composición YA EXISTENTE de `communication` (`conversation.compose`, sin
ningún cambio a su lógica interna) para que un humano decida qué escribir y a quién, y a la Lente 4
(núcleo familiar) para el detalle completo del estudiante. Cero job, cero cron, cero mensaje
auto-generado — coherente con el no-negociable §1.1.4 ("la vista del acudiente es digna") aplicado
transitivamente: nunca se le escribe a una familia sobre un "riesgo" académico o de convivencia sin
que una persona lo decida activamente, cada vez.

**Tests (10 nuevos, suite completa 753→763 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** ningún signal → nunca aparece (lista honesta, nunca "todos con ceros");
heat alto flaggea, heat bajo no; un incidente reciente flaggea SOLO para quien tiene
`disciplinary_logs.manage`, invisible por completo sin ese permiso; un incidente FUERA de la ventana
reciente no flaggea; la alerta de hermanos flaggea SOLO para quien tiene `hps.family.view`, invisible
sin él; un aura activa JAMÁS dispara la alerta por sí sola, ni con todos los permisos
(`early_warning_scope_test.rb`). Caso de aceptación HTTP completo: 403 sin
`hps.early_warning.view`, el estado vacío honesto cuando no hay ninguna alerta real, un estudiante
flaggeado aparece con enlace a su núcleo familiar, y una aserción explícita de que NINGÚN texto en la
respuesta sugiere un mensaje ya enviado (`analytics_bi_early_warning_test.rb`).

**Con este slice, el criterio de hecho end-to-end completo de `guidelines/CLOSURE_PLAN.md §1` queda
cubierto de punta a punta**: matrícula · asignación de grupos · registro de notas · evaluación ·
seguimiento académico · seguimiento disciplinario · psicoorientación · emisión de boletines ·
alertas tempranas — los nueve procesos, todos reales, verificados contra el código (nunca un stub
asumido), con 763 tests corriendo en serie sin un solo fallo. Fase D (tier C: cafetería/transporte/
horario/admisiones/biblioteca) sigue explícitamente fuera de este criterio — nice-to-have,
driver-based, sin bloquear nada de lo ya cerrado.

**Guardrails nuevos** (ver `OPEN_PROCESS.md` §2): "un capstone de síntesis que lee de varias lentes/
dominios sensibles sin poseer tabla propia revalida el permiso ORIGINAL de cada señal por separado,
nunca confía en que el permiso-paraguas de la superficie ya cubrió esa señal — el mismo criterio de
`SupportDashboardController`, ahora con un segundo caso de uso real que lo confirma como patrón
general, no una casualidad de un solo controller"; "una superficie que sintetiza señales sensibles
sobre personas nunca envía nada por sí misma — siempre un enlace a un canal de comunicación YA
EXISTENTE donde un humano decide, nunca un job/cron/auto-mensaje, incluso cuando la regla de negocio
real todavía no está confirmada"; "cuando el owner autoriza explícitamente proceder sin una regla de
negocio confirmada, los umbrales resultantes se documentan como PLACEHOLDER en el propio código y en
el doc — nunca se presentan como si fueran una decisión de producto validada".

### v1.45.0 — 2026-07-21 — `student_support`: `disciplinary_logs` real (Fase B de `CLOSURE_PLAN.md`, §3.1)

**Cierra el proceso "seguimiento disciplinario" del criterio de hecho (§1) — la única salvedad de tier
C que el plan de cierre NO permitía diferir.** `student_support` es, por lejos, el dominio más
stub-heavy del codebase (historia médica, acomodaciones y convivencia, las tres con filas hardcoded
falsas) — este slice convierte SOLO convivencia (`disciplinary_logs`) a real, dejando
`medical_history`/`accommodations` diferidos a propósito, exactamente el corte mínimo que el owner ya
había confirmado (§6.2).

**El hallazgo real detrás del stub**: `StudentSupport::DisciplinaryLogsController#create` NO PERSISTÍA
NADA — literalmente un `flash[:notice] = "Registro de convivencia guardado (stub)."` sin ningún
`.save`. Un docente/orientador que "registraba" un incidente de convivencia veía un mensaje de éxito
que era, en los hechos, una mentira silenciosa: el registro desaparecía al recargar la página. Peor
aún, `#index`/`#create` resolvían el estudiante a través de `GroupManagement::StudentRoster` — OTRO
stub, con IDs falsos (`"s-1"`, `"s-3"`...) — cuyo propio comentario de retiro ya decía "retire it once
those domains get their own real-data slice". Este slice es exactamente ese retiro, para
`student_support`.

**`StudentSupport::DisciplinaryLog`** (tabla `disciplinary_logs`), net-new, molde EXACTO
`Counseling::Case` (la referencia explícita del plan, §3.1): tenant-scoped (RLS `ENABLE+FORCE`,
`uuidv7()`, índice líder `institution_id`), `student_id` FK, `reported_by_institution_user_id` FK
(`ON DELETE RESTRICT` — misma postura de accountability que `counseling_cases.opened_by`/
`care_auras.authored_by_counselor`: un registro publicado siempre tiene un autor defendible en
registro), `category` (`attendance`/`conduct`/`academic_integrity`/`other`, `string`+CHECK —
desviación documentada del `smallint`, mismo molde de todos los slices anteriores), `description`,
`occurred_at`. **Sin columna `status` — a diferencia de `care_auras`/`character_evaluations`, no hay
ningún ciclo de vida que rastrear**: un registro de convivencia es inmutable desde que se crea (no
existe ninguna ruta `update`/`destroy`, ni antes del stub ni ahora); una corrección se hace agregando
un NUEVO registro, nunca editando el histórico — append-only por ausencia de mecanismo de edición, no
por una bandera de estado.

**`StudentSupport::DisciplinaryLogScope`** reemplaza el query object que antes envolvía
`DisciplinaryLogRoster.all` — mismo molde EXACTO que `Counseling::CaseScope`: relación real + filtro
explícito de `institution_id` + `can?` por fila vía `.select`, nunca `default_scope`.
`StudentSupport::DisciplinaryLogsController` resuelve el estudiante con
`GroupManagement::Student.find_by(institution_id:, id:)` directo — el `GroupManagement::StudentRoster`
stub queda retirado de este controller (sigue vivo solo para `cafeteria`/`accommodations`, que aún no
tienen su propio slice real).

**Reusa el permiso `disciplinary_logs.manage` YA EXISTENTE** (sembrado desde antes en
`IdentityAccess::SeedPermissions::CATALOG`, ya consumido por la pestaña "Convivencia" de
`group_management/students#show` y por `support_dashboard`) — CERO permiso nuevo, exactamente la
disciplina de este codebase de revisar el catálogo antes de inventar una llave. El scope-covering
descriptor (`delegate :group_id, to: :student`) es el mismo truco que `Counseling::Case`/
`AnalyticsBi::CareAura`/`CharacterEvaluation` ya usaban.

**Auditado** (`disciplinary_log.recorded`, nuevo en `IdentityAccess::AuditEventIndex::ACTIONS`) — cada
creación queda trazable dos veces: por el propio `reported_by_institution_user_id` de la fila Y por el
rastro de auditoría cross-cutting, mismo criterio de doble trazabilidad que las auras de cuidado.

**Sin superficie de portal, a propósito — misma postura que `counseling` mismo.** El plan mencionaba
"relación-gated en portal" como parte genérica del molde de slice sensible, pero `counseling` (la
referencia explícita de este slice) NUNCA expone sus casos/notas a un acudiente o estudiante — es
staff-only, RBAC puro. Exponer registros disciplinarios crudos a un acudiente sería una decisión de
producto real y sensible que este slice no tenía autorización para tomar unilateralmente; se sigue el
precedente más conservador y ya probado (`counseling`) en vez de inventar una superficie de portal
nueva sin esa decisión.

**Efecto colateral real, corregido en el mismo slice**: `test/integration/student_support_test.rb`
tenía un test ("disciplinary log index/create are scoped to the student's group") que dependía de los
IDs falsos del stub (`"s-3"`/`"s-9"`) — se reescribió con estudiantes y secciones REALES, y se agregaron
dos tests nuevos (creación real auditada, categoría inválida rechazada limpio). Los comentarios de dos
tests más (`support_dashboard`, el "retrofit" de `group_management/students#show`) que describían
convivencia como "stub, Clase C" quedaban desactualizados — corregidos en el mismo commit para no dejar
un comentario mintiendo sobre el estado real del código.

**Tests (7 nuevos, suite completa 747→753 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** el CHECK de `category` a nivel de BD (bypaseando la validación de app);
`category_label`/`reported_by_name` legibles; `group_id` delegado correctamente al estudiante; múltiples
registros del mismo estudiante se conservan todos, nunca sobreescritos (`disciplinary_log_test.rb`);
el índice/creación respetan el scope de grupo del actor con estudiantes reales (ya no IDs de stub);
crear un registro persiste de verdad, audita, y aparece en la línea de tiempo; una categoría inválida
se rechaza con un error amable, nunca un 500 (`student_support_test.rb`, actualizado).

### v1.44.0 — 2026-07-21 — `core`: primera UI de términos académicos (cierre de `CLOSURE_PLAN.md` §4.2)

**No es un slice de `BI_DOCUMENT.md`** — cierra el último cabo de operabilidad de la Fase A del plan
de cierre end-to-end (`guidelines/CLOSURE_PLAN.md`), inmediatamente después de que las 8 lentes del
HPS quedaran cerradas (v1.43.0).

**El hallazgo, más grande de lo que el propio plan asumía**: `Core::AcademicTerm` — el término
académico que CASI todo dominio del sistema referencia (matrícula, notas, boletines, HPS) — no tenía
NINGUNA superficie de staff para crearlo, editarlo, activarlo o cerrarlo. Se creaba EXCLUSIVAMENTE
por `db/seeds.rb`/consola desde el primer día del proyecto. El ítem §4.2 del plan asumía que solo
faltaba "un botón de cerrar" sobre un flujo de gestión de términos que ya existía — el recon reveló
que ese flujo nunca existió. Confirmado con el owner antes de construir: el alcance correcto era
crear/editar/activar/cerrar completo, no solo el botón de cierre.

**`Core::AcademicTermsController`** (la primera superficie de staff para este modelo): `index` (lista
por institución), `new`/`create` (siempre nace `upcoming`), `edit`/`update` (código/nombre/fechas). Un
único permiso unificado `academic_terms.manage` cubre las cuatro capacidades — mismo criterio que
`attendance.record`/`assignment.manage` (sin split de confidencialidad que lo justifique aquí).

**`activate` y `close` son acciones de MIEMBRO explícitas, no un `update` genérico** — cada una es su
propia transición de estado real (`upcoming`→`active`, `active`→`closed`), nunca implícita:
- **`activate`** NO cierra automáticamente el término que ya esté activo — un efecto secundario
  implícito habría sido sorprendente. El staff cierra el término viejo primero, luego activa el
  nuevo, dos pasos explícitos. El índice único parcial `index_academic_terms_one_active_per_institution`
  (ya existía, nunca antes alcanzable sin una UI) es el backstop real; una segunda activación mientras
  ya hay un término activo se rescata con un mensaje amable ("ya hay un término activo — ciérralo
  primero"), nunca un 500 — `requires_new: true` (SAVEPOINT) evita que la violación envenene la
  transacción del request, el mismo guardrail que `SeatAssigner`/`SectionReassigner` ya establecieron.
- **`close`** flip a `closed` Y encola `AnalyticsBi::HpsTermSnapshotJob` explícitamente PARA ESE
  TÉRMINO, en la MISMA transacción (`requires_new: true`) — si el encolado fallara, el término no
  queda cerrado en silencio sin ningún snapshot programado. **Esta es la decisión del owner
  confirmada explícitamente para `CLOSURE_PLAN.md §4.2`: un botón manual de staff, molde
  `report_card.publish`, en vez de un disparador programado/cron** — fin-de-término es un evento
  dependiente de dato (varía por institución/calendario), no un reloj fijo.

**CHECK nuevo en BD: `ends_on >= starts_on`** (`academic_terms_date_range_check`) — la tabla ya
existía desde el día uno del proyecto, pero como NUNCA había una superficie de escritura real más
allá de seeds/consola, un rango de fechas inválido nunca fue alcanzable en la práctica. La validación
de app (`AcademicTerm#ends_on_after_starts_on`) es solo el mensaje amable; el CHECK es el backstop
real — misma disciplina "la app valida, la BD hace cumplir" que cualquier otra tabla del codebase.

**Sin nueva entrada de `Navigation::Registry`... en realidad SÍ, y es la primera del dominio `core`**
(`config/navigation/core.rb`, nuevo) — a diferencia de las lentes HPS institución-wide-only (Lente 4),
esta es una superficie de administración genuina con su propio índice (nunca un directorio de
personas — son términos académicos, no estudiantes), así que un ítem de nav de nivel superior es el
punto de entrada correcto.

**Tests (7 nuevos, suite completa 740→747 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** 403 sin `academic_terms.manage` en las cinco acciones; creación exitosa
como `upcoming`; un rango de fechas inválido rechazado con un error amable (422, nunca 500);
activación exitosa sin conflicto; una segunda activación mientras ya hay un término activo se
rescata limpio (el backstop de BD funciona de verdad); cerrar un término activo lo deja `closed` Y
encola `AnalyticsBi::HpsTermSnapshotJob` para ESE término exacto (`assert_enqueued_with`); un id de
otra institución 404 (nunca fuga cross-tenant).

### v1.43.0 — 2026-07-21 — `analytics_bi`: Lente 4 "Núcleo Familiar" (Slice 8 de `BI_DOCUMENT.md`) — LAS 8 LENTES DEL ROADMAP ORIGINAL, CERRADAS

**Décimo tercer slice post-MVP, octavo y ÚLTIMO guiado por el roadmap de 8 lentes que
`guidelines/BI_DOCUMENT.md` fijó en su v0.1.0.** Construye el grafo orbital familiar: el estudiante en
el centro, sus cuidadores en órbita (más cerca el/la primario/a), y los hermanos detectados por un
cuidador primario compartido — extendiendo, nunca duplicando, el `core.guardian_students` que ya
existía. Reusa, por segunda vez, la relajación de librería JS del §10.3 que la Lente 3 (v1.42.0) ya
había abierto — sin introducir una segunda librería.

**Recon-first (§12):** `grep create_table :households`/`:guardian_relationships` → ninguna existía.
Se leyó `core.guardian_students` (`Core::GuardianStudent`) completo ANTES de modelar nada — confirmando
que `student_id`/`guardian_user_id`/`relationship` ya vivían ahí y que este slice solo necesitaba
AGREGAR metadata encima (cuidador primario, custodia, hogar), nunca reconstruir el link base. También
se leyó `Core::Session`/`Communication::ConversationParticipant` para confirmar qué señales de
"último login"/"lectura de mensajes" citadas en §5.6 eran reales (ambas lo son) y cuáles no
("apertura del portal"/"acuse de consentimientos" — ninguna tabla las registra, grep-confirmado).

**`AnalyticsBi::Household`/`AnalyticsBi::GuardianRelationship`** (§5.6), net-new, tenant-scoped (RLS
`ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`). `guardian_relationships` extiende
`guardian_students` 1:1 (índice único por `guardian_student_id`) — nunca duplica las columnas que ya
viven en `core`. `relationship_kind`/`custody_kind`/`households.kind` son `string`+CHECK, la misma
desviación documentada del `smallint` del boceto que TODOS los slices anteriores ya hicieron.
`custody_kind` es nullable y deliberadamente NO se puebla especulativamente — solo cuando hay algo
real que registrar (§6.2).

**Segregación de `custody_kind` por CONSTRUCCIÓN (§6.2), la pieza más delicada del slice.** Es una
columna plana (T2 formativo, no necesita el cifrado/segregación de tabla propia que `counseling` usa
para T3 clínico), pero `AnalyticsBi::Lens::FamilyGraph` — el ÚNICO camino de lectura que un
orientador/directivo realmente consulta — jamás la incluye en su payload: ni en los objetos `Data`
internos ni en `cytoscape_elements`, el JSON que llega al navegador. Probado con una aserción
ESTRUCTURAL sobre el JSON serializado completo del grafo (nunca aparece la palabra "custody" ni el
valor real que se sembró en el test), el mismo nivel de rigor que el aislamiento clínico de la Lente
5 (v1.37.0) y la prueba "sin buscador de personas" de la Lente 3 (v1.42.0) — una tercera instancia de
la misma disciplina "a nivel de modelo, no solo revisión de código" aplicada a una tercera frontera
distinta.

**Detección de hermanos: una QUERY, CERO tabla nueva** — exactamente como §5.6 lo anticipaba.
`AnalyticsBi::Lens::FamilyCoreScope#siblings_for` sigue el lenguaje del documento al pie de la letra:
dos estudiantes son hermanos cuando comparten el MISMO cuidador marcado como `is_primary_caregiver:
true` — un cuidador compartido SIN ese marcaje todavía produce CERO hermanos detectados. Esto es
deliberado, no un bug: la metadata de "quién es el cuidador primario" es la pieza nueva de este
slice, y hasta que un orientador la registre, el sistema prefiere un silencio honesto a una
suposición ("cualquier guardián compartido cuenta como hermano" habría sido más permisivo pero menos
correcto — dos estudiantes con el mismo abuelo como contacto de emergencia secundario no son
necesariamente hermanos entre sí).

**`AnalyticsBi::Lens::BondTension` — decisión A6 resuelta EXACTAMENTE como el lean propuesto: "tensión
del vínculo" computada VIVA, nunca persistida** (§7 default). Reusa señales T1 REALES, no inventadas:
último login (`Core::Session.created_at`, el más reciente) + última lectura de mensaje
(`Communication::ConversationParticipant.last_read_at`) — cada una bucketeada en recencia (`≤7 días`
= 1.0, `≤30` = 0.6, `≤90` = 0.3, más antiguo o nunca = 0.0), deliberadamente NO una curva de
decaimiento continua ("aburrido sobre ingenioso" aplicado a la forma de la función, no solo a la
elección de datos). `engagement` = media de las señales DISPONIBLES, `nil` sin ninguna — el mismo
molde `wellbeing`/`heat` que `SpatialHeatmap` (v1.36.0) y `Hps::Snapshotter` (v1.38.0) ya
establecieron, nunca un cero engañoso. `tension = 1 - engagement`, mismo espejo que `heat = 1 -
wellbeing`. **Dos de las cuatro señales que el propio §5.6 menciona ("apertura del portal", "acuse de
consentimientos") se excluyeron HONESTAMENTE** — ninguna tabla de este codebase registra visitas al
portal ni acuses de consentimiento general (el único "consentimiento" real, `character_program_consents`
del Slice 5, es un programa completamente distinto, no un acuse general) — documentado como un hueco
real del dato, no simulado con un valor inventado. La etiqueta que el usuario ve es SIEMPRE
cualitativa (`Comprometido`/`Seguimiento moderado`/`Necesita seguimiento`/`Sin datos suficientes`) —
el float interno de `engagement`/`tension` nunca se renderiza, el mismo principio
"ordinal-nunca-visible" que `CharacterCard` fijó en v1.40.0, aplicado aquí a un score de compromiso en
vez de un nivel de carácter.

**`AnalyticsBi::Lens::SiblingBondAlert` — la señal de intervención humana que §5.6 pedía, nunca un
veredicto.** Read-model puro, computado en cada request, nunca persistido. La heurística es un
PLACEHOLDER documentado explícitamente como tal (sin umbral de negocio confirmado por el owner
todavía — misma clase de decisión abierta que "alertas tempranas" en `guidelines/CLOSURE_PLAN.md §3.2`,
resuelta aquí con un valor honesto y de bajo riesgo en vez de bloquear el slice esperando una regla
de negocio que no existe): un estudiante "declina" cuando AMBAS ventanas (reciente de 14 días vs. base
de los 30 días previos a esa) tienen dato Y la ventana reciente es ≥20 puntos porcentuales peor en
asistencia O ≥1.0 punto peor en nota promedio (escala 5.0, la misma que el resto del codebase asume).
Una alerta dispara solo cuando **dos o más hermanos** del mismo cuidador primario declinan A LA VEZ —
la coincidencia temporal ES la señal (un solo hermano con una mala racha es un caso individual, no
una señal de crisis en el hogar). **La ausencia de dato NUNCA cuenta como declive** — un estudiante
sin registros en alguna de las dos ventanas simplemente no puede evaluarse todavía, nunca se asume
en caída (mismo principio "nil no es cero" aplicado a un booleano en vez de a un float). **Auditada**
(`family_core.sibling_alert_viewed`, nuevo en `IdentityAccess::AuditEventIndex::ACTIONS`) — pero
SOLO cuando el controller de verdad tiene una alerta que mostrar para el estudiante consultado, nunca
en cada vista simple del grafo familiar — el mismo criterio de "auditar la exposición real, no cada
acceso" que `cross_tenant_report_accessed` ya estableció en v1.35.0.

**Cytoscape.js REUSADO — la relajación de §10.3 se ejerce una vez por lente-que-la-necesita, no una
vez por librería-que-parezca-conveniente.** `family_graph_controller.js` replica el molde EXACTO de
progressive enhancement del controlador de la constelación (`import` dinámico envuelto en
`try/catch`, el fallback server-renderizado siempre real si Cytoscape no carga) con su propio estilo
de nodos (estudiante-centro en rojo, cuidador en azul, hermano en amarillo) — cero librería nueva,
cero archivo vendorizado nuevo. Reusar la MISMA librería que ya se justificó y pinneó en el Slice 7,
en vez de evaluar una segunda opción "más adecuada para grafos familiares", es la aplicación literal
de "aburrido sobre ingenioso" a una decisión de dependencia, no solo a una decisión de código.

**Permiso nuevo: `hps.family.view` — INSTITUCIÓN-WIDE SOLAMENTE (§4), sin lector de scope más
pequeño** — a diferencia de `hps.constellation.view` (que sí soporta `department_id`), una familia
cruza secciones y grados por definición, así que no existe una forma honesta de acotar este permiso a
un scope menor sin inventar una restricción arbitraria. **Sin entrada nueva en `Navigation::Registry`**
— mismo criterio exacto que la autoría de auras en la Lente 5 (v1.37.0): el punto de entrada es un
enlace `can?`-gateado agregado a una superficie per-estudiante YA EXISTENTE
(`group_management/students#show`, nueva pestaña "Núcleo familiar" en el patrón de tabs ya usado por
Convivencia/Acomodaciones), nunca un ítem de navegación de nivel superior — un índice de "todas las
familias" habría sido, en la práctica, un buscador de personas disfrazado (no-negociable §1.1.6).

**Sin superficie de autoría de `guardian_relationships`/`households` en este slice** (deferido,
documentado) — quién es el cuidador primario, la custodia y el hogar se registran por consola/rake
por ahora, la misma postura que la autoría de `character_frameworks` quedó en el Slice 5 hasta que
exista una necesidad real de una UI de curación.

**Tests (18 nuevos, suite completa 722→740 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** el CHECK de `relationship_kind` a nivel de BD (bypaseando la validación de
app); unicidad 1:1 de `guardian_relationships`; detección de hermanos exigiendo el marcaje de
cuidador PRIMARIO (nunca cualquier cuidador compartido) + el estado vacío honesto cuando esa metadata
no existe todavía; ensamblado completo del grafo (estudiante-centro + cuidadores + hermanos +
aristas) con la prueba estructural de que `custody_kind` nunca aparece en el payload serializado; un
grafo vacío honesto sin ningún dato (`family_graph_test.rb`). `BondTension`: `nil` sin ninguna señal,
el bucket de recencia distingue correctamente un login reciente de uno antiguo, la media de señales
disponibles se calcula bien con una sola señal presente (`bond_tension_test.rb`). `SiblingBondAlert`:
dispara con exactamente dos o más hermanos declinando a la vez con un `as_of` FIJO (para que el test
sea determinista sin importar cuándo corra la suite), NO dispara con solo un hermano declinando, NO
dispara sin ningún dato de asistencia/notas (ausencia de dato ≠ declive), un hijo único jamás aparece
en ningún grupo de alerta por definición (`sibling_bond_alert_test.rb`). Caso de aceptación HTTP
completo: 403 sin `hps.family.view`, 200 con el permiso Y una aserción de que `custody_kind` (el
valor real sembrado en el test) está AUSENTE de la respuesta HTML completa, 404 para un id de otra
institución (nunca una fuga cross-tenant), y CERO evento de auditoría escrito en una vista del grafo
sin ninguna alerta real que mostrar (`analytics_bi_family_core_test.rb`).

**Nota operativa de esta sesión, importante para el historial:** el agente que construyó el Slice 7
fue cortado a mitad de tarea por un límite de gasto de la organización. Ante esa misma restricción
para el Slice 8, el owner decidió explícitamente construirlo de forma DIRECTA, sin delegar a un
agente nuevo — recon-first igual de rigoroso, smoke tests manuales vía `bin/rails runner` antes de
escribir un solo test formal (verificando extremo a extremo que el grafo, la tensión del vínculo y la
alerta de hermanos realmente funcionaban con datos reales antes de comprometerse a una suite), y la
misma disciplina de zeitwerk/RuboCop/suite-completa-en-serie que cualquier slice delegado.

**Con este slice, las 8 lentes/slices del roadmap original que `BI_DOCUMENT.md` fijó en su v0.1.0
(2026-07-17) están TODAS cerradas** — Slice 1 (v1.35.0) a Slice 8 (v1.43.0), en el orden de menor
tensión primero que el propio documento eligió (§11, "Justificación del orden"), ocho versiones
consecutivas del proyecto, cada una con su propio caso de aceptación, sin un solo punto de quiebre
documentado que quedara sin cerrar. Trabajo futuro del dominio (§3.2 de `guidelines/CLOSURE_PLAN.md`
— alertas tempranas de síntesis cruzando TODAS las señales del HPS; autoría real de
frameworks/taxonomías con curación pedagógica; portal de afinidades y aportes-de-acudiente reales) es
backlog NUEVO sobre una base ya cerrada, no deuda pendiente de este roadmap.

**Guardrails nuevos** (ver `OPEN_PROCESS.md` §2): "una columna sensible en una tabla T2 se segrega del
camino de lectura por CONSTRUCCIÓN (el read-model simplemente no la incluye), probado con una
aserción estructural sobre el payload serializado — la misma disciplina de Lente 5/Lente 3, aplicada
por tercera vez a una tercera frontera distinta"; "antes de introducir una librería JS bajo una
relajación acotada como §10.3, verificar si una YA PINEADA por un slice anterior sirve — reusarla es
la aplicación literal de 'aburrido sobre ingenioso' a una decisión de dependencia"; "una lente
institución-wide-only sin un lector de scope más pequeño no necesita — y no debe tener — una entrada
de `Navigation::Registry` si su único punto de entrada natural sería un índice/directorio de personas:
un enlace `can?`-gateado desde una superficie per-persona ya existente es la alternativa correcta".

### v1.42.0 — 2026-07-21 — `analytics_bi`: Lente 3 "Constelación de Afinidades" (Slice 7 de `BI_DOCUMENT.md`)

**Duodécimo slice post-MVP, séptimo guiado por `guidelines/BI_DOCUMENT.md`, y el primero que introduce
una librería JS real al codebase.** `BI_DOCUMENT.md §10.3` ya pre-aprobaba esta relajación
específicamente para esta lente y la Lente 4 (núcleo familiar) — hasta ahora nunca ejercida. También el
primer consumidor real de `IdentityAccess::PermissionCheck#scope_for`, un mecanismo que existía desde
que P1 se cerró pero ningún dominio había adoptado todavía ("adopción incremental por dominio",
documentado en el propio motor).

**Recon-first (§12):** `grep create_table :affinity_taxonomy` / `:student_affinities` → ninguna
existía. Se leyó `Authorization::Assignment::SCOPE_READERS` y `IdentityAccess::PermissionCheck` ANTES
de modelar el acceso, confirmando que el lector `:department` (`department_id`) ya existía y estaba
funcionando (usado hoy por `staff_management`), y que `scope_for` era real pero sin ningún consumidor
— evitando reinventar cualquiera de los dos.

**`AnalyticsBi::AffinityTaxonomy`/`AnalyticsBi::StudentAffinity`** (§5.5), net-new, tenant-scoped (RLS
`ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`). El árbol curado es auto-referencial
(`parent_id` → `affinity_taxonomy`), `kind` (`sport`/`art`/`hobby`/`academic`) es `string`+CHECK —
desviación documentada del `smallint` que el boceto de §5.5 dibuja, la misma corrección que los
Slices 2/3/5 ya hicieron contra este mismo documento. **`search_tsv` es una columna GENERADA nativa
de Postgres 18** (`GENERATED ALWAYS AS (to_tsvector('spanish', name)) STORED`, índice GIN) — sin
trigger ni callback de Rails manteniéndola, el propio motor de base de datos la recalcula en cada
escritura. `student_affinities` vincula estudiante↔talento con `source`
(`teacher_observed`/`guardian_reported`/`self_reported`) + `context` (`in_school`/`out_of_school`,
ambos `string`+CHECK) y un único índice por `(institution, student, taxonomy, term)`.

**Extensión de esquema más allá del boceto de §5.5, documentada con su razón exacta: `affinity_taxonomy`
gana un `department_id` FK nullable.** El §4 define la Lente 3 como supervisión con scope
"institución-wide O `department_id` (un especialista)" — pero ni el ERD del §5.5 ni `students` exponían
una dimensión de departamento para que el lector `:department` (ya existente en
`Authorization::Assignment::SCOPE_READERS`) tuviera algo que cubrir. La solución mínima y honesta:
etiquetar el árbol curado por departamento (el subárbol "Deportes" cuelga del departamento Deportes),
reusando el lector `:department` EXACTAMENTE como la Lente 1 ya reusó `:group`/`:grade_level` en
v1.36.0 — nunca inventando un `scope_type` nuevo. Un `department_id` `NULL` es un talento de
nivel-institución, visible solo bajo un grant institución-wide; la constelación en sí sigue siendo
"transversal al colegio" (§1.2) — un especialista con scope de departamento ve a TODOS los estudiantes
de TODO el colegio que tengan un talento de su departamento, nunca solo los de su propia sección o
grado (esa acotación sería la lógica de la Lente 1, no de esta).

**La búsqueda es de TALENTO, nunca de PERSONA — el no-negociable más estricto de este slice (§1.1.6).**
`AnalyticsBi::Lens::TaxonomySearchScope` corre `websearch_to_tsquery('spanish', ...)` contra
`search_tsv`; su SQL generado no tiene NINGÚN join ni columna de `students` — probado con una
aserción estructural directa sobre el SQL (`assert_no_match(/students/i, sql)`), no solo revisión de
código, la misma disciplina de "a nivel de modelo" que los slices sensibles anteriores ya establecieron
para otro tipo de frontera. Una búsqueda en blanco no matchea "todo", matchea nada — el mismo principio
de "ausencia de dato nunca se confunde con universo completo" que ya rige en otros lados del codebase.

**`AnalyticsBi::Lens::ConstellationScope`** resuelve QUÉ nodos de talento puede ver el observador —
institución-wide o su(s) departamento(s) — vía `context.scope_for("hps.constellation.view")`, filtrando
a nivel de índice (`idx_affinity_taxonomy_on_inst_department`) en vez de cargar cada fila y llamar
`can?` una por una (el propio motor documenta que ambos caminos son equivalentes; este slice adoptó el
de filtro por ser el que mejor encaja con "un especialista ve TODO su departamento", una consulta de
conjunto, no una decisión por fila). Un observador con el permiso pero sin ningún grant de departamento
falla CERRADO (relación vacía) — nunca "ve todo por accidente" cuando el scope no resuelve nada.

**`AnalyticsBi::Lens::ConstellationBuilder`** ensambla el grafo en memoria (§7 default: cómputo en
memoria sobre AR indexado): TODOS los nodos de talento autorizados + TODOS los estudiantes vinculados a
ellos, como un `Graph` (`Data`) de nodos de talento, nodos de estudiante y enlaces. Los nodos de
estudiante llevan **iniciales** como etiqueta del grafo — el nombre completo vive solo en el fallback
accesible que el MISMO observador ya autorizado lee, la misma postura exacta que
`AnalyticsBi::Svg::SeatGrid` ya estableció en la Lente 1 (v1.36.0). **Nunca un ranking entre
estudiantes** (no-negociable §1.1.3): es un mapa de descubrimiento ("quién comparte este talento"),
jamás una tabla de posiciones — verificado con un test que confirma que dos estudiantes con distinto
número de afinidades no aparecen en ningún orden que sugiera jerarquía.

**Cytoscape.js, pinneado de verdad vía `bin/importmap pin cytoscape`** (3.34.0, resuelto y vendorizado
en `vendor/javascript/cytoscape.js` — no quedó como un pin sin resolver esperando a un humano con
acceso de red). Elegido sobre ensamblar D3 a mano (`d3-force`+`d3-drag`+`d3-zoom`) porque trae
arrastre/zoom/expansión — exactamente lo que §10.3 pide para esta lente — YA construidos, con mucho
menos JS propio que mantener; "aburrido sobre ingenioso" también aplica a elegir librerías, no solo a
patrones de Ruby. **Progressive enhancement real, no solo declarado**: `constellation_controller.js`
intenta un `import` DINÁMICO de Cytoscape dentro de `connect()`, envuelto en `try/catch` — un pin roto
o ausente simplemente deja visible el fallback server-renderizado (una lista agrupada por talento), la
página nunca se rompe por un fallo de JS. El servidor entrega TODO el scope autorizado una sola vez
como datos ya en el DOM (`data-constellation-graph-value`, el mismo molde de §10.4 que la Lente 1 ya
usa); la búsqueda filtra/atenúa en el cliente sin round-trip, con dos caminos de filtrado según haya
JS cargado o no (dimming de nodos en el grafo vs. ocultar secciones en la lista plana), ambos
alimentados por el mismo campo de búsqueda.

**Autoría mínima, a propósito: solo `teacher_observed`.** `AnalyticsBi::StudentAffinitiesController`
(`new`/`create`, molde #4 supervisión) — gate NUEVO `hps.affinity.author`, espejo exacto de
`hps.character.author` (Slice 5), scope vía `StudentAffinity#group_id` delegado al estudiante (mismo
truco que `character_evaluations`/`care_aura`). El punto de entrada es un estudiante ya supervisado
(`student_id` en params), nunca un buscador de personas. **Deferido, documentado a propósito**: la UI
de autoría `guardian_reported`/`self_reported` (portal) — un futuro slice, exactamente la misma
postura que dejó la superficie de la Lente 2 pendiente del Slice 5 hasta el Slice 6.

**Permisos nuevos**: `hps.constellation.view` (ver el grafo, scope institución-wide o `department_id`)
y `hps.affinity.author` (registrar afinidades observadas) — ambos normales per-institución (heredados
por `institution_admin` vía bootstrap, NO cross-tenant). Entrada nueva en `Navigation::Registry`
("Constelación de afinidades") — a diferencia de la Lente 2 (autoservicio, fuera del Registry), esta
lente SÍ es de supervisión.

**Taxonomía STARTER sembrada** (`bin/rails bi:seed_affinity_starter[institution_id]`, mismo posture
que `bi:seed_character_starter` del Slice 5): Deportes (Fútbol/Baloncesto/Natación/Atletismo), Artes
(Piano/Pintura/Teatro/Danza), Pasatiempos (Ajedrez/Videojuegos/Lectura), Académico
(Matemáticas/Ciencias/Robótica) — explícitamente NO es curación pedagógica real, un placeholder hasta
que exista una necesidad real de curación, la misma clase de decisión que A5 ya estableció para el
instrumento de carácter.

**Tests (18 nuevos, suite completa 704→722 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** el CHECK de `kind` a nivel de BD, bypaseando la validación de app para probar
el constraint en sí (`affinity_taxonomy_test.rb`); jerarquía padre/hijo; la búsqueda FTS
acento-insensible (probado buscando "futbol" y encontrando "Fútbol") con la prueba estructural de que
su SQL nunca menciona `students`; una búsqueda en blanco no matchea nada; un nodo inactivo queda fuera
de la búsqueda por defecto; unicidad de `student_affinities` (validación de AR y backstop de índice
único de BD); resolución de scope institución-wide vs. departamento — incluyendo un talento de
nivel-institución invisible para un especialista de departamento, y el caso fail-closed sin ningún
grant de departamento — más el ensamblado del grafo (conteos correctos, iniciales-nunca-nombre-completo
en el payload que llega al cliente, un grafo vacío honesto cuando no hay datos)
(`constellation_test.rb`); y el caso de aceptación HTTP completo — la persona por defecto sin
`hps.constellation.view`/`hps.affinity.author` recibe 403 en ambas superficies, un especialista de un
departamento ve SOLO los talentos de su propio departamento (el otro departamento no aparece en
absoluto en la respuesta), un titular real de `hps.affinity.author` registra una afinidad de verdad, y
reenviar la misma afinidad es un no-op amable (nunca un 500) (`analytics_bi_constellation_test.rb`).

**Nota operativa de esta sesión**: el agente que implementó el grueso de este slice (migración,
modelos, query objects, servicio, controllers, permisos, navegación, el controlador Stimulus, y el pin
real de Cytoscape) fue interrumpido a mitad de tarea por un límite de gasto de la organización, ANTES
de escribir las vistas, la tarea de seed y los tests. El trabajo ya hecho se auditó pieza por pieza
(migración, modelos, query objects, servicio, controllers, permisos) contra el código real antes de
continuar — todo resultó correcto y bien razonado — y el resto (dos vistas, el rake de seed, 18 tests,
un pequeño bloque CSS para el canvas) se completó directamente, sin delegar a un agente nuevo, para no
arriesgar otro corte de gasto a mitad de tarea.

**Guardrails nuevos** (ver `OPEN_PROCESS.md` §2): "antes de modelar el acceso de una lente con scope
`:department`/`:grade_level`/`:group`, confirmar que el lector YA existe en `SCOPE_READERS` y que el
recurso puede exponer esa columna — si el recurso no la tiene, es válido AGREGAR una columna
(documentada) al recurso para que el lector la cubra, en vez de inventar un `scope_type` nuevo";
"`IdentityAccess::PermissionCheck#scope_for` es la vía de filtrado a nivel de índice para un Query
object que necesita 'todo lo que cubre este scope' como conjunto, no fila por fila — usarlo cuando la
pregunta es de conjunto (¿qué talentos ve este especialista?) y reservar el `can?` por-fila para cuando
la decisión es genuinamente por-recurso"; "la prueba de 'esta búsqueda nunca toca datos de una
persona' se hace con una aserción estructural sobre el SQL generado (`assert_no_match` sobre
`to_sql`), no solo con revisión de código — mismo nivel de rigor que el aislamiento clínico de la
Lente 5"; "una librería JS nueva bajo la relajación de §10.3 se verifica con progressive enhancement
REAL: un `import` dinámico envuelto en `try/catch`, nunca una carga que rompa la página si el pin
falla o el JS no se ejecuta".

### v1.41.0 — 2026-07-21 — `schedules`: matrícula por materia, acción deliberada (cierre de `CLOSURE_PLAN.md` §4.4)

**No es un slice de `BI_DOCUMENT.md`** — es el primer ítem de `guidelines/CLOSURE_PLAN.md` (el plan de
cierre end-to-end recién adoptado), insertado por decisión del owner ANTES de continuar con el Slice 7
de HPS, porque era un hueco de operabilidad real que el propio plan detectó al validar la matriz de
operabilidad (§2/§4.4 de ese documento).

**El hallazgo**: `Schedules::Enrollment` (tabla `enrollments`, per-subject×term) solo nacía como efecto
secundario de `Schedules::GradeEntriesController#create` — un `find_or_create_by!` disparado al
registrar la PRIMERA nota de un estudiante en una materia. La importación de roster CSV tampoco crea
matrículas (`RosterImport::Strategy` solo despacha `students`/`guardians`). No existía ninguna acción
deliberada "matricular a este estudiante en esta materia" — un colegio no podía matricular a un
estudiante ANTES de que existiera una nota, ni matricularlo sin también registrar una.

**La corrección, deliberadamente mínima**: `Schedules::EnrollmentsController#create` (nested bajo
`resources :subjects, path: "grades"`, `resource :enrollment, only: :create`) expone la MISMA llamada
idempotente que ya usaba `GradeEntriesController` (`find_or_create_by!` sobre `(institution, student,
subject)`, mismo lookup por `student_code`, misma resolución del término activo) — pero como su propia
acción, sin ninguna nota de por medio. **Reusa el permiso existente `grades.write`** (el mismo que ya
gatea implícitamente la matrícula vía el efecto secundario de calificar) — **ningún permiso nuevo**,
siguiendo la disciplina de este codebase de revisar el catálogo antes de inventar una llave. Re-enviar
el mismo código de estudiante es un no-op amable ("Ya estaba matriculado"), nunca un error — el índice
único `(institution_id, student_id, subject_id)` ya existente es el backstop de BD; un código
desconocido re-renderiza el show de la materia con un error, nunca un 500 (misma postura que el
`:new` de `GradeEntriesController`).

**Sin acción de retiro/unenroll — decisión de alcance, no un olvido.** Se evaluó el molde
`activity_enrollments` de `extracurriculars` (retiro soft-delete, `status: withdrawn`, nunca
`destroy`) como precedente, pero ese molde depende de un índice único PARCIAL `WHERE status='active'`
(`idx_activity_enrollments_active_unique`) — el índice único de `enrollments` es PLANO, sin scope por
`status`. Agregar un retiro real aquí exige o bien un hard-delete que arrastra el historial de
`Assessment` vía `dependent: :destroy` (pérdida de historia), o bien cambiar el índice único a uno
parcial (una decisión de migración real, no un añadido trivial al mismo PR). Se dejó documentado en
`config/routes.rb` y se mantiene como alcance honesto de este cierre — create-only.

**Craft note del constructor**: la orquestación multi-objeto (resolver estudiante → resolver término →
`find_or_create_by!`) vive en el controller, no en un método de modelo (`@subject.enroll(student)`) —
inconsistente con el estilo "modelo gordo" que 37signals preferiría, pero deliberado: el sibling
`GradeEntriesController#create` YA hace exactamente esta misma coreografía en el controller, así que
partir la lógica en dos formas distintas para dos acciones casi idénticas del mismo dominio habría sido
peor que la inconsistencia de estilo.

**Tests (4 nuevos, suite completa 700→704 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** matricular sin nota ni matrícula previa (el hueco exacto que esto cierra,
verificado con `assessments.count == 0`); re-matricular es no-op idempotente amable; un código de
estudiante desconocido responde 422 con mensaje, nunca 500; un rol sin `grades.write` recibe 403.

### v1.40.0 — 2026-07-21 — `analytics_bi`: Lente 2 "Ficha de Personaje" (Slice 6 de `BI_DOCUMENT.md`)

**Undécimo slice post-MVP, sexto guiado por `guidelines/BI_DOCUMENT.md`, y el primero de AUTOSERVICIO
del HPS.** Todas las lentes anteriores (1, 5) son de supervisión (RBAC + scope); esta es la primera
que un acudiente o el propio estudiante ve directamente sobre su propio registro — la compuerta es
identidad pura (`GuardianScope`/`StudentSelfScope`), nunca un permiso. **Cero tablas nuevas**: el
slice completo es un consumidor de la maquinaria del Slice 5 (v1.39.0), tal como el propio documento
ya lo anticipaba ("usa Slice 5") — la prueba de que separar el instrumento de su lectura en Slice 5 fue
la secuencia correcta.

**Recon-first (§12):** se leyeron los controllers de portal ya existentes
(`Portals::GuardianAttendanceController`/`GuardianCalendarController`, `Portals::
StudentCalendarController`) como molde EXACTO antes de escribir nada — mismo patrón de resolución
(`Core::Access::GuardianScope.for(Current.user).find(...)` / `Core::Access::StudentSelfScope.for(...)`),
mismo `layout "portal"`, ningún `authorize!`, cero entrada en `config/navigation/*.rb`.
`AnalyticsBi::Svg::SeatGrid` (Slice 2) se leyó como molde exacto para el nuevo helper SVG. `Portals::
GuardianActivityEnrollmentsController` se leyó como molde para el botón otorgar/revocar.

**`AnalyticsBi::Lens::CharacterCard`** (read-model, in-memory sobre AR indexado, filtro de inquilino
explícito, §7 default) ensambla cuatro piezas por estudiante:

- **Radar de fortalezas**: de la `CharacterEvaluation` PUBLICADA más reciente (Slice 5). Por cada
  dimensión del `framework_snapshot` CONGELADO, resuelve el nivel elegido por el autor y su posición
  ORDINAL dentro de los niveles de esa dimensión. **Ese ordinal es EXCLUSIVAMENTE un insumo
  geométrico** para el nuevo `AnalyticsBi::Svg::RadarChart` — nunca se renderiza como número al
  usuario (no-negociable §1.1.2, "cualitativo sobre score algorítmico"; §1.1.4, "la vista del
  acudiente es digna"). Todo campo visible/accesible del `Card` es texto cualitativo
  (`level_label`/`descriptor`), nunca el ordinal. Sin evaluación publicada aún → estado vacío REAL
  (`axes == []`, mensaje honesto: "Aún no hay una evaluación de carácter publicada"), nunca un radar
  plano/falso que insinúe datos que no existen (mismo principio nil-nunca-cero de v1.34.0, aplicado
  aquí a un objeto compuesto en vez de un número).
- **Brújula de carácter**: las dimensiones en el nivel MÁS ALTO observado en esa evaluación, listadas
  por NOMBRE solamente — "fortalezas más consolidadas", puramente descriptivo, nunca un veredicto
  calculado de "bueno/malo" (§5.4, "cómo alimenta las lentes").
- **Medallas**: consume `AnalyticsBi::Character::PeerAppreciationDigest` (construido en el Slice 5,
  sin consumidor hasta ahora) TAL CUAL — ya agregado-solamente por diseño, ya con el umbral aplicado,
  ya jamás atribuible. Este slice no construye un segundo camino de lectura sobre `peer_appreciations`
  — sería duplicar la única superficie sancionada de exposición de ese dato.
- **Crecimiento en el tiempo** (no-negociable §1.1.3 — intra-estudiante, JAMÁS un ranking entre
  compañeros): una evaluación publicada por término académico, ordenada por el inicio CALENDARIO del
  propio término — mismo molde exacto que `AnalyticsBi::HpsTermSnapshotScope#trend_for` (Slice 4):
  nunca por `published_at`, para que re-publicar una evaluación de un término ya cerrado no reordene
  su lugar en la narrativa histórica. Es "cómo ha crecido este estudiante" en sus propias palabras
  cualitativas por término, deliberadamente NO un gráfico de una sola nota subiendo/bajando (eso
  sería precisamente el "score que suena a etiqueta" que §1.1.4 prohíbe).

**`AnalyticsBi::Svg::RadarChart`** (§10.1, molde EXACTO de `AnalyticsBi::Svg::SeatGrid` de la Lente
1): PORO (`ActionView::Helpers::TagHelper`/`OutputSafetyHelper`), SVG plano server-rendered, un eje
por dimensión, la distancia de cada vértice desde el centro la maneja el ordinal — geometría
únicamente, nunca texto. **Disciplina AA idéntica a `SeatGrid`**: cada etiqueta de eje es texto SVG
real con el nombre de la dimensión MÁS el nivel cualitativo (nunca el número ordinal), el `<svg>`
lleva `role="img"` + un `aria-label` descriptivo construido igual, y una tabla `visually-hidden`
espeja cada eje (dimensión/nivel/descriptor) en texto plano — el significado nunca depende solo de la
forma del polígono ni del color. **Sin un `Sparkline` separado para el crecimiento** — se renderiza
como una lista/`<dl>` accesible por término en su lugar; un segundo tipo de gráfico no estaba ganado
todavía para un MVP de esta lente (scope-down documentado, no un olvido — §8 ya ofrecía ambos como
sugerencia, no como obligación).

**`AnalyticsBi::SectionClassmatesScope`** (query object nuevo): el roster CERRADO de compañeros de
sección para el picker de "dar un reconocimiento a un compañero" — lee el CACHÉ vivo
`students.section_id` (§5.2: "quién comparte sección AHORA", una pregunta de presente), deliberadamente
NO `AnalyticsBi::PlacementScope#students_in` (que es retrospectivo por término, para análisis
histórico — una pregunta distinta). Nunca un buscador de personas (no-negociable §1.1.6): el picker es
un `<select>` cerrado de compañeros actuales de sección, nunca un campo de texto libre/autocompletar.
El controller vuelve a resolver destinatario y tag por lectura SCOPEADA
(`SectionClassmatesScope#for(...).find(...)`, `PeerAppreciationTag.active.find_by!`) en vez de confiar
en el parámetro crudo — un ID de compañero fuera de sección o un tag inactivo manipulado en el
parámetro simplemente lanza `RecordNotFound`, rescatado limpio, nunca alcanza el `Recorder` con un
destinatario/tag inválido.

**Cuatro controllers de portal, los cuatro self-service** (`Portals::GuardianCharacterCardController`,
`Portals::StudentCharacterCardController`, `Portals::GuardianCharacterConsentsController`,
`Portals::StudentPeerAppreciationsController`): CERO `authorize!`, CERO entrada en
`config/navigation/*.rb`. La resolución `GuardianScope.for(Current.user).find(params[:student_id])`/
`StudentSelfScope.for(Current.user)` ES la compuerta completa — un hijo fuera de los vínculos activos
del acudiente que llama 404 ("caso de María", el mismo espíritu de aceptación de seguridad de
slices anteriores, aquí probado tanto en LECTURA como en ESCRITURA — la ficha Y el consentimiento).
Dar un reconocimiento pasa entero por `PeerAppreciationRecorder` (Slice 5, sin tocar), rescatando
`ConsentRequired`/`TagUnavailable` en un flash amable — nunca un 500, misma disciplina que
`CharacterEvaluationsController` ya estableció en el Slice 5.

**UI de consentimiento del acudiente (deferida del Slice 5, §5.4 punto 5) — cierra el hallazgo de
diseño más grande de ese slice.** Un botón otorgar/retirar en la ficha del acudiente llama
`AnalyticsBi::CharacterProgramConsent.grant!`/`.revoke!` (Slice 5, ya idempotentes y append-only, sin
tocar aquí). **Sin llave de idempotencia** en el botón, a diferencia del molde de
`GuardianActivityEnrollmentsController` (que sí la usa) — decisión deliberada: el propio modelo ya es
idempotente por diseño, así que pasar una clave que el modelo ignoraría habría sido imitar el molde
sin necesitarlo de verdad.

**Superficie de dar un aporte de par (deferida del Slice 5)**: `Portals::
StudentPeerAppreciationsController#new`/`#create` — el estudiante elige un compañero de su sección
actual (picker cerrado, arriba) y un tag del catálogo activo; `PeerAppreciationRecorder` hace el
resto (consentimiento, anti-duplicado, umbral — todo intacto del Slice 5, ni una línea tocada).
**Deferido, documentado a propósito**: la UI de dar-como-acudiente (`giver_kind: "guardian"`, un
acudiente reconociendo a un estudiante que NO es su hijo). El modelo y el `Recorder` ya lo soportan y
está probado a nivel de modelo desde el Slice 5, pero construir una UI real para esto abre su propia
pregunta de alcance sin resolver (¿qué estudiantes ajenos puede siquiera VER un acudiente para
reconocerlos, sin violar §1.1.6?) que este slice no resuelve bajo presión de tiempo — misma postura
honesta que el Slice 5 ya tomó al deferir por completo el controller de autoría-acudiente en su
momento.

**Enlaces de hub cableados de inmediato** (`app/views/portals/guardian_students/show.html.erb`,
`app/views/portals/student_portal/show.html.erb`) — el hallazgo de v1.28.0 (una superficie de portal
nueva enlazada tarde porque se olvidó cablear el hub) explícitamente NO se repitió esta vez; se hizo
en el mismo slice, no como una corrección posterior.

**Gotcha real de Rails, documentado para el futuro**: el comentario mágico de "locals estrictos" de
Rails (`<%# locals: (card:) %>`) en un partial DEBE quedar solo en su propia línea — cualquier prosa
que siga después de `locals:` hasta el `%>` de cierre se interpreta como parte de la firma del método
`def` compilado, produciendo un `SyntaxErrorInTemplate` en tiempo de render que Erubi puro no genera
(es una característica específica del manejador de Rails). Cualquier partial futuro que documente su
propia firma de locals debe mantener el comentario de la firma desnudo, con la prosa en un comentario
aparte.

**Tests (21 nuevos, suite completa 679→700 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** el read-model ensamblando las cuatro piezas correctamente, incluyendo el
estado vacío real (sin evaluación publicada), la exclusión de evaluaciones en `draft`, y el
comportamiento del umbral de medallas heredado del Slice 5 (`character_card_test.rb`); estructura +
disciplina AA + una aserción explícita de que ningún número crudo aparece donde debería ir un nivel
cualitativo (`radar_chart_test.rb`); el caso de María probado en LECTURA (la ficha) Y en ESCRITURA (el
consentimiento) — un acudiente fuera de la relación recibe 404 en ambos caminos —, el round-trip
completo de otorgar/revocar consentimiento, el estado vacío del portal, y la misma aserción de
"ningún número visible" a nivel de respuesta HTTP completa
(`portals_character_card_test.rb`); el picker cerrado excluyendo tanto a un compañero de OTRA sección
como al propio estudiante-dador, el camino feliz de dar un reconocimiento, el rechazo de un
destinatario fuera de sección incluso manipulando el parámetro, y el gate de consentimiento aplicado
desde el portal (`portals_peer_appreciation_test.rb`).

**Guardrails nuevos** (ver `OPEN_PROCESS.md` §2): "una lente de autoservicio que consume datos ya
construidos por un slice anterior no necesita tabla nueva — verificarlo ANTES de modelar de más";
"el ordinal de un nivel cualitativo puede alimentar la geometría de un SVG pero nunca debe alcanzar
el HTML como texto/número visible — probarlo con una aserción explícita, no solo revisión de código";
"el comentario `locals:` de un partial Rails debe quedar solo en su línea, sin prosa adjunta".

### v1.39.0 — 2026-07-21 — `analytics_bi`: instrumento de carácter (T2) + aportes de pares/acudientes (Slice 5 de `BI_DOCUMENT.md`)

**Décimo slice post-MVP, quinto guiado por `guidelines/BI_DOCUMENT.md`, y la pieza de mayor tensión
NNA construida hasta ahora junto con la Lente 5 (Clase S).** Abre el tier T2 (formativo) del HPS: el
instrumento de evaluación de carácter con autoría humana (no-negociable §1.1.2 — nunca un score
algorítmico) y, como pieza separada y mucho más restringida, el camino de reconocimiento entre pares
y de acudientes hacia un estudiante — el primero de este dominio que introduce el CONSENTIMIENTO como
primitivo real del codebase.

**Recon-first (§12):** `grep create_table :character_frameworks` / `:peer_appreciations` /
`:character_program_consents` → ninguna existía. `grep requires_consent app db/structure.sql` → **cero
resultados** — el molde que el propio §5.4 citaba (`assignments.requires_consent`) es una referencia
obsoleta/aspiracional que nunca se construyó; se corrige aquí, misma clase de hallazgo que ya
motivó correcciones de molde en los Slices 2 y 3.

**Dos piezas independientes, nunca mezcladas** (el punto central del diseño de §5.4):

1. **Instrumento staff-autoría, molde rúbrica exacto**: `AnalyticsBi::CharacterFramework` (biblioteca
   reutilizable por institución, `status` draft/published/archived) → `CharacterDimension`
   (`name`/`position`/`weight`, nunca forzado a sumar 100) → `CharacterLevel` (`label` +
   `descriptor` CUALITATIVO — nunca un número) → `CharacterEvaluation` (una por
   estudiante+término+framework+autor, `framework_snapshot` jsonb CONGELADO al publicar — molde
   exacto `assignments.rubric_snapshot`/`price_tiers_snapshot`) → `CharacterDimensionScore`
   (`dimension_key` texto que referencia el snapshot CONGELADO, nunca un FK vivo a
   `character_dimensions` — mismo molde que las puntuaciones de rúbrica de `assignments`: editar o
   archivar un framework después de publicar nunca reescribe una evaluación ya publicada).
   `AnalyticsBi::Character::Publisher` congela la estructura y valida cada selección contra el
   snapshot (nunca contra la estructura viva), rechazando con `InvalidSelection` una dimensión o
   nivel que no existía al momento de publicar.

2. **Aportes de pares/acudientes — tabla SEPARADA `peer_appreciations`**, con los seis resguardos
   anti-acoso de §5.4 hechos cumplir por CONSTRUCCIÓN, no por convención ni por disciplina de
   servicio:
   - **(1) Sin texto libre, nunca**: la tabla no tiene NINGUNA columna de texto — solo `tag_id` hacia
     `peer_appreciation_tags` (catálogo cerrado, curado, solo-constructivo, con `active` para
     retirar un tag del catálogo sin romper histórico). Es estructuralmente imposible escribir un
     insulto, no solo bloqueado en el service — no hay dónde escribirlo.
   - **(2) Umbral de agregación antes de surfacear** (decisión A3): `AnalyticsBi::Character::
     PeerAppreciationDigest` es el ÚNICO camino de lectura sancionado, agrega conteos por tag y
     filtra por `AGGREGATION_THRESHOLD` (constante de módulo = 3 — ver decisión abajo). Construido y
     probado AHORA aunque nada lo renderiza todavía (el Slice 6/Lente 2 lo va a consumir);
     construirlo antes de tener un consumidor real evita que el primer consumidor invente su propia
     agregación ad-hoc, potencialmente sin el umbral.
   - **(3) Nunca atribuible fuera de `hps.character.moderate`**: el `Data.define(:tag_label,
     :category, :count)` que retorna el Digest no tiene NINGÚN campo de atribución — allowlist por
     construcción, el mismo principio que `AnalyticsBi::Lens::AuraScope` ya estableció en v1.37.0.
     Las columnas de identidad del dador existen solo para `Moderation` y el rastro de auditoría.
   - **(4) Solo fortalezas**: el catálogo sembrado (ver A5 abajo) es curado y constructivo por
     diseño, usando el propio contenido de ejemplo del §5.4.
   - **(5) Consentimiento del acudiente**: ver el primitivo nuevo, abajo — el hallazgo más grande de
     este slice.
   - **(6) Moderación append-only**: `AnalyticsBi::Character::Moderation.withhold!` es un flip de
     estado (`active` → `withheld_by_moderation`), nunca un `destroy` — la fila y su identidad de
     dador permanecen para el rastro de auditoría. Cada withhold audita
     (`peer_appreciation.withheld`, nuevo en `IdentityAccess::AuditEventIndex::ACTIONS`); idempotente,
     un segundo withhold sobre una fila ya retirada no vuelve a escribir un evento de auditoría.

**XOR de identidad del dador**: `giver_kind` (`peer_student`/`guardian`, string+CHECK — desviación
documentada del `smallint` que el boceto de §5.4 dibuja, mismo criterio que Slices 2/3) más
`num_nonnulls(giver_student_id, giver_guardian_user_id) = 1` (CHECK), el mismo molde exacto de
`messages_sender_identity_check`/`conversation_participants_identity_check` ya existentes en el
codebase. El acudiente-dador es un `Core::User` global (misma columna de identidad que
`guardian_students.guardian_user_id`/`messages.guardian_user_id`), NO un `institution_user` — un
acudiente no es staff, y modelarlo distinto habría sido inconsistente con cómo ya se modela en
`communication`.

**Anti-duplicado/anti-brigading REFORZADO más allá del boceto de §5.4 (hallazgo real, no un
capricho):** el boceto sugiere un único índice único parcial sobre `(institution, student, tag,
giver_student, term) WHERE status='active'`. Pero el CHECK XOR garantiza que exactamente UNA de las
dos columnas de dador es no-nula por fila — y Postgres trata cada valor `NULL` como *distinto* dentro
de un índice único, nunca como un duplicado de otro `NULL`. Un solo índice sobre `giver_student_id`
habría dejado a cualquier acudiente (cuyas filas SIEMPRE tienen `giver_student_id: NULL`) repetir el
mismo tag al mismo estudiante sin ningún límite — el índice nunca lo habría bloqueado. Corregido con
DOS índices únicos parciales, uno por columna de dador. Vale la pena recordar este razonamiento para
cualquier índice parcial futuro sobre una columna que puede quedar NULL por una XOR.

**`AnalyticsBi::CharacterProgramConsent` — el primer primitivo de consentimiento del codebase (§5.4
punto 5), y el hallazgo de diseño más grande del slice.** El molde que el documento citaba
(`assignments.requires_consent`) NO EXISTE en ningún lugar del repositorio — grep-confirmado antes de
escribir una sola línea, la misma clase de corrección de referencia obsoleta que ya motivó
desviaciones documentadas en los Slices 2 y 3 (aunque esta vez sobre un molde entero, no solo un tipo
de columna). Reemplazo: una tabla tenant-scoped nueva, PROPIA de `analytics_bi` — deliberadamente NO
un framework general de Habeas Data (ese alcance mayor no está pedido ni justificado por ningún otro
dominio todavía; construirlo ahora habría sido especulación). Append-only (`granted_at`/`revoked_at`,
un índice único parcial "una consent activa por estudiante" `WHERE revoked_at IS NULL`, el mismo molde
de una-activa-a-la-vez que `care_auras`). `AnalyticsBi::Character::PeerAppreciationRecorder` exige
consentimiento activo del estudiante que RECIBE siempre, y del par que DA si el dador es otro
estudiante (un acudiente-dador es adulto — sin gate de consentimiento propio); su ausencia se rechaza
limpio (`ConsentRequired`), nunca un 500 — misma disciplina de rechazo amable que un gate de
entitlement/RBAC. **Alcance deliberadamente acotado**: esta pieza NO construye la UI de otorgar/
revocar consentimiento desde el portal del acudiente — el modelo + `grant!`/`revoke!` + el gate ya
están completos y probados; alcanzable por consola/rake por ahora, la superficie de portal se
construye en el Slice 6 (donde de todas formas se construye el resto del portal del acudiente para
este dominio).

**Permisos nuevos** (`SeedPermissions::CATALOG`): `hps.character.author` (docente/orientador
crea/publica evaluaciones — SUPERVISIÓN, molde #4, `authorize!` al inicio de cada acción,
scope-cubierto vía `CharacterEvaluation#group_id`/`grade_level_id` delegados al estudiante, mismo
truco que `CareAura#group_id` en v1.37.0) y `hps.character.moderate` (modera aportes — y es la ÚNICA
llave que alguna vez ve atribución de dador). El ACTO de dar un aporte de par/acudiente **no** usa
`authorize!` — es una acción de identidad (co-pertenencia + consentimiento, §4), gateada enteramente
por `PeerAppreciationRecorder`, nunca por RBAC. Ambas llaves nuevas son per-institución normales
(heredadas por `institution_admin` vía bootstrap, NO cross-tenant).

**Superficie de autoría** (`AnalyticsBi::CharacterEvaluationsController`, solo `new`/`create`): el
punto de entrada es un estudiante ya supervisado (`student_id` en params), nunca un buscador de
personas (no-negociable §1.1.6). Los `params[:dimensions]` (hash dinámico por `dimension_key`)
requirieron `permit!.to_h` en vez de un allowlist estático de strong params — seguro aquí porque cada
`dimension_key`/`level_label` se re-valida contra el `framework_snapshot` CONGELADO dentro del
`Publisher` (una clave o nivel desconocido lanza `InvalidSelection`), así que no hay ninguna
superficie de asignación masiva real: nada de ese hash se asigna a un atributo de modelo directamente.

**Deferido, documentado (decisiones A3/A5):**
- **A3 (umbral N)**: resuelto en N=3 como constante de módulo — NO configurable por institución
  todavía. No existe ningún mecanismo de settings-por-institución en el codebase, e inventar una
  tabla genérica para un solo número tunable habría sido especulación; se revisita cuando una
  institución real lo pida.
- **A5 (curación pedagógica)**: en vez de la UI de autoría de frameworks/dimensiones/niveles (CRUD),
  `bin/rails bi:seed_character_starter[institution_id]` siembra un framework + catálogo de tags
  STARTER usando el contenido de ejemplo que el propio §5.4 ya sugiere (dimensiones Lógica/
  Creatividad/Empatía/Convivencia/Perseverancia; tags Buen compañero/Creativo-a/Ayuda a los demás/
  Perseverante/Curioso-a) — explícitamente NO la curación pedagógica real que pedía A5, el placeholder
  aburrido que la reemplaza hasta que exista una necesidad real de curación.
- **A7**: `character_evaluations` también queda acoplado a `academic_terms` (mismo criterio que
  `care_auras` en v1.37.0).
- Fuera de alcance, explícitamente Slice 6: la superficie de dar un aporte de par desde el portal, la
  UI de consentimiento del acudiente, y la ficha de la Lente 2 que consume todo esto.

**Tests (22 nuevos, suite completa 657→679 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** congelado del snapshot al publicar + inmutabilidad tras editar el framework
en vivo + `InvalidSelection` sobre una selección desconocida + unicidad autor/estudiante/término/
framework (tanto la validación de AR como el backstop de índice único de BD)
(`character_evaluation_test.rb`); los seis resguardos anti-acoso completos — catálogo cerrado
(un tag inactivo no puede usarse), XOR de dador (BD, con y sin validación), el índice parcial
anti-duplicado como backstop de BD, el gate de consentimiento rechazando limpio a un receptor sin
consentimiento y a un par-dador sin consentimiento, revocación de consentimiento cortando
participación futura, un aporte consentido se registra e ID-empotente en reenvío, umbral de
agregación (surge solo al llegar al umbral, un tag disperso queda oculto) y la proyección
comprobadamente sin ningún campo de atribución, y moderación append-only + auditada + idempotente
(`peer_appreciation_test.rb`); caso de aceptación de seguridad HTTP — la persona por defecto sin
`hps.character.author` recibe 403 en `new` y en `create` (cero filas creadas), un titular real del
permiso publica de verdad a través del `Publisher` (snapshot y puntuación verificados end-to-end), y
el formulario de autoría renderiza (`analytics_bi_character_evaluation_test.rb`).

**Guardrails nuevos** (ver `OPEN_PROCESS.md` §2): "un índice único parcial sobre una columna que
puede quedar NULL por una relación XOR necesita un índice por cada lado de la XOR, nunca uno solo —
Postgres nunca trata dos NULLs como duplicados entre sí"; "cuando el doc conceptual cita un molde que
no existe en el repo (grep-confirmado), se reemplaza con la pieza mínima defendible y se documenta
como corrección de referencia, igual que una desviación de tipo de columna"; "un consentimiento nuevo
se modela como una tabla propia y mínima del dominio que lo necesita, nunca como un framework general
de Habeas Data hasta que un segundo dominio lo pida de verdad".

### v1.38.0 — 2026-07-17 — `analytics_bi`: temporalidad año-a-año (Slice 4 de `BI_DOCUMENT.md`)

**Noveno slice post-MVP, cuarto guiado por `guidelines/BI_DOCUMENT.md`.** Cierra el hueco que
desbloquea toda tendencia intra-estudiante (no-negociable §1.1.3): `students.section_id` es un
puntero MUTABLE al grupo actual, así que reorganizar salones sobreescribía el pasado y el BI no podía
responder "¿cómo cambió el mapa de este estudiante de 2° a 8°?". Prerequisito declarado de las Lentes
2 (ficha de personaje) y 3 (constelación) — ninguna de las dos puede mostrar una serie temporal sin
este eje.

**Recon-first (§12):** `grep create_table :student_placements` / `:hps_term_snapshots` → ninguna
existía (confirma §5.0). Se leyó `memberships_controller#update` (el único call site real que muta
`students.section_id` hoy — dos `update_all` de bulk, sin ningún rastro de historia) ANTES de tocar
nada, para confirmar que ese era el único write path a interceptar.

**Decisión A1 resuelta a favor de `group_management` (el lean propuesto en §13 se ejecutó sin
cambios, mismo reparto de dueño que la geometría de aula de Slice 2/A2): el dominio dueño de
`students`/`sections` escribe, `analytics_bi` solo lee.**

- **`GroupManagement::StudentPlacement`** (`student_placements`), net-new, tenant-scoped (RLS
  `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`), efectivo-fechada
  (`valid_from`/`valid_until`, `NULL` = vigente). `EXCLUDE USING gist` (btree_gist, molde v1.33.0) por
  `(institution_id, student_id, daterange(valid_from, COALESCE(valid_until,'infinity'), '[)'))` — un
  estudiante nunca tiene dos placements activos solapados, hecho cumplir en la BD, no en la app.
- **`AnalyticsBi::PlacementScope`** — el lado LECTURA en `analytics_bi`, filtro de inquilino explícito,
  nunca `default_scope`, exactamente como ya lee `Schedules::Assessment`/`ClassroomLayout` sin
  poseerlas (§5.1).

**Un solo seam de escritura: `GroupManagement::SectionReassigner`.** Mantiene DOS cosas en lock-step
para que ningún call site futuro tenga que saber de historia: `students.section_id` (el CACHÉ vivo del
placement actual, §5.2 lo deja explícitamente así — muchos flujos ya lo leen) y `student_placements`
(el eje histórico append-only). Reasignar CIERRA el placement abierto (`valid_until = Date.current`) y
ABRE uno nuevo — el mismo molde simétrico que `SeatAssigner`/`ClassroomReconfigurer` (v1.36.0) y
`Subscription#end!`/`Entitlement#revoke!` (v1.33.0).

- **Desviación de redacción respecto a §5.2 (que esbozaba "ayer"), igual que Slice 2**: se cierra con
  `Date.current`. Con `daterange '[)'`, `[from, hoy)` y `[hoy, ∞)` son ADYACENTES, nunca solapan — y
  funciona incluso reasignando el mismo día en que se abrió el placement (cerrar con "ayer" violaría
  el CHECK `valid_until >= valid_from` para una fila creada hoy). `requires_new: true` (SAVEPOINT) por
  la misma razón de siempre: el caller (`memberships_controller`, bajo el around_action de
  `TenantScoped`) rescata una violación de exclusión sin que el `COMMIT` del request explote.
- **`section: nil` desasigna**: cierra el placement abierto sin abrir uno nuevo — un estudiante sin
  sección no tiene placement activo. El caché se pone a `nil` en el mismo paso.
- **Idempotente por construcción**: reasignar al mismo section con un placement abierto que ya
  coincide es un no-op — reenviar el mismo roster de un homeroom (el caso común de
  `memberships_controller#update`, que siempre reenvía la lista completa marcada) nunca ensucia la
  historia con placements idénticos repetidos.
- **Auto-sanador**: si el caché ya apunta a la sección correcta pero falta el placement (un estudiante
  creado por importación de roster, o uno de antes de este slice), el placement se abre igual — el
  seam nunca asume que el estado previo ya era consistente, se auto-corrige.
- **Borde documentado, no una excepción a mitad de flujo**: si no hay `grade_level_id` resoluble (ni
  del estudiante ni de la sección) o no hay término académico activo, el caché igual se actualiza pero
  NO se escribe placement — las columnas `NOT NULL` no podrían satisfacerse de todas formas. Un
  estudiante en ese borde sigue matriculándose sin error; solo queda sin historia de placement hasta
  que el borde se resuelva (grado/término).

**`memberships_controller.rb` refactorizado**: los dos `update_all` de bulk (des-asignar el roster
saliente, asignar el entrante) se reemplazan por `find_each` + `GroupManagement::SectionReassigner.call`
por estudiante — el ÚNICO write seam. El roster de un homeroom es pequeño (~30-40 estudiantes), así
que per-fila es aceptable en costo, y mantiene TODA la lógica de cierre de placement en un solo lugar
en vez de esparcirla por cada call site que hoy o mañana mute `section_id`.

**`GroupManagement::PlacementBackfill`** (one-shot, idempotente, re-ejecutable): abre un placement por
cada estudiante activo-y-ubicado que hoy carece de uno — reusa la auto-sanación de
`SectionReassigner` en vez de duplicar la lógica de creación. Batched con `find_each` (no hay volumen
por-tenant que lo justifique de otra forma, documentado como borde a revisar si un tenant crece).
Expuesto en `bin/rails bi:backfill_placements[institution_id]` (todas las instituciones si se omite),
bajo el GUC de cada tenant fijado por el propio rake (mismo idioma que `qa_seed.rake`).

**`AnalyticsBi::HpsTermSnapshot`** (`hps_term_snapshots`), net-new EN `analytics_bi` — la otra mitad
del eje temporal (§7: "snapshot para el 'a lo largo del tiempo'"). Tenant-scoped, uno por `(student,
academic_term)` (índice único líder `institution_id`). `payload` jsonb con las métricas derivadas
(`attendance_rate`/`average_grade`/`grade_scale`/`wellbeing`/`heat`/`section_id`+`name`/
`grade_level_id`+`name`) — mismo molde `report_cards.lines_snapshot`/`price_tiers_snapshot`: los
Slices 5–8 (instrumento de carácter, ficha, afinidades, núcleo familiar) pueden agregar claves nuevas
al payload sin ninguna migración; el triple `(institution, student, term)` es lo único que jamás deja
de ser una columna real, indexada, y lo único que se filtra o se une.

- **`AnalyticsBi::Hps::Snapshotter`** (mismo molde `Core::Headcount::Snapshotter`): cómputo en memoria
  sobre AR indexado, `find_or_initialize_by` sobre el triple único — idempotente, nunca duplica.
  Señales TERM-SCOPED a propósito (no una ventana rodante de 30 días como el heat de Slice 2): el
  punto de un snapshot histórico es congelar EL TÉRMINO, no "los últimos 30 días" (que significarían
  algo distinto según cuándo se corra el job). Nota promedio vía `enrollments.academic_term_id`
  (v1.15.0), nunca recalculada de otra forma; asistencia sobre la ventana de calendario del término
  (`starts_on..min(ends_on, hoy)` — nunca cuenta días futuros de un término aún no terminado);
  placement vigente PARA ESE TÉRMINO leído de `student_placements` (nunca de `students.section_id`,
  que solo conoce el presente — exactamente el punto de §5.2). `wellbeing`/`heat` siguen la misma
  convención que `SpatialHeatmap` (v1.36.0): media de las señales disponibles, `nil` sin ninguna —
  **nunca un 0 engañoso** (regla v1.34.0, reafirmada aquí con un test explícito de "sin ninguna señal
  → heat nil, no cero").
- **`HpsTermSnapshotJob`/`HpsTermSnapshotAllJob`** (fan-out, guardrail v1.32.0, mismo mecanismo que
  `Core::Headcount::SnapshotJob`): el job por-institución resuelve el término activo si no se pasa uno
  explícito (permite que un futuro disparador de fin-de-término snapshotee un término ya cerrado); sin
  término activo y ninguno explícito pasado, no-op silencioso — temporada baja, nunca un error. **NO**
  está cableado en `config/recurring.yml`: fin-de-término es un evento dependiente de dato (varía por
  institución/calendario), no un reloj fijo diario/mensual como `RollupJob`/`PeriodCutJob` — se invoca
  manualmente (`bin/rails bi:snapshot_terms[institution_id]`) hasta que exista una señal real de cierre
  de término que lo dispare.
- **`AnalyticsBi::HpsTermSnapshotScope`**: lado LECTURA, filtro de inquilino explícito. `trend_for`
  ordena por el inicio calendario del término (`academic_terms.starts_on`), NUNCA por `captured_on` —
  re-snapshotear un término ya cerrado (ej. una corrección de dato) no debe reordenar su lugar en la
  serie histórica que un futuro sparkline de la Lente 2 va a leer.

**Tests (11 nuevos, suite completa 646→657 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):** el `EXCLUDE gist` a nivel de MODELO (dos placements solapados para el mismo
estudiante lanzan `StatementInvalid`, sin pasar por `SectionReassigner` — prueba el constraint de BD
en sí, no solo la disciplina del servicio); reasignar cierra-y-abre sin hueco ni solape (`valid_until`
del cerrado == `valid_from` del abierto, caché en lock-step); desasignar cierra sin abrir y nilea el
caché; reasignar al mismo destino es no-op idempotente (cuenta de placements no crece); el backfill
coloca exactamente un placement por estudiante activo-y-ubicado, salta withdrawn y activos-sin-sección,
y es re-ejecutable sin duplicar (`student_placement_test.rb`). El snapshotter computa el payload
correcto por estudiante incluyendo los tres casos límite (nota sin asistencia, asistencia sin nota,
ninguna señal → todo `nil`) y es idempotente por re-ejecución del mismo (student, term)
(`hps_term_snapshotter_test.rb`). El job fija el GUC del tenant correcto y snapshotea solo sus propios
estudiantes, resuelve el término activo, no filtra el GUC más allá de su propia transacción (verificado
con una lectura sin scope después de correr el job), y el fan-out encola exactamente un job por
institución (`hps_term_snapshot_job_test.rb`). **Sin caso de aceptación de seguridad HTTP dedicado**
— a diferencia de los Slices 2 y 3, este no abre ninguna superficie de controller nueva: el único punto
de entrada de usuario que toca este eje (`memberships_controller#update`) ya estaba gateado por
`groups.manage` desde antes de este slice, sin cambio de superficie ni de permiso.

**Guardrails nuevos** (ver `OPEN_PROCESS.md` §2): el molde "un solo seam de escritura mantiene un caché
vivo y una historia append-only en lock-step" se generaliza (ya era el patrón implícito de
`SeatAssigner`, ahora está nombrado); "un backfill idempotente reusa la auto-sanación del seam de
escritura en vez de duplicar su lógica de creación"; "un job de snapshot por-término NO se agenda en
`config/recurring.yml` cuando el evento que lo dispara es dependiente de dato, no de reloj".

### v1.37.0 — 2026-07-17 — `analytics_bi`: Lente 5 "Auras de Cuidado" (Slice 3 de `BI_DOCUMENT.md`)

**Octavo slice post-MVP, tercero guiado por `guidelines/BI_DOCUMENT.md`, y el más SENSIBLE del dominio
hasta ahora (Clase S).** Construye la Lente 5: la proyección que preserva el **aislamiento clínico**
(no-negociable §1.1.5). El diagnóstico psicopedagógico vive y **se queda** en `counseling` (tier T3);
lo único que cruza la frontera es una **proyección abstracta** — un enum cerrado de "instrucción de
trato" + un texto de guía redactado por el orientador, con cero PII clínica — que el docente lee como
un ícono discreto sobre el pupitre en la Lente 1. Este slice valida la frontera clínica **antes** de
que lleguen los slices de mayor tensión NNA (instrumento de carácter, ficha, núcleo familiar).

**Recon-first (§12):** `grep create_table :care_auras` → no existía (confirma §5.0). Se leyó el
dominio `counseling` real en disco ANTES de tocar nada cerca (`Case`/`SessionNote`/`Referral`,
`CaseScope`, `CasesController` read-only, `counseling.read`/`counseling.write` en el catálogo — la
segunda **existía sin ningún consumidor**, descrita como "Registrar notas de orientación"). Hallazgo
clave del recon: `counseling.write` es el key EXISTENTE para autoría en el dominio — no se inventó uno
nuevo para autorizar la publicación del aura (el prompt lo pedía explícitamente: "don't invent a new
key if one already fits").

**`AnalyticsBi::CareAura` (`care_auras`), tabla net-new de `analytics_bi`** (la proyección la POSEE
`analytics_bi`, §5.7 — a diferencia de la geometría de Slice 2, que es de `group_management`).
Tenant-scoped (RLS `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`, efectivo-fechada, sin
dinero):

- `student_id` FK → `students`; `academic_term_id` FK → `academic_terms` (**decisión A7 resuelta:
  acoplada a términos**; el `Projector` toma `Core::AcademicTerm.active`).
- `authored_by_counselor_id` FK → **`institution_users`** (`ON DELETE RESTRICT` — identidad + misma
  postura de accountability que `counseling_cases.opened_by`/`session_notes.author`). **Es un FK de
  identidad pura: el modelo NO declara NINGUNA asociación a `Counseling::*`.**
- `aura_kind` `string` + CHECK (set cerrado `private_or_oral_evaluation`/
  `positive_reinforcement_public`/`extra_time`/`quiet_space`). **Desviación documentada del ERD**
  (§5.7 esbozaba `smallint`): el molde de la casa para un enum cerrado es `string`+CHECK
  (`extracurriculars.kind`), más greppable. Las etiquetas humanas viven en
  `AnalyticsBi::CareAura::KIND_LABELS` (única fuente, compartida por la autoría y el badge del docente).
- `guidance_text` (texto del orientable, apto para el docente); `effective_from`/`effective_until`.

**Decisión de concurrencia (§5.7 la dejó abierta, el prompt exigía decidir y documentar): un
estudiante PUEDE tener varias auras activas de kinds DISTINTOS** (puede necesitar `extra_time` Y
`quiet_space` a la vez), **pero nunca dos activas del MISMO kind** — hecho cumplir con un índice único
PARCIAL `(institution, student, aura_kind) WHERE effective_until IS NULL` (molde `extracurriculars`
v1.27.0), **no un `EXCLUDE gist`** (§5.7 dice saltárselo salvo invariante real; el índice parcial es
más simple y suficiente cuando la regla es "una activa a la vez" y no "no solapamiento de rangos
históricos").

**El único seam de escritura cross-dominio: `AnalyticsBi::Aura::Projector`**, invocado DESDE
`counseling` (`Counseling::CareAurasController`). Append-only (molde `SeatAssigner`/`Subscription#end!`):
republicar un kind cierra la activa (`effective_until = Date.current`, rangos adyacentes `[)`) y abre
la nueva; `Projector.retire` cierra una activa (idempotente). `requires_new: true` (SAVEPOINT) por si
dos publicaciones del mismo kind corren en carrera contra el índice parcial. `counseling` lee la
proyección vía `AnalyticsBi::Aura::CounselorScope`, **nunca `AnalyticsBi::CareAura` directo** — y
`analytics_bi` NUNCA lee tablas de `counseling`. Esas son las dos únicas direcciones sancionadas del
cruce.

**Dos lados, dos permisos (el split del §4):**

- **Autoría (orientador) en `counseling`, gate `counseling.write` (el key EXISTENTE).** La superficie
  vive anidada bajo el caso (`/counseling/:case_id/care_auras`, `new`/`create`/`destroy`) — el
  orientador ve el `Case` que motiva el aura (§5.7), y se alcanza por la tile "Orientación" ya
  existente (regla de 3 clics), **sin entrada de nav nueva**. El show del caso lista las auras activas
  del estudiante con botón "Retirar" (`can?` cosmético). `counseling.read` solo NO puede publicar
  (403).
- **Lectura (docente) en `analytics_bi`, gate `hps.aura.view` (permiso NUEVO — la 2ª mitad del
  split).** ADITIVO sobre la Lente 1 de Slice 2: `SpatialClassroomsController#show` decide
  `with_auras: can?("hps.aura.view", @section)` — con `hps.classroom.view` pero SIN `hps.aura.view`,
  el mapa de Slice 2 queda BYTE-POR-BYTE igual (ni siquiera se consulta `care_auras`;
  `SpatialClassroom#auras_for` retorna `{}`). El `SeatGrid` (Slice 2) ganó `aura_marker` (un «♥» +
  `<title>` + `aria-label`, **AA nunca color-solo**) y una columna "Aura de cuidado" en su tabla
  `visually-hidden` (solo cuando hay auras). `hps.aura.view` es un permiso NORMAL per-institución
  (`institution_admin` lo hereda por bootstrap como cualquiera salvo `cross_tenant_reports.view`) — NO
  cross-tenant.

**Disciplina de serializador (§6.2): la lectura del docente devuelve un `Data` de 4 campos, jamás el
AR model.** `AnalyticsBi::Lens::AuraScope` mapea cada fila a un
`Aura(kind, guidance, effective_from, effective_until)` — así el SVG solo puede interpolar esos cuatro
campos nombrados (allowlist por construcción), sin ninguna posibilidad de traversar `:student` u otra
asociación, ni de un `to_json` crudo. El docente ve ÚNICAMENTE la proyección.

**Aislamiento clínico probado a nivel de MODELO (no solo HTTP) — el caso de aceptación Clase S que
el prompt exigía:** (1) un **SQL tap** (`ActiveSupport::Notifications.subscribed("sql.active_record")`)
sobre el camino de lectura del docente (`AnalyticsBi::Lens::SpatialClassroom.for(with_auras: true)`,
llamado directo bajo el GUC, no por HTTP) afirma que NINGUNA query toca
`counseling_cases`/`session_notes`/`referrals` — y que SÍ lee `care_auras` (prueba que el tap
funciona, no un falso verde); (2) una aserción estructural de que
`AnalyticsBi::CareAura.reflect_on_all_associations` no apunta a ningún `Counseling::*`; (3)
`AuraScope` devuelve solo el `Data` de 4 campos. Grep de cierre: `analytics_bi` menciona "counseling"
ÚNICAMENTE en comentarios, jamás en código/queries. El caso María (§6.4) se replica además a nivel
HTTP: `hps.aura.view` surface el badge con solo enum+texto, sin él el grid plano sin fuga, SQL tap
sobre la request real, 403 fuera de scope, 404 cross-tenant.

**Entitlement:** el lado docente cuelga del addon `analytics_bi` (namespace `analytics_bi/*`, ya
gateado por `Entitlement::Controller`); el lado autoría cuelga del addon `counseling` (namespace
`counseling/*`, ya gateado). Un colegio con `counseling` pero sin `analytics_bi` publica auras que el
orientador ve en el caso pero ningún docente ve en un mapa — borde aceptado, no un gap.

**Tests (20 nuevos, suite completa 626 → 646 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):**
- Modelo/servicio (`test/models/analytics_bi/care_aura_test.rb`): publicación por el `Projector`,
  enum cerrado (validación + CHECK), concurrencia (kinds distintos coexisten; misma-kind activa
  duplicada lanza `RecordNotUnique`), append-only (republicar cierra+abre), retire idempotente,
  `group_id` delegado, + **los dos tests de aislamiento clínico a nivel de modelo** (SQL tap +
  estructura de asociaciones) + el `Data` de 4 campos de `AuraScope`.
- Autoría (`test/integration/counseling_care_aura_authoring_test.rb`): `counseling.read` solo NO
  publica (403 en `new` y `create`), `counseling.write` publica vía el `Projector`, aparece en el show
  del caso, append-only, retire.
- Aceptación de seguridad del docente (`test/integration/analytics_bi_care_aura_test.rb`, espíritu
  María §6.4): `hps.aura.view` surface el badge (enum+texto), sin él el grid plano sin fuga, SQL tap
  sobre la request real (cero counseling), 403 fuera de scope, 404 cross-tenant.
- Sin SimpleCov en el repo (Minitest sin gema de cobertura, igual que Slice 2) — la cobertura se
  sostiene por los tests de modelo/servicio/controller (happy + fallo) descritos.

**Migración:** `bin/migrate` en dev y test (nunca `rails db:migrate`); `bin/rails zeitwerk:check`
verde (constantes colapsadas correctas: `AnalyticsBi::Aura::{Projector,CounselorScope}`,
`AnalyticsBi::Lens::AuraScope`, `AnalyticsBi::CareAura`). `TenantRlsGuardTest` verde (RLS
`ENABLE+FORCE` + índice líder `institution_id` en `care_auras`).

Ver `BI_DOCUMENT.md` §14 (v0.4.0) y `OPEN_PROCESS.md` ítem #22 + guardrails v1.37.0 para el detalle.

### v1.36.0 — 2026-07-17 — `analytics_bi`: Lente 1 "Mapa de Empatía Espacial" (Slice 2 de `BI_DOCUMENT.md`)

**Séptimo slice post-MVP, segundo guiado por `guidelines/BI_DOCUMENT.md`.** Construye la superficie
espacial canónica del HPS (la Lente 1): el plano IRL del aula con una capa de calor derivada de datos
que ya existen (notas, asistencia), para que el docente/director de grupo vea de un vistazo quién
necesita atención — *el estudiante contra sí mismo, nunca un ranking entre niños* (no-negociable
§1.1.3). Dos mitades: geometría de aula **net-new** (dato primario que había que modelar) + heat
**derivado** de T1 (dato que ya estaba).

**Recon-first (§12):** `grep create_table classroom_layouts|seat_assignments` → no existían (confirma
§5.0). El patrón `EXCLUDE USING gist` (btree_gist) ya estaba en el repo desde v1.33.0
(`subscriptions`/`institution_entitlements`) — se copió el idioma exacto, incluido `COALESCE(fin,
'infinity'::date)` para el extremo abierto. `helpers/` NO está en la lista de colapso de Zeitwerk
(`config/application.rb` colapsa solo `{models,queries,services,jobs,policies}`), así que el helper
SVG fue a `services/svg/` (colapsa a `AnalyticsBi::Svg::*`), verificado con `zeitwerk:check` antes de
cerrar.

**Decisión A2 ejecutada (owner-approved): la geometría la POSEE `group_management`, no
`analytics_bi`.** El aula física es dato de `group_management` (dueño de `Section`/`Student`), igual
que `analytics_bi` ya lee `Schedules::Assessment`/`Attendance::AttendanceRecord` sin poseerlas (§5.1).
Dos tablas net-new tenant-scoped (RLS `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`, sin
columnas de dinero):

- **`GroupManagement::ClassroomLayout`** — una configuración versionable por `(section,
  academic_term)`: `rows`/`cols` smallint, `board_orientation` (0·90·180·270, CHECK), `aisles` jsonb
  (geometría pura, default `[]`, nunca PII), `version`, `effective_from`/`effective_until`.
- **`GroupManagement::SeatAssignment`** — quién se sienta dónde: `classroom_layout_id`/`student_id`/
  `"row"`/`"col"` (smallint), efectivo-fechado.

**Tres `EXCLUDE USING gist`** — la integridad vive en la BD, no en la app: (1)
`classroom_layouts_no_overlapping_versions` por `(institution, section, term, daterange)` — una sola
versión vigente + append-only real (más allá de "una activa a la vez"); (2)
`seat_assignments_no_double_booked_seat` por `(institution, layout, row, col, daterange)`; (3)
`seat_assignments_no_two_seats_per_student` por `(institution, layout, student, daterange)`. `"row"`
va entrecomillado en TODO SQL crudo (palabra reservada de SQL — sin las comillas la migración explota
al parsear el CHECK y el EXCLUDE). `btree_gist` ya lo habilitó la migración de billing; el `down` de
esta migración NO lo elimina (los constraints de billing siguen dependiendo de él).

**Reconfiguración append-only, molde simétrico `Subscription#end!`/`Entitlement#revoke!`.**
`GroupManagement::ClassroomReconfigurer` cierra la versión vigente y abre `version + 1` (los
`seat_assignments` viejos quedan intactos → histórico preservado); `GroupManagement::SeatAssigner`
cierra el asiento activo del estudiante antes de abrir el nuevo (mover ≠ violar el constraint), y
`unassign` solo cierra. **Desviación de redacción documentada:** §5.3 esbozaba `effective_until =
ayer`; se cierra con `Date.current` en su lugar — con `daterange '[)'`, `[from, hoy)` y `[hoy, ∞)`
son ADYACENTES (nunca solapan), lo que satisface el `EXCLUDE` Y funciona reconfigurando el mismo día
en que se creó la versión (ayer violaría el CHECK `effective_until >= effective_from` y dejaría un
hueco de un día). Ambos servicios abren su transacción con **`requires_new: true` (SAVEPOINT)** — sin
eso, una violación de exclusión (double-booking) abortaba la transacción entera del request
(`TenantScoped` around_action), y aunque el controller rescatara la excepción, el `COMMIT` final
explotaba con "current transaction is aborted"; con `requires_new` la violación revierte solo al
savepoint y re-lanza limpio (bug real encontrado corriendo los tests, ver abajo).

**Dos superficies, dos gates distintos (no se colapsan):**

- **Reconfiguración (WRITE) en `group_management`, gate `groups.manage`** (mismo permiso que edita la
  matrícula del grupo — gestionar el aula física es la misma capacidad): `ClassroomLayoutsController`
  (crear/reconfigurar) + `SeatAssignmentsController` (asignar/mover/liberar), colgados de
  `/group_management/groups/:id/`, enlazados desde el show del grupo. UX **select-based**, sin
  drag-and-drop — "aburrido sobre ingenioso", y sin precedente de nested-attributes-con-JS en esta
  casa que respalde un builder cliente-side. El double-booking (constraint) se surface como alerta
  amable, nunca un 500.
- **Lectura del mapa (Lente 1) en `analytics_bi`, gate `hps.classroom.view`** (permiso NUEVO en
  `SeedPermissions::CATALOG` — per-institución; `institution_admin` lo hereda por el bootstrap
  `FirstAdmin` como cualquier key salvo `cross_tenant_reports.view`; NO es cross-tenant). Molde #4
  (supervisión): `AnalyticsBi::SpatialClassroomsController` con `authorize!` al inicio de cada acción;
  query object `AnalyticsBi::Lens::SpatialClassroomScope` (filtro de inquilino explícito + per-row
  `can?` sobre `layout.section` — un grant `:group` la cubre vía `Section#group_id`, uno
  `:grade_level` vía `section.grade_level_id`, ambos por los `SCOPE_READERS` existentes). `can?` solo
  cosmético en vistas.

**Heat in-memory, HSL server-side, cero recomputación en cliente (§7 default, §10.2).**
`AnalyticsBi::Lens::SpatialHeatmap` (molde `InstitutionDashboard`/`ReportCards::Computation`) deriva
por estudiante un valor 0..1 (mayor = más necesita atención) de `Schedules::Assessment.graded`
(nota/5.0) + `Attendance::AttendanceRecord` (presentes ÷ registrados, últimos 30 días); `wellbeing =
media de las señales disponibles`, `heat = 1 - wellbeing`. Sin datos → `heat` **nil** (empty state
real, dimmed/neutral, nunca un 0 engañoso — mismo principio que v1.34.0). Mapea a `hsl(hue,72%,52%)`
con `hue = (1-heat)*130` (calmo verde → cálido rojo), emitido como variable CSS `--heat` por asiento.
`AnalyticsBi::Lens::SpatialClassroom` compone layout + asientos + heat como read-model (un objeto por
controller, Sandi Metz).

**SVG server-rendered (§10.1): `AnalyticsBi::Svg::SeatGrid`** (`services/svg/seat_grid.rb`).
Renderiza la grilla como SVG plano (mismo molde que `shared/_bar_chart`, sin librería de charting),
un `<g class="seat">` por asiento con `style="--heat: hsl(...)"` + `data-needs-attention`/`data-heat`.
**AA, nunca color solo (UX_UI §7):** el asiento que necesita atención lleva una marca "!" +
`aria-label`, y una tabla `visually-hidden` espeja cada asiento (el significado nunca depende de leer
el color). **Cero PII al cliente más allá de lo permitido:** solo iniciales en el SVG; el nombre
completo solo en la tabla que el observador ya puede ver server-side. Stimulus
`spatial_map_controller.js` atenúa los estables (`.seat--dimmed`) resaltando quienes necesitan
atención, solo con data-attributes ya en el DOM — sin round-trip, sin `localStorage` (§10.4).

**Aura overlay (§5.7, `care_auras`) DEFERIDO a Slice 3.** La Lente 1 de §5.7 menciona un ícono de
aura abstracta sobre el pupitre del docente; este slice construye SOLO el mapa espacial + heat. El
cableado del aura se hará al construir el Slice 3 (`counseling` → proyección) — anotado en el doc.

**Tests (18 nuevos, suite completa 626 runs / 0 fallos / 1 skip preexistente, en serie
`PARALLEL_WORKERS=1`):**
- Modelo (los tres `EXCLUDE`): reconfigurar a mitad de año cierra la versión y abre la siguiente sin
  violar; dos versiones solapadas para el mismo `(section, term)` lanzan `StatementInvalid`;
  double-book de un asiento lanza; un estudiante con dos asientos activos lanza; mover un estudiante
  (cerrar + abrir) NO viola y preserva el histórico.
- Unit de heat: thriving (heat bajo, no needs_attention), struggling (heat alto, needs_attention),
  sin-datos (heat nil, `hsl` neutral), y una sola señal disponible.
- Aceptación de superficie (espíritu del caso de María, §6.4): `authorize!` + scope realmente gatean
  quién ve qué aula — grupo-scoped ve solo la suya en el índice, 403 fuera de scope, 404 cross-tenant
  (nunca fuga), y el write gateado por `groups.manage` (no por `hps.classroom.view`).
- **Hallazgo de testing (nuevo guardrail):** una violación de constraint dentro de una transacción
  *joinable* aborta la transacción entera; los tests de modelo fijan el GUC sobre la transacción de
  fixtures (no una anidada joinable) para que cada `create!` que viola caiga a su propio savepoint
  (comportamiento estándar de Rails en tests transaccionales), y los servicios usan `requires_new:
  true` por la misma razón en producción. Sin SimpleCov configurado en el repo (Minitest sin gema de
  cobertura) — la cobertura se sostiene por los tests de modelo/servicio/controller (happy + fallo)
  descritos, no por un reporte automatizado.

Ver `BI_DOCUMENT.md` §14 (v0.3.0) y `OPEN_PROCESS.md` ítem #21 + guardrails v1.36.0 para el detalle.

### v1.35.0 — 2026-07-17 — `analytics_bi`: `CrossTenantReportRoster` real (mitad cross-tenant, Slice 1 de `BI_DOCUMENT.md`)

**Sexto slice post-MVP**, primero guiado por `guidelines/BI_DOCUMENT.md` (nuevo documento maestro del
dominio, HPS/BI Empático). Cierra la mitad que v1.34.0 dejó deliberadamente en stub: el reporte
cross-tenant, primera conexión REAL de la app como el rol Postgres `edu_bi_reader` (`BYPASSRLS`).

**Recon:** `edu_bi_reader` YA EXISTÍA en el clúster local con `BYPASSRLS` y `SELECT` ya otorgado en
dev y test (`lib/tasks/roles.rake`, corrido en algún momento anterior) — solo la contraseña era
desconocida (`EDU_BI_READER_PASSWORD` no estaba en `.env`). Reseteada vía `psql` con el superusuario
del SO (mismo mecanismo ya documentado para `EDU_MIGRATOR_PASSWORD` cuando se pierde), cluster-wide
— un solo `ALTER ROLE` cubre dev y test.

**Diseño construido:**
- `AnalyticsBi::BiReaderRecord` (nuevo) — la ÚNICA clase que conecta como `edu_bi_reader`: un pool de
  conexión SEPARADO, nunca reconfigura el primario de `edu_app_runtime`. `establish_connection` vía
  `ActiveRecord::Base.configurations.configs_for(env_name:, name: "primary").configuration_hash.merge(
  username: "edu_bi_reader", password: ENV["EDU_BI_READER_PASSWORD"])` — `configs_for` parsea
  `database.yml` sin necesitar una conexión ya abierta (seguro en tiempo de autoload). Contraseña
  SIN `.fetch` (nil válido, igual que `EDU_DB_PASSWORD` del primario): Postgres local confía
  conexiones TCP de localhost sin importar el rol — confirmado empíricamente
  (`AnalyticsBi::BiReaderRecord.connection.select_value("SELECT current_user")` devuelve
  `"edu_bi_reader"` sin ninguna variable de entorno seteada); un deployment real sí necesita la
  variable real.
- `AnalyticsBi::BiReader::{Institution,Student,Assessment}` (nuevos) — clases lectoras DEDICADAS bajo
  esa conexión. Nunca se reusan `Core::Institution`/`GroupManagement::Student`/`Schedules::Assessment`
  (heredan de `ApplicationRecord`, atadas para siempre al pool primario).
- `AnalyticsBi::CrossTenantReportRoster.all` reemplaza el stub — agrega estudiantes activos y nota
  promedio, SIEMPRE `.group(:institution_id)` explícito (el "doble filtro a nivel de aplicación" de
  `BI_DOCUMENT.md §6.1.2`: una vez bypasseado RLS, el `GROUP BY` de la app es la ÚNICA defensa contra
  mezclar tenants — nunca un agregado sin agrupar). Solo agregados por institución salen del método,
  cero fila/PII de estudiante cruza la frontera.
- `cross_tenant_report_accessed` nuevo en `IdentityAccess::AuditEventIndex::ACTIONS`, logueado desde
  `CrossTenantReportsController#index` bajo la institución del propio `bi_auditor` (NO
  `ControlPlane::Audit` — el actor es staff de tenant con el permiso, no un `platform_admin`).

**Hallazgo de testing crítico (el verdadero riesgo de este slice, no el código de producción):**
`CrossTenantReportRoster` corre en una conexión de BD GENUINAMENTE separada — nunca ve la
transacción abierta-y-nunca-comiteada de un test transaccional normal de Rails. El primer intento de
test, con `self.use_transactional_tests = false` pero SIN teardown, llamó `grant_full_entitlements`
(crea los ~13 `Addon` de catálogo, GLOBALES, PARA TODOS LOS DOMINIOS, de verdad) — esas filas,
comiteadas de verdad, chocaron (violación de índice único `key`) con decenas de tests no
relacionados más adelante en la MISMA corrida completa de la suite (nunca visible corriendo solo el
archivo nuevo). Corregido: (a) el test otorga SOLO el addon `analytics_bi` que necesita, nunca el
helper de "todos los dominios"; (b) un `teardown` explícito borra TODO en orden seguro de FK
(entitlement → role_assignment/role_permission/role → institution_user → institución; usuario
primero, cascada sus `sessions`). Un segundo hallazgo menor: sin el wrapper transaccional, el GUC ya
no "gotea hacia adelante" entre sentencias como en un test normal (el commit real de cada
`within_tenant` limpia el GUC de verdad, a diferencia de un savepoint) — `with_grants`/`grant_role!`
necesitan el GUC fijado explícitamente justo antes de llamarlos. Nuevo archivo dedicado,
`test/integration/analytics_bi_cross_tenant_test.rb`, separado de `analytics_bi_test.rb` (que sigue
100% transaccional) por esta única razón.

**Caso de aceptación, verificado end-to-end:** dos instituciones con 2 y 1 estudiante activo
respectivamente aparecen con sus conteos CORRECTOS y separados (nunca 3 para ambas, nunca 0 para
ninguna) en el reporte; cada acceso queda auditado bajo la institución del `bi_auditor`. Verificado
también que la suite COMPLETA (no solo el archivo nuevo) sigue en 0 pollution tras el fix — la
lección concreta de por qué el checklist de cierre siempre corre la suite entera.

**Resultado:** 608 runs / 2581 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
607; 1 test nuevo en `analytics_bi_cross_tenant_test.rb`, ajuste de aserción en
`analytics_bi_test.rb` para no depender de nombres de institución fuera de su propia transacción).
`bin/rails zeitwerk:check` verde. Sin migraciones — solo una contraseña de rol reseteada.

**Archivos nuevos/editados:**
- Modelos: `app/domains/analytics_bi/models/bi_reader_record.rb`,
  `app/domains/analytics_bi/models/bi_reader/{institution,student,assessment}.rb` (todos nuevos).
- Servicio: `app/domains/analytics_bi/services/cross_tenant_report_roster.rb`.
- Controller: `app/controllers/analytics_bi/cross_tenant_reports_controller.rb`.
- Vista: `app/views/analytics_bi/cross_tenant_reports/index.html.erb`.
- `app/domains/identity_access/services/audit_event_index.rb` (nueva acción en `ACTIONS`).
- Tests: `test/integration/analytics_bi_cross_tenant_test.rb` (nuevo),
  `test/integration/analytics_bi_test.rb`.
- Doc: `guidelines/BI_DOCUMENT.md` (nuevo, v0.2.0 — documento maestro del dominio).
- `.env`: `EDU_BI_READER_PASSWORD` agregado (referencia local; innecesario en dev/test por trust auth).

### v1.34.0 — 2026-07-17 — `analytics_bi`: `InstitutionDashboard` real (mitad tenant-scoped)

**Quinto slice post-MVP.** `analytics_bi` seguía 100% en fase stub (`InstitutionDashboard.stub`,
números fijos: 187 estudiantes, 3.8 de promedio, etc.). Decisión deliberada: cerrar SOLO la mitad
tenant-scoped en este slice — la mitad cross-tenant (`CrossTenantReportRoster`, rol
`edu_bi_reader`/`BYPASSRLS`) es la primera vez que la app conectaría con un rol Postgres distinto
para una query real, y merece su propio recon/checkpoint, no colarse aditiva aquí.

**Lo construido:** `AnalyticsBi::InstitutionDashboard.for(institution:)` reemplaza `.stub` —
mismas seis claves exactas que la vista ya esperaba (`total_students`/`avg_grade`/
`attendance_rate`/`enrollment_trend`/`grades_by_subject`/`status_breakdown`), cero cambios a la
vista salvo el manejo de `nil`.
- `total_students`: misma definición que `Core::Headcount::Snapshotter` (`status == "active"`,
  nunca filtrado por término) — pero SIN llamar a `Snapshotter.call`, que persiste una fila +
  un `Audit.log` por invocación (side-effect equivocado para una vista de solo lectura).
- `avg_grade`/`grades_by_subject`: `Schedules::Assessment.graded` (el gradebook compartido de
  siempre, `schedules::Assessment`), agrupado por materia para el segundo.
- `attendance_rate`: presentes ÷ total de `Attendance::AttendanceRecord` de los últimos 30 días.
- `enrollment_trend`: la ÚNICA excepción que lee histórico en vez de recalcular —
  `ControlPlane::StudentHeadcountSnapshot` (real de verdad desde que `SnapshotAllJob` corre solo,
  v1.32.0), reusado sin re-computarlo.
- `avg_grade`/`attendance_rate` devuelven `nil` (nunca un `0`/`0%` engañoso) cuando no hay datos
  todavía — la vista muestra "—", mismo principio que "boletín sin notas no aporta línea, nunca
  un cero" ya establecido en `report_cards`.

**Caso de aceptación, verificado end-to-end:** con 2 estudiantes activos + 1 inactivo, dos notas
(4.0/3.0) y dos registros de asistencia (1 presente/1 ausente), el dashboard muestra exactamente
2 estudiantes, 3.5 de promedio, 50.0% de asistencia y "Álgebra" en el desglose por materia — todo
calculado en vivo, nada hardcodeado. Una institución sin datos ve "—" en vez de un cero falso.

**Resultado:** 607 runs / 2572 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
606; el test existente de `analytics_bi_test.rb` se corrigió — ya no espera el número fijo del
stub — y se agregó el caso de aceptación con datos reales). `bin/rails zeitwerk:check` verde. Sin
migraciones.

**Archivos nuevos/editados:**
- Servicio: `app/domains/analytics_bi/services/institution_dashboard.rb`.
- Controller: `app/controllers/analytics_bi/institution_dashboard_controller.rb`.
- Vista: `app/views/analytics_bi/institution_dashboard/show.html.erb`.
- Test: `test/integration/analytics_bi_test.rb`.

### v1.33.0 — 2026-07-17 — Hardening de billing: exclusion constraints GiST (solapamiento de rangos)

**Cuarto slice post-MVP.** De los cuatro sub-ítems documentados bajo "hardening, no construido"
(`OPEN_PROCESS.md` §1.5.3), solo el de exclusion constraints es un default seguro de construir sin
una decisión de producto nueva — prorrateo/edición manual de líneas/tabla `billing_periods`
explícita quedan abiertos, cada uno exige reglas de negocio reales que este slice no puede asumir.

**Recon:** los índices únicos parciales ya existentes (`index_subscriptions_one_active_per_
institution`, `index_entitlements_one_active_per_institution_addon`) YA prevenían "dos filas
ACTIVAS a la vez" — el exclusion constraint no era necesario para ESE invariante. El gap real:
ninguno de los dos chequeaba que una fila NUEVA no se solapara en el tiempo con una fila VIEJA
(ended/revoked) de la MISMA institución — un dato inconsistente hoy silencioso (dos "contratos"
reclamando el mismo rango de calendario), nunca antes verificado ni a nivel de app ni de BD.

**Lo construido:**
- Migración `20260717161248`: `CREATE EXTENSION btree_gist` (operator class de igualdad para
  `uuid` dentro de un `EXCLUDE`, PG18 nativo) + `EXCLUDE USING gist` en `subscriptions`
  (`institution_id WITH =`, `daterange(starts_on, COALESCE(ends_on,'infinity'::date),'[)') WITH &&`)
  y en `institution_entitlements` (mismo molde, + `addon_id WITH =`). Sin migrar datos — ninguna fila
  existente violaba el nuevo constraint (dev/test corrieron limpio).

**Bug real que el propio constraint destapó (no hipotético):** `Entitlement#revoke!` NUNCA cerraba
`valid_until` — a diferencia de `Subscription#end!`, que sí cierra `ends_on` desde su propio slice.
Un entitlement revocado seguía reclamando su rango hasta el infinito, así que revocar y volver a
otorgar el MISMO addon a la MISMA institución (flujo real y común: "quitar cafetería, dárselo de
nuevo más adelante") violaba el nuevo `EXCLUDE`. Corregido:
- `Entitlement#revoke!(valid_until: Date.current)` cierra el rango (mismo molde que `end!`).
- `Entitlement#reactivate!` reabre la MISMA fila (`valid_until: nil`), sin tocar `valid_from` —
  nunca crea una nueva.
- Mismo restricción "no el mismo día" que ya tenía `Subscription#end!` (la validación
  `valid_until_after_valid_from` ya existía, sin cambios) — `EntitlementsController#revoke` ganó el
  MISMO `rescue ActiveRecord::RecordInvalid`/mensaje amable que ya usaba
  `SubscriptionsController#terminate`, copiado literal.

**Blast radius real del fix, encontrado corriendo la suite COMPLETA (nunca solo el archivo en el que
se trabajaba): 18 tests en ~13 archivos**, todos por la MISMA causa raíz —
`grant_full_entitlements` (`test_helper.rb`) sembraba el entitlement por defecto de CADA test con
`valid_from: Date.current`, y decenas de tests de "entitlement gate #1" (uno por dominio addon-
gated) lo revocan el MISMO día dentro del mismo test para simular "institución sin el módulo".
Arreglado en UN solo lugar (`valid_from: 1.day.ago.to_date` en el helper) — no se tocó cada archivo
individualmente, salvo los 4 tests que YA creaban su propio entitlement inline con `Date.current`
(`entitlement_test.rb`, `entitlements_check_test.rb`, `control_plane/entitlements_test.rb`,
`control_plane/addons_test.rb`), que se corrigieron uno por uno por ser setups propios, no del
helper compartido.

**Caso de aceptación, verificado end-to-end:** revocar un entitlement con `valid_from` en el pasado
cierra `valid_until` a hoy; reactivarlo reabre la MISMA fila; un intento de re-otorgar el mismo
addon a la misma institución con un rango que se solapa con uno YA REVOCADO es rechazado por la
BASE DE DATOS (`ActiveRecord::StatementInvalid`/`PG::ExclusionViolation`), nunca silenciosamente
aceptado — la app nunca chequeaba esto antes. Revocar el mismo día que se otorgó sigue dando el
mensaje amable existente, nunca una excepción cruda.

**Resultado:** 606 runs / 2562 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
603; 4 tests nuevos en `entitlement_test.rb`, 18 tests preexistentes reparados por la causa raíz
compartida — no nuevas aserciones de negocio, solo fechas de setup corregidas). `bin/rails
zeitwerk:check` verde. Una migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260717161248_add_no_overlap_exclusion_constraints_to_billing.rb`.
- Modelo: `app/control_plane/control_plane/entitlement.rb`.
- Controller: `app/control_plane/control_plane/entitlements_controller.rb`.
- Test helper: `test/test_helper.rb` (`grant_full_entitlements`).
- Tests: `test/models/control_plane/entitlement_test.rb`,
  `test/models/control_plane/entitlements_check_test.rb`,
  `test/integration/control_plane/{entitlements,addons}_test.rb` (fechas de setup corregidas).

### v1.32.0 — 2026-07-17 — Schedule recurrente para SnapshotJob/RollupJob/PeriodCutJob/Expirer

**Tercer slice post-MVP.** `Core::Headcount::SnapshotJob`, `ControlPlane::Usage::RollupJob`,
`ControlPlane::Billing::PeriodCutJob` e `IdentityAccess::Invitations::Expirer` quedaban
"invocables manual/rake" desde sus slices originales (S3a/S4/v1.7.0) — `config/recurring.yml`
(Solid Queue) ya existía en el repo (con `clear_solid_queue_finished_jobs` real, del scaffold)
pero sin ninguna entrada propia del proyecto.

**Recon:** ninguno de los tres jobs per-institución (`SnapshotJob.enqueue_for`, `PeriodCutJob#perform
(institution_id:, ...)`, `Expirer.call(institution:)`) puede colgar DIRECTO de una entrada de
`recurring.yml` — esa entrada solo invoca UNA clase con args fijos, y estos necesitan una
institución distinta por invocación. `RollupJob` es la excepción: global/self-contenido desde
S3a (agrupa TODOS los `usage_events` de un día, sin GUC), así que cuelga directo sin wrapper.

**Diseño construido — patrón fan-out, un wrapper por job per-institución:**
- `Core::Headcount::SnapshotAllJob` — itera `Core::Institution.find_each`, encola un
  `SnapshotJob.enqueue_for(institution)` por cada una (sin tocar ese método existente).
- `ControlPlane::Billing::PeriodCutAllJob` — corta el **mes calendario ANTERIOR completo**, solo
  para instituciones con `ControlPlane::Subscription.active` AHORA MISMO (una sin suscripción se
  salta silenciosamente — caso común, no una falla a loguear); encola `PeriodCutJob.perform_later`.
- `IdentityAccess::Invitations::ExpireAllJob` — el más distinto: `Invitation` es tenant-scoped/RLS
  (a diferencia de las tablas globales de los otros dos), así que este job gestiona su PROPIO loop
  de `ActiveRecord::Base.transaction { Tenant::Guc.set_local(...) } ensure Tenant::Guc.reset!` por
  institución — no hay un `.enqueue_for` previo que reusar, `Expirer.call` nunca corrió como job.
- `config/recurring.yml`, bloque `production:` (dev/test siguen con los rakes manuales): rollup
  1am → snapshot 2am → sweep de invitaciones 4am (diarios); corte de facturación 3am del día 1 de
  cada mes — orden elegido para que billing/headcount vean datos ya asentados del día anterior.

**Hallazgo de testing (no un bug del job):** el primer intento de test de `ExpireAllJob` reportó
"GUC leaked past the job" — falso positivo. La causa real: las aserciones DESPUÉS del job usaban
`within_tenant(...)` (el helper de test, que deliberadamente NUNCA resetea el GUC — es un atajo
"corre esto bajo X", no una garantía de limpieza) para releer `issued_a`/`issued_b`, dejando el
GUC fijado ANTES de la aserción "no hay fuga". Aislado con `bin/rails runner` (fuera del wrapper
transaccional de Minitest) para confirmar que el job en sí resetea correctamente — el fix fue
reordenar el test, no tocar el job. Nuevo guardrail sobre esto.

**Caso de aceptación, verificado end-to-end:** `SnapshotAllJob`/`PeriodCutAllJob` encolan
exactamente un job por institución elegible (verificado con `assert_enqueued_jobs`/inspección de
argumentos serializados); drenar la cola snapshotea cada institución y corta un borrador de
factura de junio cuando se corre en julio; `ExpireAllJob` expira invitaciones vencidas de DOS
instituciones distintas bajo sus GUCs correctos, sin fuga verificada con una query real bajo RLS
(nunca una relectura de `current_setting()`).

**Resultado:** 603 runs / 2557 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
598; 5 tests nuevos: 2 en `snapshot_all_job_test.rb`, 2 en `period_cut_all_job_test.rb`, 1 en
`people_management_test.rb`). `bin/rails zeitwerk:check` verde. Sin migraciones.

**Archivos nuevos/editados:**
- Jobs: `app/domains/core/jobs/headcount/snapshot_all_job.rb`,
  `app/control_plane/control_plane/billing/period_cut_all_job.rb`,
  `app/domains/identity_access/jobs/invitations/expire_all_job.rb` (los tres nuevos).
- Config: `config/recurring.yml`.
- Comentarios actualizados (ya no "deferred"): `period_cut_job.rb`, `invitations/expirer.rb`.
- Tests: `test/models/core/headcount/snapshot_all_job_test.rb` (nuevo),
  `test/models/control_plane/billing/period_cut_all_job_test.rb` (nuevo),
  `test/integration/people_management_test.rb`.

### v1.31.0 — 2026-07-17 — RBAC intra-plano (`platform_admin` roles)

**Segundo slice post-MVP.** Con S3b cerrado, el owner (autónomo — decisiones tomadas siguiendo
siempre la opción recomendada, per instrucción explícita de iterar sin pausas) siguió con el
siguiente ítem del backlog de billing (`OPEN_PROCESS.md` §1.5.4): cualquier `platform_admin`
autenticado administraba TODO el plano de control (catálogo, provisioning, subscripciones,
entitlements, facturas, otros admins) — el propio código de `AddonsController` lo documentaba
("no intra-plane RBAC in S1, scope creep, deferred").

**Recon:** `platform_admins` no tenía NINGUNA columna de rol/scope. `PlatformAdminsController` solo
expone `index/show/suspend/reactivate` — el alta es SOLO por CLI de bootstrap
(`lib/tasks/control_plane.rake`), nunca por la UI. Confirmado: ningún otro dato de scope
(departamento/institución) tendría sentido aquí — el plano de control es cross-tenant por diseño.

**Decisión (recomendada, elegida):** un mapeo ESTÁTICO rol→permisos en código, NUNCA el esquema
completo del inquilino (`roles`/`role_permissions`/`role_assignments` con columnas de scope) — los
platform admins son un puñado de personas de ops, no un sistema de autoservicio. Tres roles:
`super_admin` (todo), `billing_ops` (provisioning + billing del día a día, SIN catálogo ni gestión
de otros admins), `viewer` (solo lectura). Reads (`index`/`show`) quedan abiertos a CUALQUIER admin
activo sin importar el rol — solo las mutaciones se gatean, mismo split "escritura=RBAC,
lectura=membresía" que ya usa el lado del inquilino.

**Lo construido:**
- Migración `20260717155106_add_role_to_platform_admins.rb`: columna `role` string, CHECK
  `IN ('super_admin','billing_ops','viewer')`, **default `super_admin`** — backward-compatible a
  propósito: TODO admin/test preexistente conserva acceso completo sin tocar una sola línea.
- `ControlPlane::Authorization` (concern nuevo, incluido en `BaseController`): `PERMISSIONS_BY_ROLE`
  (constante congelada), `authorize_platform!(permission)` (puerta dura, `raise NotAuthorized` →
  `rescue_from` → 403 amable, `control_plane/errors/forbidden.html.erb` nuevo, mismo molde que
  `Authorization::Controller` del inquilino), `can_platform?(permission)` (cosmético, para ocultar
  botones).
- Cuatro permisos: `catalog.manage` (`AddonsController`/`PlansController`, `super_admin` solo),
  `institutions.manage` (`InstitutionsController#new/#create`), `billing.manage`
  (`SubscriptionsController`/`EntitlementsController`/`InvoicesController`, todas las mutaciones),
  `platform_admins.manage` (`suspend`/`reactivate` de OTROS admins — el más sensible, `super_admin`
  solo). `billing_ops` recibe `institutions.manage`+`billing.manage`; `viewer`, ninguno.
- Vistas: botones "Nuevo addon"/"Nuevo plan"/"Nueva institución" y "Suspender"/"Reactivar" (en el
  índice de `platform_admins`, que también ahora muestra la columna `role`) ocultos vía
  `can_platform?` para quien no tiene el permiso — cosmético, el gate real sigue en el controller.

**Caso de aceptación, verificado end-to-end:** un `viewer` lee todo (addons/plans/institutions/
invoices) pero cada mutación (crear addon/plan/institución, abrir subscripción/entitlement/factura,
suspender otro admin) da 403 con la página amable, nunca una excepción cruda; un `billing_ops`
provisiona instituciones pero no puede tocar el catálogo ni suspender a otro admin; un
`super_admin` sigue haciendo todo, incluida la gestión de otros admins. Los 52 tests preexistentes
del plano de control pasaron SIN NINGÚN CAMBIO (el default `super_admin` preserva el comportamiento
de antes de este slice al pie de la letra).

**Resultado:** 598 runs / 2539 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
593; 5 tests nuevos en `test/integration/control_plane/authorization_test.rb`). `bin/rails
zeitwerk:check` verde. Una migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260717155106_add_role_to_platform_admins.rb`.
- Modelo: `app/control_plane/control_plane/platform_admin.rb`.
- Concern: `app/control_plane/control_plane/authorization.rb` (nuevo), `base_controller.rb`.
- Controllers: `addons_controller.rb`, `plans_controller.rb`, `institutions_controller.rb`,
  `subscriptions_controller.rb`, `entitlements_controller.rb`, `invoices_controller.rb`,
  `platform_admins_controller.rb`.
- Vistas: `control_plane/errors/forbidden.html.erb` (nueva), `addons/index`, `plans/index`,
  `institutions/index`, `platform_admins/index`.
- Test: `test/integration/control_plane/authorization_test.rb` (nuevo).

### v1.30.0 — 2026-07-17 — S3b: emisión real de uso por dominio (post-MVP, M1 medio cerrado)

**Primer slice post-MVP** — con el camino crítico de `LINEAMIENTOS_MVP.md` completo (v1.29.0), el
owner eligió continuar con el track de billing del plano de control (`PROJECT_STATE.md` §7) en vez
de RBAC intra-plano o `analytics_bi`. Cierra (parcialmente) M1: "unidad de metering por dominio
medido", abierto desde que el pipe de uso se construyó (S3a) sin que ningún dominio lo llamara.

**Recon (STOP #1):** `ControlPlane::Usage::Ingest`/`UsageEvent`/`UsageDailyRollup`/`RollupJob` ya
eran reales desde S3a — confirmado con grep que CERO dominio los invocaba fuera de
`test/models/control_plane/usage/*`. De los 13 dominios en `AddonCatalog::DOMAIN_KEYS`, solo 6 son
Clase A con un evento de escritura real e inequívoco (`communication`, `attendance`,
`extracurriculars`, `assignments`, `report_cards`, `finance`); el resto es Clase C (`transportation`,
`cafeteria`, `student_support`, `analytics_bi` — cero tabla real que emitir) o sensible/diferido
(`counseling`). Hallazgo crítico: `transportation` estaba sembrado `metered:true, unit:"check-ins"`
en `seed_catalog.rb` desde S1 — 100% aspiracional, el dominio nunca tuvo ningún checkout real.
`extracurriculars` (v1.27.0) nunca tuvo fila `Addon` en el seed en absoluto (creado después de que
`AddonCatalog::DOMAIN_KEYS` lo incluyera, nunca backfilleado). `ControlPlane::Billing::PeriodCut` ya
sumaba `UsageDailyRollup` correctamente por rango de fecha+addon — confirmado que no necesitaba
ningún cambio.

**Checkpoint de diseño (STOP #2) — decisiones del owner:**
1. **Alcance: barrido completo de los 6 dominios Clase A en un solo slice** (no incremental
   domain-por-domain como otros tracks) — M1 es una decisión de negocio DISTINTA por dominio, pero
   no exige cerrarse de a una.
2. **`transportation` se corrige a `metered:false`** en el mismo slice — un seed que promete
   medición sobre un evento inexistente es engañoso.

**Diseño construido:**
- **`ControlPlane::Usage::Ingest.emit`** (nuevo, junto a `.call` — sin tocar su contrato original,
  seguido probando por el test suite de S3a): rescata específicamente `Rejected` (addon no
  sembrado/no medido) y devuelve `nil` — nunca rompe la acción de negocio real por un problema de
  configuración de billing. Cualquier otro error sigue propagando.
- **Seis call sites, cada uno con su propia ancla de idempotencia** — la lección repetida del
  slice: usar el id de la fila SOLO si es estable; si el hecho de negocio se REGENERA, la clave debe
  ser la tupla semántica, no un id volátil.
  - `Communication::MessageSender` → "mensajes", `message:#{id}` (cada envío es una fila nueva).
  - `Attendance::RecordsController#create` → "registros", `attendance_record:#{record.id}`
    (re-tomar el mismo (grupo, fecha) reusa la MISMA fila vía `find_or_initialize_by`, uno por
    estudiante del roster).
  - `Extracurriculars::EnrollmentCreator` → "inscripciones", `enrollment:#{id}` (solo alcanzado tras
    el guard de idempotencia propio del servicio — un re-enroll activo nunca re-emite).
  - `Assignments::SubmissionRecorder` → "entregas", `submission:#{id}` (upsert — reeditar/resubmit
    reusa la fila, uno por GRUPO en una tarea grupal, nunca por integrante).
  - `Finance::ChargeCreator`/`PaymentRecorder` → "transacciones" (mismo unit para ambos),
    `charge:#{id}`/`payment:#{id}` — ambos servicios YA tenían su propio guard de idempotencia
    previo al lock (v1.18.0), reusado tal cual.
  - **`ReportCards::Publisher` rompe el patrón "usar el id de la fila"**: `publish_one` hace
    `delete_all`+`create!` en cada re-publicación (v1.17.0) — el `ReportCard#id` es NUEVO en cada
    regrade/republish. Ancla correcta: `"report_card:#{institution.id}:#{student.id}:#{academic_term.id}"`
    (el hecho de negocio "este boletín de este estudiante en este término", nunca la fila física) —
    verificado con un test dedicado que re-publica dos veces y confirma UN solo `UsageEvent` pese a
    un id de `ReportCard` distinto cada vez.
- **`seed_catalog.rb`**: los 5 dominios ganaron `metered:true`+`unit`+cupos de ejemplo (`registros`
  15.000/`entregas` 5.000/`boletines` 2.000/`transacciones` 3.000, más `mensajes` 10.000 ya existente);
  `extracurriculars` ganó su primera fila `Addon` (`inscripciones`, 500); `transportation` pasó a
  `metered:false`.
- **`PeriodCut`/`RollupJob` sin ningún cambio** — confirmado el recon, no hacía falta.

**Caso de aceptación, verificado end-to-end (uno por dominio, en el archivo de test existente de
cada dominio — nunca un archivo nuevo):** cada acción real (enviar un mensaje, tomar asistencia,
inscribir, entregar una tarea, publicar un boletín, cobrar/pagar) con el addon correspondiente
sembrado y medido crea exactamente un `ControlPlane::UsageEvent` con el `unit` esperado; repetir la
acción de forma idempotente (reenviar, re-tomar, re-inscribir, re-entregar, re-publicar,
re-cobrar/re-pagar con la MISMA `idempotency_key`) nunca duplica el evento; y — caso crítico —
`ReportCards::Publisher` re-publicando produce una fila `ReportCard` con id DISTINTO cada vez pero
sigue emitiendo un solo `UsageEvent`. Con el addon SIN sembrar/sin medir (el estado real de
`sign_in_as_member`, que crea el addon pero `metered:false` por defecto), la acción de negocio sigue
funcionando exactamente igual — `Usage::Ingest.emit` nunca la bloquea.

**Resultado:** 593 runs / 2506 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
581; 12 tests nuevos: 2 en `messaging_test.rb`, 1 en `attendance_test.rb`, 1 en
`extracurriculars_test.rb`, 1 en `submissions_test.rb`, 1 en `report_cards_test.rb`, 1 en
`finance_test.rb`, 2 en `ingest_test.rb` (`.emit`), 3 en el `seed_catalog_test.rb` nuevo — el primer
test de ese archivo). `bin/rails zeitwerk:check` verde. Sin migraciones.

**Archivos nuevos/editados:**
- `app/control_plane/control_plane/usage/ingest.rb` (`.emit`).
- `app/control_plane/control_plane/seed_catalog.rb`.
- `app/domains/communication/services/message_sender.rb`,
  `app/controllers/attendance/records_controller.rb`,
  `app/domains/extracurriculars/services/enrollment_creator.rb`,
  `app/domains/assignments/services/submission_recorder.rb`,
  `app/domains/report_cards/services/publisher.rb`,
  `app/domains/finance/services/{charge_creator,payment_recorder}.rb`.
- Tests: `test/models/control_plane/usage/ingest_test.rb`,
  `test/models/control_plane/seed_catalog_test.rb` (nuevo),
  `test/integration/{messaging,attendance,extracurriculars,submissions,report_cards,finance}_test.rb`.

### v1.29.0 — 2026-07-17 — Provisioning de instituciones + correo real (ítem #10 del MVP) — CAMINO CRÍTICO DEL MVP COMPLETO

**Último ítem del camino crítico de `LINEAMIENTOS_MVP.md`.** Dos decisiones cerradas con el owner
ANTES de codear (mismo checkpoint-first que todo dominio net-new de este track): (1) bootstrap del
primer admin en UN solo flujo, no dos pasos separados; (2) SMTP genérico vía credentials/ENV, no un
proveedor de API específico.

**Recon (STOP #1) — el hallazgo que cambió el diseño real:** `Provisioning::CreateInstitution`
(`lib/provisioning/`) YA EXISTÍA y ya la usaba `db/seeds.rb` para las dos instituciones demo — el
"provisioning" no era construir un servicio de dominio desde cero, era exponerlo vía HTTP. Pero un
recon más profundo encontró un chicken-and-egg REAL, sin resolver en ningún camino de producción:
`IdentityAccess::PeopleController#create` (cómo se une CUALQUIER persona a una institución) exige
`authorize!("people.manage")`, que exige un `RoleAssignment` YA EXISTENTE — y ningún flujo de
producción sembraba el primero. Solo pasaba en `test_helper.rb#grant_role!` (tests) y en
`lib/tasks/qa_seed.rake` (rake QA-only, `Rails.env.development?` obligatorio). Ni siquiera las
instituciones demo de `db/seeds.rb` tienen un `institution_admin` real hoy — confirmado, fuera de
alcance de este slice arreglarlo (`db/seeds.rb` no se tocó).

**Diseño construido:**
- `IdentityAccess::Bootstrap::FirstAdmin` (`services/bootstrap/first_admin.rb`) — el ÚNICO lugar
  autorizado a crear un `RoleAssignment` sin que ya exista uno previo. Corre `SeedPermissions.call`
  (idempotente, catálogo global), siembra el rol `institution_admin` con **TODO el catálogo de
  permisos EXCEPTO `cross_tenant_reports.view`** (ese key sigue reservado a `bi_auditor`/
  `edu_bi_reader`, nunca a un rol de institución — mismo guardrail de siempre; la lista se deriva de
  `CATALOG.keys`, nunca se hardcodea aparte, así que una permission nueva futura la hereda gratis),
  resuelve/crea la persona vía `Core::People::Resolver` (el MISMO resolver que usa el roster de
  estudiantes/acudientes, no uno nuevo) y la invita vía `IdentityAccess::Invitations::Issuer` (el
  MISMO camino que `PeopleController#create` — un email real, no un atajo con password directa).
- `Provisioning::ProvisionInstitution` (`lib/provisioning/`) — orquestador nuevo, UN solo flujo/UNA
  transacción: compone `CreateInstitution` (sin tocarla) + `Bootstrap::FirstAdmin`. Si cualquier paso
  falla, todo revierte — nunca queda una institución a medias sin quién la administre.
- `ControlPlane::InstitutionsController#new/#create` — molde exacto de `PlansController` (`create!`
  + `ControlPlane::Audit.log`); valida presencia de `admin_name`/`admin_email` en el boundary del
  form ANTES de llamar al servicio, deja que `ActiveRecord::RecordInvalid` burbujee a un único
  `rescue` (mismo molde que `PeopleController#create`). Solo `new`/`create` — sin `edit`/`destroy`:
  los campos de identidad de una institución no cambian una vez creada, y no hay necesidad de
  producto de des-provisionar una todavía.
- `Core::Institution` ganó `validates :slug/:code, uniqueness:` + `:kind, inclusion:` + `:slug`
  excluye los subdominios reservados de `Tenant::Resolver::SubdomainStrategy::RESERVED` (`www`,
  `app`, `admin`, `api`) — antes de este slice SOLO el índice único de Postgres los protegía, así
  que un duplicado explotaba como `ActiveRecord::RecordNotUnique`/`PG::CheckViolation` crudo frente
  a un formulario web, no un error de validación limpio.
- **Correo real**: los tres entornos estaban sin transporte configurado — ninguna gema, ninguna
  credencial, ningún proveedor decidido en ningún doc (`production.rb` seguía con el boilerplate
  `example.com`/SMTP comentado de `rails new`; `development.rb` no fijaba `delivery_method` en
  ningún lado, cayendo al default `:smtp` contra `localhost:25`, que se pierde en silencio con
  `raise_delivery_errors = false`). `production.rb` ahora usa SMTP genérico —
  `Rails.application.credentials.dig(:smtp, ...)` con fallback a `ENV["SMTP_*"]` (env gana cuando
  ambos están seteados) — funciona con CUALQUIER proveedor (Postmark/SendGrid/SES/Mailgun/un buzón
  propio) sin gema de proveedor, y `raise_delivery_errors = true` (un SMTP mal configurado debe
  fallar ruidoso, nunca perder un OTP/invitación en silencio). `development.rb` usa
  `delivery_method: :file` (`Mail::FileDelivery`, nativo de la gema `mail` que ActionMailer ya
  trae — CERO gemas nuevas), escribiendo a `tmp/mails/`; `bin/rails "qa:otp[...]"`
  (`lib/tasks/qa_seed.rake`) sigue vivo como atajo más rápido, ya no como el único camino (su
  comentario, que decía "el envío de correo no está configurado en development", se corrigió).
  `ApplicationMailer#from` pasó de `"from@example.com"` (placeholder sin editar) a
  `ENV.fetch("MAILER_FROM", "no-reply@edu-platform.test")`.

**Caso de aceptación, verificado end-to-end:** provisionar una institución vía
`POST /control_plane/institutions` crea la fila global + su `institution_settings` 1:1 + un
`IdentityAccess::Role` "institution_admin" con exactamente `CATALOG.keys - cross_tenant_reports.view`
(comparado el set completo, no una muestra) + un `RoleAssignment` institución-wide + una
`IdentityAccess::Invitation` real con `status: "sent"` + un correo entregado (verificado con
`ActionMailer::Base.deliveries`, el mismo camino de `PeopleController#create`); un slug duplicado da
un error de validación limpio (nunca una excepción cruda de BD); un `kind` inválido igual; sin
`admin_name`/`admin_email` nunca se crea NADA (ni la institución) — la transacción entera revierte.

**Resultado:** 581 runs / 2448 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
578; 4 tests nuevos, todos en `test/integration/control_plane/institutions_test.rb` — reemplazando
el test obsoleto "no hay ruta para crear una institución", cuya premisa este slice invalidó a
propósito). `bin/rails zeitwerk:check` verde. Sin migraciones — ninguna tabla nueva.

**Archivos nuevos/editados:**
- Servicios: `app/domains/identity_access/services/bootstrap/first_admin.rb`,
  `lib/provisioning/provision_institution.rb`.
- Modelo: `app/domains/core/models/institution.rb` (validaciones).
- Controller: `app/control_plane/control_plane/institutions_controller.rb` (`new`/`create`).
- Rutas: `config/routes.rb`.
- Vistas: `app/control_plane/views/control_plane/institutions/{new,_form}.html.erb`,
  `.../institutions/index.html.erb` (botón "Nueva institución").
- Mail: `config/environments/{development,production}.rb`, `app/mailers/application_mailer.rb`,
  `lib/tasks/qa_seed.rake` (comentario corregido).
- Tests: `test/integration/control_plane/institutions_test.rb`.

**Con esto se cierra el camino crítico completo de `LINEAMIENTOS_MVP.md` §7 (ítems #1–#10).** Lo que
queda documentado como diferido post-MVP (asistencia por materia, timetabling real, tiempo real en
`communication`/`transportation`, pasarela de pago, `student_support`/`counseling`/`cafeteria`/
`transportation` reales para este perfil) sigue exactamente igual — nada de esto lo reabre este
slice.

### v1.28.0 — 2026-07-17 — Portal del cuidador ampliado: asistencia + hallazgos de recon (ítem #9 del MVP)

**Ítem #9 del camino crítico de `LINEAMIENTOS_MVP.md`** — "colgar notas, asistencia, actividades,
calendario, asignaciones y mensajes" en el portal del acudiente. **Recon-first cambió el tamaño real
del slice**: un recon exhaustivo (controllers de `app/controllers/portals/`, `config/routes.rb`,
`Core::Access::GuardianScope`) confirmó que cinco de seis superficies YA colgaban reales del
namespace `/portal` — `report_cards` (v1.17.0), `finance` (v1.18.0), `communication` (v1.19.0/
v1.20.0), `assignments` (v1.21.0+), `calendar` (v1.27.0) y `extracurriculars` (v1.27.0) ya reusan
`GuardianScope`/`StudentSelfScope` sin RBAC, fuera de `Navigation::Registry`. El único hueco real:
`attendance` (v1.16.0) nunca tuvo ninguna superficie de portal — confirmado que su checkpoint de
diseño original (v1.16.0) nunca decidió portal, no fue un olvido de ese slice.

**Lo construido (attendance → portal):**
- `Attendance::StudentView.for(student:, institution:)` — query object nuevo (`queries/
  student_view.rb`), el único camino de lectura, mismo molde "una computación, N superficies" que
  `Finance::AccountStatement`/`ReportCards::Computation`/`Calendar::Timeline`. `AttendanceRecord`
  del estudiante, más reciente primero.
- `Portals::GuardianAttendanceController#show` — `GuardianScope.for(user).find(student_id)` primero
  (un hijo fuera del scope 404), luego `StudentView.for`. Mismo molde exacto que
  `GuardianCalendarController`.
- `Portals::StudentAttendanceController#show` — `StudentSelfScope.for(user)`, mismo molde que
  `StudentCalendarController` (sin estudiante vinculado ⇒ `.none`, nunca error).
- Rutas anidadas: `resource :attendance` bajo `portal/guardian/students/:student_id` y bajo
  `portal/student`, mismo estilo singular que `:calendar`.
- Vista compartida `attendance/_history` (una tabla fecha/grupo/estado/nota) + `AttendanceHelper`
  (`attendance_status_badge`, mismo molde `CounselingHelper#counseling_case_status_badge`) —
  reusada por ambas superficies de portal, ninguna duplica el markup.

**Dos hallazgos de recon, cerrados en el mismo slice (no eran parte del pedido original, pero
directamente servían "portal ampliado" = discoverability):**
1. Los hubs del portal (`guardian_students#show`, home del estudiante) enlazaban Boletines/Tareas/
   Estado de cuenta, pero NUNCA Calendario ni Actividades — ambos construidos en v1.27.0 sin cablear
   su link desde el hub. Un olvido de nav de ese slice, no una decisión documentada en ningún lado.
   Cerrado agregando los tres botones (Asistencia + los dos que faltaban) a ambos hubs.
2. **No existía NINGÚN enlace de cierre de sesión en toda la aplicación** — ni el shell de staff
   (`layouts/application.html.erb`) ni el portal (`layouts/portal.html.erb`) tenían forma de llegar a
   `SessionsController#destroy`, que siempre existió y funcionaba (ruta `DELETE /session`, ya
   protegida — no está en `allow_unauthenticated_access`). `shared/_logout_link` (un `link_to` +
   `data: { turbo_method: :delete }`, mismo idioma que `identity_access/roster_imports#show`) ahora
   vive en ambos layouts, un solo partial. **Deliberadamente NO `button_to`**: un `<form>` en un
   layout compartido aparece en CADA página bajo ese layout — el primer intento con `button_to` rompió
   dos tests preexistentes (`finance_test.rb`/`group_assignments_test.rb`) que aseveran "cero forms"
   en una superficie de solo lectura del portal, sin ningún scope a `main#main`. Corregido cambiando
   la implementación, no los tests preexistentes — el invariante que esos tests protegen (ninguna
   acción de escritura en una vista de solo lectura) sigue vigente; el logout no es una acción del
   dominio de esa página.

**Caso de aceptación, verificado end-to-end:** un acudiente ve solo el historial de su propio hijo
(otro hijo con registro el mismo día nunca aparece), ordenado más-reciente-primero; un hijo fuera de
sus vínculos activos 404 en `/portal/guardian/students/:id/attendance` (mismo gate de relación que
`GuardianStudentsController`); un estudiante ve su propio historial por self-scope; el logout
efectivamente termina la sesión (`DELETE /session` seguido de un request protegido vuelve a
redirigir a login).

**Resultado:** 578 runs / 2425 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
573; 5 tests nuevos: 2 en `attendance_test.rb`, 1 en `authentication_test.rb`, más los dos ajustes en
tests existentes descritos arriba). `bin/rails zeitwerk:check` verde. Sin migraciones — ninguna tabla
nueva, este slice es puramente capa de portal sobre un dominio ya real.

**Archivos nuevos/editados:**
- Query object: `app/domains/attendance/queries/student_view.rb`.
- Controllers: `app/controllers/portals/{guardian,student}_attendance_controller.rb`.
- Rutas: `config/routes.rb` (dos `resource :attendance` nuevos).
- Vistas: `app/views/portals/guardian_attendance/show.html.erb`,
  `app/views/portals/student_attendance/show.html.erb`, `app/views/attendance/_history.html.erb`,
  `app/views/shared/_logout_link.html.erb`.
- Helper: `app/helpers/attendance_helper.rb`.
- Hubs actualizados: `app/views/portals/guardian_students/show.html.erb`,
  `app/views/portals/student_portal/show.html.erb`.
- Layouts: `app/views/layouts/application.html.erb`, `app/views/layouts/portal.html.erb`.
- Tests: `test/integration/attendance_test.rb` (portal), `test/integration/authentication_test.rb`
  (logout) — `finance_test.rb`/`group_assignments_test.rb` NO se tocaron; el `button_to` inicial que
  los rompió se descartó a favor de `link_to`+`turbo_method` antes de tocar ningún test.
- Doc: `PROJECT_STATE.md` (backfill de la fila de dominio `extracurriculars` que faltaba desde
  v1.27.0, además del cierre de este ítem), `OPEN_PROCESS.md` (ítem #13 + tres guardrails nuevos).

### v1.27.0 — 2026-07-16 — `extracurriculars`: actividades + inscripción del acudiente (ítem #8 del MVP)

**Dominio net-new, addon-gated, real desde el día uno (sin fase stub) — mismo molde que `attendance`
(v1.16.0)/`assignments` (v1.21.0+): dos tablas, dos modelos, un query object, tres servicios, cinco
controllers (dos de supervisión + tres de portal), sin over-engineering.** Ítem #8 del camino crítico
del MVP (`LINEAMIENTOS_MVP.md` §4.1/§7). Las dos decisiones abiertas del §9 se cerraron con el owner
ANTES de empezar (ambas vías de inscripción; scope de instructor por propiedad de fila, sin columna
nueva en `role_assignments`); este slice fue implementación disciplinada de ese checkpoint.

**Recon (STOP): sin contradicciones materiales, dos correcciones de suposición.** Verificado contra
disco: (1) el motor de RBAC (`Authorization::Assignment#covers?`+`SCOPE_READERS`, `PermissionCheck`)
modela SOLO jerarquía (`scope_department_id`/`scope_grade_level_id`/`scope_group_id`) — la propiedad
de una sola fila NO es expresable ahí, confirmando que "la actividad del instructor" es un filtro de
identidad por FK en un query object, no un `scope_type` nuevo. (2) `Finance::StudentAccount` NO se crea
de forma perezosa en NINGÚN lado del repo (los controllers de `finance` hacen `find_by`+404; solo los
tests la crean, hardcodeando `"COP"`) — así que una actividad paga hace `find_or_create_by!` de la
cuenta (seguro: `student_accounts` tiene índice único `(institution_id, student_id)`), moneda `"COP"`
por defecto (no hay columna de moneda en `institutions`). (3) `Schedules::ActiveTermEnrollmentScope`
ya declaraba "inscripción a actividades" como consumidor previsto — reusado tal cual para el roster
inscribible de supervisión, sin re-derivar el join de término.

**Diseño construido:**
- Migración `20260716203439_create_extracurriculars.rb`: `activities` (`kind` sport/art/tutoring CHECK,
  `name`, `academic_term_id` NOT NULL + cascade — cierra parte de B2, `capacity` NOT NULL CHECK `>0`,
  `instructor_staff_member_id` nullable + nullify — la actividad precede al instructor, mismo criterio
  que `attendance.recorded_by`, `fee_cents` bigint nullable CHECK `>=0` — dinero NUEVO en `*_cents`
  (F6), NO `decimal` como el `finance` legacy grandfathered, `location`/`schedule_info` texto PROPIO
  (sin depender de `schedules`), `status` draft/published/archived CHECK — mismo ciclo que
  `assignments`) + `activity_enrollments` (`status` active/withdrawn CHECK, `enrolled_at`/`withdrawn_at`,
  `enrolled_via` staff/guardian CHECK, `enrolled_by_user_id` FK `users` nullify — atribución, "quién
  inscribió: colegio vs acudiente", mismo criterio que `submissions.submitted_by_user_id`). RLS
  `ENABLE+FORCE` en ambas. Corrida en dev Y test.
- **Cupo + doble inscripción — dos defensas distintas.** El cupo es un invariante AGREGADO ("nº de
  activos < capacity"), NO expresable barato como constraint declarativo sin un trigger (y este repo no
  usa triggers): se hace cumplir en `Extracurriculars::EnrollmentCreator` con `activity.lock!` + count
  dentro del lock (misma disciplina que `Finance::ChargeCreator`/`PaymentRecorder`). La doble
  inscripción ACTIVA la bloquea un **índice único PARCIAL** `(institution_id, activity_id, student_id)
  WHERE status='active'` (predicado inmutable) — el índice no corre carreras como sí lo haría
  `validates uniqueness`, y el `WHERE status='active'` deja intacto el historial (varias filas withdrawn
  + una active), coherente con "append, nunca destruir".
- Modelos `Activity`/`Enrollment` (labels ES, `fee_amount` = el ÚNICO puente `cents`→`decimal`,
  `BigDecimal(fee_cents)/100`, exacto, sin Float). `EnrollmentCreator` (lock + cupo + fila + Charge de
  actividad paga en la MISMA transacción, idempotente por la fila activa existente + `idempotency_key`
  de `ChargeCreator`), `EnrollmentWithdrawer` (flip suave a withdrawn, NO revierte el Charge — política
  de tesorería diferida), `StudentActivities` (camino de lectura del portal, módulo `module_function`,
  molde `Assignments::StudentView`).
- **RBAC — split manage/instruct por ALCANCE de propiedad, no por confidencialidad.** `activity.manage`
  (coordinador, institución-wide: todo el catálogo + inscribir en cualquiera). `activity.instruct`
  (instructor: piso de acceso a la superficie + roster de las actividades PROPIAS). La propiedad se
  resuelve en `Extracurriculars::ActivityScope` por `instructor_staff_member_id == mi StaffMember#id`
  (WHERE directo en el query, no un `.select`+`covers?` per-fila — misma familia que `TeacherScope`,
  pero el test de "mío" es identidad, no scope de rol). `covers?`/`SCOPE_READERS`/`role_assignments`
  **intactos** (cero cambios de esquema en `role_assignments`, la restricción dura del checkpoint).
- **Nav de un solo permiso, resuelto sembrando el coordinador con AMBOS.** El `Navigation::Registry`
  admite un permiso por tile; se gatea por `activity.instruct` (el piso que ambos roles tienen) y el rol
  `activity_coordinator` se siembra con `activity.manage` Y `activity.instruct` — así una sola tile
  sirve a los dos roles sin duplicarla ni tocar el mecanismo del Registry.
- Controllers de supervisión (`ActivitiesController` catálogo CRUD + publish/archive gate `activity.
  manage`, index/show gate `activity.instruct`; `EnrollmentsController` inscribir/desinscribir, la
  propiedad la hace cumplir `ActivityScope.resolve.find` → 404 fuera de alcance, convención de portal).
  Portal (`Portals::StudentActivities` solo lectura self-scope; `GuardianActivities` lectura per-child;
  `GuardianActivityEnrollments` inscribir/desinscribir en nombre del hijo — doble salto GuardianScope →
  `StudentActivities.enrollable`, sin `authorize!`, fuera de `Navigation::Registry`, exactamente como
  las entregas del acudiente). Index de supervisión: un solo GROUP BY para "inscritos/cupo" (nunca un
  count por-fila — N+1 evitado).
- **Actividad paga = un `Finance::Charge`, jamás un cobro propio.** `EnrollmentCreator` find-or-create
  la cuenta y llama `Finance::ChargeCreator` con `activity.fee_amount` (el puente cents→decimal), reusa
  su `idempotency_key` (hidden field generado una vez en el render, misma convención que todo `finance`).

**Diferido (a propósito):** atribución de la BAJA (solo status + `withdrawn_at`); reversión del Charge
al desinscribir (nota de crédito = política de tesorería); actividades de cupo ilimitado (columna
nullable, no gana su lugar hoy); gate de matrícula-de-término en el flujo del acudiente (el dropdown de
supervisión SÍ usa `ActiveTermEnrollmentScope`, el acudiente inscribe a su propio hijo directo —
asimetría documentada, armonizable después).

**Gotcha operativo (v1.27.0): checkout COMPARTIDO con el slice `calendar` concurrente.** `calendar`
(ítem #7) se construyó en paralelo en el MISMO working tree (no worktrees aislados), tocando archivos
compartidos (`config/routes.rb`, `addon_catalog.rb`, `seed_permissions.rb`, `db/structure.sql`, los
docs) y ambos numerados v1.27.0. El commit de código de `extracurriculars` se mantuvo limpio staged
SOLO sus propios hunks/archivos (verificado con `git show --stat`); las ediciones de doc en conflicto
(cabecera del roadmap, entrada de HISTORIA) NO se pueden fusionar coherentemente en un working tree
compartido — se reconcilian en el MERGE de `feature/extracurriculars` + `feature/calendar`, no
capándolas en disco. Recordatorio: dos slices concurrentes necesitan worktrees/branches aislados desde
el inicio, no el mismo checkout.

### v1.26.0 — 2026-07-16 — `assignments`: rúbricas, slice 4/4 (ítem #6 del MVP) — CIERRA el track

**Biblioteca de rúbricas reutilizables del docente + asociarlas a una tarea + calificar por rúbrica
(individual y grupal), con la nota siempre traducida a `schedules::Assessment`.** Cierra el track
completo de `assignments` (publicar/calificar directo · entrega de texto · entregas grupales ·
adjuntos de entrega · materiales del docente · rúbricas). Fuera de alcance: nada de adjuntos; no se
toca el fan-out ni el emparejamiento entrega↔nota.

**Recon: sin contradicciones materiales.** Confirmado contra disco: `assignment.manage` sigue siendo
el único permiso de autoría/calificación — se reusó directamente, sin permiso nuevo (misma
conclusión que v1.25.0). `Assignments::GradeRecorder`/`GroupGrader` (v1.21.0/v1.23.0) tienen
exactamente la firma esperada — la rúbrica los llama tal cual, nunca los reimplementa.
`Assignment#lock_group_work_after_publish` (v1.23.0) fue el molde EXACTO copiado para el nuevo
`lock_evaluation_method_after_publish`. El precedente de snapshot jsonb inmutable
(`ControlPlane::Subscription#price_tiers_snapshot`/`ReportCards#lines_snapshot`) se siguió al pie de
la letra para `Assignment#rubric_snapshot`. `StudentView.for(student)` filtra por `Assignment.
published` — confirma (de nuevo, como en v1.25.0) que un borrador Y una tarea archivada quedan fuera
del scope del portal por igual, así que el desglose de rúbrica de ambos es inalcanzable gratis.

**Diseño: plantilla en tablas normalizadas, snapshot en jsonb.** El lean explícito del prompt se
confirmó correcto: `assignments` no tenía ningún precedente de jsonb propio, pero el patrón de
snapshot-congelado-en-jsonb YA es idiomático en la casa (control_plane, report_cards) para
"estructura editable en vivo + congelada al momento crítico" — encaja perfecto para "plantilla viva
editable, tarea publicada inmutable". La plantilla en sí (`RubricTemplate`/`RubricCriterion`/
`RubricLevel`/`RubricCellDescriptor`) son tablas normalizadas tenant-scoped (RLS `ENABLE+FORCE`,
editable/greppable) — el snapshot (`Assignment#rubric_snapshot`, jsonb) es un array-de-hashes con
IDs propios congelados, construido por `RubricTemplate#snapshot`, el ÚNICO momento en que la
plantilla viva se lee para fines de calificación (`Assignments::Publisher`, al publicar).

**La evaluación (qué nivel se marcó por criterio) es dato del dominio, la nota NUNCA se guarda ahí.**
`Assignments::RubricEvaluation` (nueva tabla) — estudiante **XOR** grupo, mismo patrón `CHECK
(num_nonnulls(...) = 1)` que `Assignments::Submission` (v1.23.0) — guarda `levels_by_criterion`
(jsonb, criterio_snapshot_id → nivel_snapshot_id, keyed contra el snapshot CONGELADO, nunca la
plantilla viva). `Assignments::RubricScore` (cálculo puro, sin escritura) computa `(Σ puntos_nivel ×
peso) / (Σ puntos_máx × peso) × 5.0`, redondeado a 1 decimal — pesos relativos, la fórmula es una
razón, nunca necesitan sumar 100. `Assignments::RubricGrader`/`GroupRubricGrader` (servicios nuevos)
upsertan la evaluación y LUEGO escriben la nota vía `GradeRecorder`/`GroupGrader` — sin cambios —
exactamente como una nota directa. Un criterio sin nivel marcado hace la evaluación `:incomplete` —
nunca un cero fantasma.

**Toggle + freeze, mismo molde que `group_work` (v1.23.0).** `evaluation_method` (`direct`/`rubric`)
y `rubric_template_id` son settable SOLO en `draft`; `Assignment#lock_evaluation_method_after_publish`
(`before_validation`, defensa en profundidad en el MODELO) descarta cualquier cambio una vez
publicada, sin importar qué action lo intentó. El fan-out de `Publisher` (v1.21.0) es IDÉNTICO con o
sin rúbrica — cada estudiante sigue recibiendo su `Assessment` con `score: nil`; la rúbrica solo
cambia CÓMO se llena ese score, nunca el mecanismo de fan-out. Antes de publicar, la grilla de
preview lee la plantilla VIVA (`RubricTemplate#snapshot`, el mismo builder que congela — nunca una
segunda implementación); publicada, lee SOLO el snapshot congelado.

**Vistas — la grilla de calificación es la única pieza con JS real de este slice.** Biblioteca
(`Assignments::RubricTemplatesController`, RBAC como CAPABILITY check — sin `resource`, porque una
rúbrica es reutilizable por el docente en cualquier materia, no scopeada a una — ver el docstring de
`Authorization::Assignment#covers?`; visibilidad author-owned aplicada en el controller, nunca
`default_scope`). Agregar/quitar criterios y niveles es server-round-trip simple (mismo "sin Stimulus
para listas dinámicas" que el resto de la casa — ningún controller Stimulus existente en este repo
maneja nested-attributes-con-JS, así que un builder cliente-side habría sido la primera abstracción
de su tipo sin precedente real que lo respalde); los descriptores se guardan en UN bulk-save (mismo
patrón "hash anidado en un solo POST" que `#grade` ya usa para `scores`/`group_scores`). La grilla de
CALIFICACIÓN sí es interactiva (`rubric_grid_controller.js`, nuevo): tocar un nivel por criterio
recalcula la nota en vivo, cero round-trips por clic — display-only, el servidor
(`Assignments::RubricScore`) sigue siendo la única fuente de verdad para lo que persiste. Portal
(`Assignments::StudentView.rubric_breakdown_for`, nuevo): estudiante/acudiente ven, por criterio, el
nivel obtenido y su descriptor — la transparencia que responde "por qué Bueno y no Excelente" —
leído SOLO del snapshot congelado + la evaluación, nunca la plantilla viva.

**Caso de aceptación, verificado end-to-end:** calificar por rúbrica calcula la nota correcta a 1
decimal (verificado con combinaciones de pesos que no suman 100) y la escribe SOLO en `Assessment`
(cero duplicados tras re-calificar); una evaluación incompleta no escribe nota; evaluar un grupo hace
bulk-set a cada integrante, un override individual sobrevive hasta que se re-aplica la grupal
(reseteando a todos, incluido el override — mismo comportamiento que v1.23.0); `evaluation_method`/
`rubric_template_id` quedan bloqueados tras publicar (verificado a nivel de MODELO, no solo vista);
editar la plantilla-biblioteca (renombrar un criterio, cambiar su peso, agregar uno nuevo) después de
publicar NUNCA toca el snapshot ya congelado de una tarea existente — verificado comparando el
snapshot byte a byte antes/después de la edición; un acudiente ve nivel + descriptor por criterio de
la tarea de su hijo; una tarea en `draft` es 404 para el portal, sin ningún chequeo extra; aislamiento
cross-tenant de plantillas/evaluaciones verificado con RLS real; las páginas de gestión (biblioteca,
grilla de calificación individual/grupal, preview de borrador, formulario de tarea con el picker de
plantilla) se verificaron con requests reales, no solo lógica de servicio.

**Incidente operativo durante el slice, no de producto:** un `bin/rails runner` de depuración
(usado para diagnosticar un `institution must exist` real en `RubricCriteriaController`/
`RubricLevelsController` — faltaba pasar `institution:` al crear vía la asociación anidada) dejó un
`Core::User`/`Core::Institution` COMMITTED en la base de datos de test (el script no estaba envuelto
en una transacción que revirtiera). Esto rompió dos tests preexistentes y no relacionados
(`RosterImportsGuardiansTest`, `Core::RosterImport::Strategies::GuardiansTest`) que asumen conteos
GLOBALES en cero — se detectó por la corrida completa de la suite, se limpiaron las filas huérfanas,
y ambos tests volvieron a pasar. Lección operativa: cualquier `bin/rails runner` de depuración contra
`RAILS_ENV=test` que cree datos debe envolver TODO en una transacción con rollback explícito, nunca
asumir que el proceso deja el estado limpio por sí solo. Un segundo hallazgo real (no operativo):
la migración original de `rubric_cell_descriptors` no tenía ningún índice liderado por
`institution_id` — lo detectó `TenantRlsGuardTest` (el guardia automático de este invariante),
corregido antes de cerrar el slice.

**Resultado:** 540 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 528; 12 tests nuevos
en `test/integration/rubrics_test.rb`, sin fixtures binarios nuevos). `bin/rails zeitwerk:check`
verde. Dos migraciones, aplicadas en dev y test.

**Archivos nuevos/editados:**
- Migraciones: `db/migrate/20260716151743_create_rubric_templates.rb`,
  `db/migrate/20260716151744_add_rubric_grading_to_assignments.rb`.
- Modelos: `app/domains/assignments/models/rubric_{template,criterion,level,cell_descriptor,
  evaluation}.rb` (+ edits a `assignment.rb` — evaluation_method/rubric_template/rubric_snapshot/
  lock_evaluation_method_after_publish —).
- Servicios: `app/domains/assignments/services/{rubric_score,rubric_grader,group_rubric_grader,
  attachment_type_check}.rb` — este último ya existía (v1.25.0), sin cambios — (+ edits a
  `publisher.rb` — congela el snapshot al publicar — y `student_view.rb` — `rubric_breakdown_for`).
- Controllers: `app/controllers/assignments/rubric_{templates,criteria,levels,cell_descriptors}
  _controller.rb` (+ edit a `assignments_controller.rb` — picker de plantilla, branch de `#grade`).
- Vistas: `app/views/assignments/rubric_templates/{index,new,edit}.html.erb`,
  `app/views/assignments/_rubric_{grid,structure_preview,breakdown}.html.erb` (+ edits a
  `assignments/assignments/{show,_form}.html.erb`,
  `app/views/portals/{student,guardian}_assignments/show.html.erb`).
- JS: `app/javascript/controllers/rubric_grid_controller.js` (nuevo, único con interactividad real).
- Config: `config/routes.rb`, `config/navigation/assignments.rb` (entrada nueva "Rúbricas").
- Proceso: `OPEN_PROCESS.md` (guardrail nuevo; cierre del ítem 11 — track `assignments` COMPLETO).
- Tests: `test/integration/rubrics_test.rb`.

### v1.25.0 — 2026-07-16 — `assignments`: materiales del docente, slice 3b/4 (ítem #6 del MVP)

**Adjuntar/quitar/listar/servir materiales (docx/pdf/jpg/png, ≤10 MB, ≤10 por tarea) colgados de una
`Assignment` existente.** Es el espejo de v1.24.0 (adjuntos de ENTREGA) pero con dueño distinto —
`Assignment`, no `Submission` — y, sobre todo, una puerta de escritura distinta: RBAC del docente
(`assignment.manage`), nunca una relación de portal. Fuera de alcance: rúbricas (slice 4); ningún
cambio a los adjuntos de entrega ni al fan-out de notas.

**Recon: sin contradicciones materiales esta vez** (a diferencia de v1.24.0, donde Active Storage ya
estaba instalado contra la premisa del prompt). Confirmado contra disco: `assignment.manage` es el
ÚNICO permiso que gatea crear/editar/publicar/archivar/calificar una tarea (`seed_permissions.rb`) —
sin ningún split fino de autoría; se reusó directamente, sin inventar un permiso nuevo.
`Assignments::StudentView.for(student)` filtra por el scope `Assignment.published` (`status:
"published"`) — confirma que un borrador (Y, hallazgo adicional no pedido explícitamente por el
prompt, una tarea ARCHIVADA también) desaparece por completo de ese scope, así que la visibilidad de
materiales para estudiante/acudiente en esos dos estados cae gratis, sin ningún chequeo aparte —
`#show` del portal ya 404 antes de llegar a resolver ningún material. `GuardianScope` encadenado con
`StudentView.for` (hijo→tarea, dos scopes) ya estaba probado en v1.22.0/v1.24.0; se replicó igual acá
para el nuevo `GuardianMaterialsController`.

**Diseño: mismo molde de tabla puente que v1.24.0, dueño distinto.** `Assignments::Material` es la
tabla puente tenant-scoped (RLS `ENABLE+FORCE`) — igual razón que `SubmissionAttachment`: las tablas
crudas de Active Storage no tienen `institution_id`/RLS, así que el límite de tenant lo sostiene esta
fila, nunca las tablas de Rails (guardrail v1.24.0, no reabierto). Nombre elegido: `Assignments::
Material` (lenguaje de dominio — "materiales del docente"), tabla `assignment_materials` (prefijo por
el DUEÑO, mismo patrón que `submission_attachments`/`submission_groups`/`group_memberships` — el
namespace del dominio nunca se repite en el nombre de tabla, el dueño sí).

**Un service hermano, no un dueño polimórfico — pero con un helper compartido de verdad.** Se creó
`Assignments::MaterialAdder`, sibling de `Assignments::AttachmentAdder`, en vez de generalizar este
último a un dueño polimórfico — cada uno tiene su propio cupo (10 vs. 5) y su propia asociación de
dueño, y forzar un dueño genérico habría costado más indirección de la que ahorra. Lo que SÍ es
idéntico byte a byte entre los dos — el chequeo de tipo real (Marcel) + purga-y-destroy si es
inválido, y el chequeo de tamaño — se extrajo a `Assignments::AttachmentTypeCheck` (módulo nuevo,
`services/`), y `AttachmentAdder` (v1.24.0) se refactorizó para usarlo también — evita que las dos
copias de esa lógica diverjan con el tiempo. Verificado sin regresión: la suite completa de
`attachments_test.rb`/`submissions_test.rb`/`group_assignments_test.rb` sigue en verde tras el
refactor.

**La diferencia real de este slice: RBAC en vez de relación.** El docente adjunta/quita desde
`Assignments::MaterialsController` (nested bajo `assignments::subjects::assignments`, mismo
`authorize!("assignment.manage", @subject)` que ya gatea el resto del namespace) — un actor sin ese
permiso recibe **403** (el gate RBAC), nunca el 404 de relación que usan los portales. Permitido
mientras `draft`/`published`; bloqueado en `archived` (mismo principio "archivado = congelado" que
v1.24.0) — y, a diferencia de `report_cards`, agregar un material DESPUÉS de publicar es normal y
esperado (un recurso aclaratorio), no rompe ningún snapshot congelado; los estudiantes ven la lista
viva. `attached_by_user_id` = el docente (`Current.user`) que subió, atribución únicamente.

**Serving: tres controllers, mismo `AttachmentServing` compartido.** `Assignments::
MaterialsController#show` (docente, RBAC), `Portals::StudentMaterialsController#show` y
`Portals::GuardianMaterialsController#show` (ambos read-only — el docente escribe, el portal solo
sirve). Los tres reusan el concern `AttachmentServing` de v1.24.0 — renombrado `send_submission_
attachment` → `send_attachable_file` porque ahora sirve DOS tipos de dueño (`SubmissionAttachment` Y
`Material`), y el mensaje de error de `:too_many` se generalizó (ya no menciona "5" ni "por entrega"
en el texto — cada Adder tiene su propio cupo). Ninguno de los tres usa las rutas firmadas default de
Active Storage. Disposition idéntica a v1.24.0: docx = descarga, pdf/jpg/png = inline.

**Caso de aceptación, verificado end-to-end:** un docente adjunta docx/pdf/jpg/png a la tarea y él
mismo, el estudiante y el acudiente los ven con la disposition correcta; un acudiente ve el material
de la tarea de su hijo por los dos scopes encadenados; un material en una tarea `draft` es 404 para
el estudiante — tras publicar, 200, sin ningún cambio de código entre ambos momentos (la visibilidad
la resuelve `StudentView.for` solo); un archivo renombrado con firma mágica que contradice la
extensión se rechaza por el tipo REAL y purga el blob; el 11.º material se rechaza manteniendo el
cupo en 10; un archivo de 11MB se rechaza antes de tocar disco; un actor sin `assignment.manage`
recibe 403 al intentar adjuntar (nunca 404); adjuntar en una tarea `archived` se bloquea; un material
sembrado en otra institución nunca se filtra ni por la ruta del docente ni por la del portal del
estudiante (aislamiento cross-tenant, RLS real).

**Resultado:** 528 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 519; 9 tests nuevos
en `test/integration/materials_test.rb`, reusando los fixtures binarios de v1.24.0). `bin/rails
zeitwerk:check` verde. Una migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260716143401_create_assignment_materials.rb`.
- Modelos: `app/domains/assignments/models/material.rb` (+ edits a `assignment.rb` — `has_many
  :materials` —, `submission_attachment.rb` — referencia las constantes compartidas en vez de
  redefinirlas).
- Servicios: `app/domains/assignments/services/material_adder.rb`,
  `app/domains/assignments/services/attachment_type_check.rb` (nuevo, compartido) (+ edit a
  `attachment_adder.rb` para reusarlo).
- Controllers: `app/controllers/assignments/materials_controller.rb`,
  `app/controllers/portals/{student,guardian}_materials_controller.rb` (+ edit a
  `app/controllers/concerns/attachment_serving.rb` — rename genérico + mensaje de error
  generalizado —, y a `app/controllers/assignments/attachments_controller.rb`/`app/controllers/
  portals/{student,guardian}_attachments_controller.rb` por el rename).
- Vistas: `app/views/assignments/_materials_list.html.erb` (portal, compartido, read-only) (+ edits
  a `assignments/assignments/show.html.erb` — lista + formulario de subida —,
  `app/views/portals/{student,guardian}_assignments/show.html.erb` — render del partial nuevo —,
  y helpers `material_path_for` en ambos controllers de portal).
- Config: `config/routes.rb`.
- Proceso: `OPEN_PROCESS.md` (guardrail nuevo: escritura RBAC vs. lectura por relación en el MISMO
  dominio; cierre del ítem 11 slice 3b — solo queda rúbricas).
- Tests: `test/integration/materials_test.rb` (reusa los fixtures de `test/fixtures/files/` de
  v1.24.0, sin fixtures nuevos).

### v1.24.0 — 2026-07-16 — `assignments`: adjuntos de entrega, slice 3/4 (ítem #6 del MVP)

**Adjuntar/quitar/listar/servir archivos (docx/pdf/jpg/png, ≤10MB, ≤5 por entrega) sobre una
`Assignments::Submission` YA EXISTENTE** (estudiante XOR grupo). Fuera de alcance: materiales del
docente (slice 3b), rúbricas (slice 4), conversión de docx. No toca el fan-out de `Assessment`,
`GradingView`, ni el eje entrega↔nota.

**Recon (STOP #1 — contradicción material con la premisa del prompt):** Active Storage YA ESTABA
instalado desde el primer commit — `active_storage_{blobs,attachments,variant_records}` en
`db/structure.sql`, `config/storage.yml` con servicio `disk` local ya configurado, `config.
active_storage.service` seteado en los tres entornos. El prompt asumía una instalación desde cero;
se reportó el hallazgo y se ajustó el plan: ninguna migración de instalación, solo la tabla puente
y el código de aplicación. Recon también corrigió el nombre real de la tabla FK: `submissions`, no
`assignments_submissions` como asumía el prompt.

**El diseño real: Active Storage como GLOBAL, sin RLS — la tabla puente es el límite de tenant.**
`active_storage_blobs/attachments/variant_records` son tablas de Rails sin `institution_id` y sin
RLS — adjuntar directamente ahí sería una exposición cross-tenant real, no una preferencia de
estilo. Esta razón ya estaba documentada en el docstring de `Core::RosterImportBatch` (evitaba
`has_one_attached` por el mismo motivo) — fue el precedente que validó todo el diseño del slice.
`Assignments::SubmissionAttachment` es la tabla puente tenant-scoped (RLS `ENABLE+FORCE`,
`institution_id` NOT NULL): un blob solo es alcanzable resolviendo primero SU fila, que RLS ya
scopea. Las tablas crudas de Active Storage se dejan exactamente como Rails las entrega — nunca se
les agrega RLS (ver guardrail nuevo en `OPEN_PROCESS.md`).

**Content-type real, sin gemas nuevas:** la validación de tipo usa la detección nativa de Active
Storage (`Marcel::MimeType.for`, basada en magic bytes vía `identify: true` por defecto) — nunca la
extensión del archivo ni el header declarado por el cliente. No se agregó `ActiveStorageValidations`
ni ninguna otra gema — la validación vive en un service object (`Assignments::AttachmentAdder`),
nunca en el modelo. Tamaño se valida ANTES de adjuntar (evita la escritura a disco de un upload
obviamente sobredimensionado); tipo se valida DESPUÉS de adjuntar (la detección de Marcel solo
corre una vez que el blob existe) — un adjunto rechazado se purga de inmediato, nunca queda un blob
huérfano.

**Frontera de servicio: tres controllers, no uno.** El prompt sugería un único
`Assignments::AttachmentsController#show` compartido; se decidió, siguiendo la convención ya
establecida en communication/v1.20.0 ("nunca colapsar distintos caminos de acceso en un
controller"), usar TRES: `Assignments::AttachmentsController` (docente, solo lectura),
`Portals::StudentAttachmentsController` y `Portals::GuardianAttachmentsController` (create/show/
destroy). Los tres comparten SOLO la lógica de streaming genérica vía el concern
`AttachmentServing` — cada uno resuelve su propio scope (StudentView/GuardianScope/roster) de forma
independiente, nunca un `SubmissionAttachment.find` crudo. Ninguno usa las rutas firmadas propias de
Active Storage (`rails_blob_path`/`rails_representation_path`) — el archivo siempre se transmite a
través del controller propio, después de resolver el scope.

**Lo construido:**
- Migración `20260716140030_create_submission_attachments.rb`: tabla `submission_attachments`
  (`institution_id`, `submission_id` FK a `submissions` on_delete cascade, `attached_by_user_id` FK
  a `users` nullable/nullify — atribución únicamente, nunca redefine de quién es el trabajo), RLS
  `ENABLE+FORCE`+policy, índice `(institution_id, submission_id)`. Corrida en dev y test.
- Modelo `Assignments::SubmissionAttachment` (`has_one_attached :file`, `disposition` — docx =
  `attachment`, pdf/jpg/png = `inline`); `Assignments::Submission` gana
  `has_many :submission_attachments, dependent: :destroy`.
- Servicio `Assignments::AttachmentAdder` (tamaño ≤10MB, cupo ≤5 contando existentes, tipo real ∈
  {docx, pdf, jpg, png}, bloqueado solo si la tarea está `archived` — "tardía" sigue siendo un flag
  calculado, nunca un bloqueo).
- Concern `AttachmentServing` (streaming + mapeo de errores, compartido por los tres controllers de
  servicio) + `Assignments::AttachmentsController#show` (docente, RBAC `assignment.manage`),
  `Portals::StudentAttachmentsController` y `Portals::GuardianAttachmentsController`
  (`create`/`show`/`destroy`, misma disciplina de scope encadenado que v1.22.0/v1.23.0 — el gate de
  lectura ES el gate de escritura; para el grupo, la fila `GroupMembership` del PROPIO actor resuelve
  la `Submission` compartida, nunca un `group_id` del request).
- Rutas anidadas bajo la tarea (no bajo un recurso `submission`, que no tiene ruta propia) en las
  tres superficies.
- Vistas: `_submission_form.html.erb` (portal, compartido) gana lista de adjuntos + formulario de
  subida (oculto tras el cupo de 5); `assignments/show.html.erb` (docente) gana enlaces de adjunto
  por fila/grupo vía el partial nuevo `_attachment_links.html.erb`, respetando `disposition`.

**Caso de aceptación, verificado end-to-end:** un estudiante adjunta docx/pdf/jpg/png a su propia
entrega y el docente los ve/descarga con la disposición correcta (docx = descarga, resto = inline);
un archivo renombrado para simular un tipo permitido (bytes reales de GIF con extensión `.pdf`) se
rechaza por el tipo REAL, nunca por el nombre; un tipo prohibido subido honestamente también se
rechaza; el 6.º adjunto (incluso en un resubmit) se rechaza manteniendo el cupo en 5; un archivo de
11MB se rechaza antes de tocar disco; un acudiente adjunta por su hija — la atribución queda en el
acudiente, la propiedad de la entrega sigue siendo de la niña; un acudiente ajeno no puede adjuntar
para un estudiante que no es su hijo (404); un integrante de un grupo adjunta y OTRO integrante ve y
quita el mismo adjunto (misma fila compartida); un adjunto sembrado en otra institución nunca se
filtra ni por la ruta del docente ni por la del portal del estudiante (aislamiento cross-tenant,
verificado con query real bajo RLS, no una relectura de `current_setting()`).

**Fixtures de test reales, no solo bytes de cabecera:** se generaron archivos reales en
`test/fixtures/files/` (`attachment.{docx,pdf,jpg,png,gif}`, `fake.pdf`) — el `.docx` es un ZIP OOXML
válido mínimo (`[Content_Types].xml`/`_rels/.rels`/`word/document.xml`) para que la detección de
Marcel (que busca `PK\x03\x04` + `[Content_Types].xml` + `word/` cerca del inicio del archivo)
lo reconozca de verdad como `application/vnd.openxmlformats-officedocument.wordprocessingml.
document`, no solo por extensión; `fake.pdf` tiene bytes reales de GIF con extensión `.pdf` — Marcel
prioriza la detección por extensión cuando el contenido no tiene una firma mágica clara (texto
plano, por ejemplo), así que el caso de "tipo real distinto del nombre" exige un contenido con firma
mágica propia que contradiga la extensión, no cualquier texto renombrado.

**Resultado:** 519 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 510; 9 tests nuevos
en `test/integration/attachments_test.rb`). `bin/rails zeitwerk:check` verde. Una migración,
aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260716140030_create_submission_attachments.rb`.
- Modelos: `app/domains/assignments/models/submission_attachment.rb` (+ edit a `submission.rb`).
- Servicios: `app/domains/assignments/services/attachment_adder.rb`.
- Controllers: `app/controllers/concerns/attachment_serving.rb`,
  `app/controllers/assignments/attachments_controller.rb`,
  `app/controllers/portals/{student,guardian}_attachments_controller.rb` (+ edits a
  `app/controllers/portals/{student,guardian}_assignments_controller.rb`).
- Vistas: `app/views/assignments/_attachment_links.html.erb` (+ edits a
  `_submission_form.html.erb`, `assignments/assignments/show.html.erb`).
- Config: `config/routes.rb`.
- Proceso: `OPEN_PROCESS.md` (guardrail nuevo sobre Active Storage sin RLS; cierre del ítem 11
  slice 3).
- Tests: `test/integration/attachments_test.rb`; fixtures binarias reales en
  `test/fixtures/files/attachment.{docx,pdf,jpg,png,gif}` y `fake.pdf`.

### v1.23.0 — 2026-07-16 — `assignments`: entregas grupales (ítem #6 del MVP)

**Generaliza el modelo de v1.21.0/v1.22.0** para tareas grupales: el docente marca `group_work` al
crear la tarea (criterio suyo, sin regla por grado), forma grupos tras publicar (el roster es
concreto ahí), cualquier integrante entrega/edita la entrega compartida (acudiente-en-nombre sigue
valiendo, B1), y calificar es una nota por grupo con posibilidad de override individual.

**Recon (STOP #1):** leyó el modelo real de v1.21.0/v1.22.0 completo antes de tocar nada —
`Assignments::Submission` (`(assignment_id, student_id)`, `submitted_by_user_id`),
`Assignments::StudentView`/`GradingView`/`GradeRecorder`/`Publisher`/`Roster` — sin sorpresas
materiales. **Corrección de un supuesto del prompt**: no existe `GroupManagement::Group` en el
esquema — el "grupo de clase"/homeroom real siempre fue `GroupManagement::Section` (confirmado ya
desde slices anteriores de este mismo ciclo). No había, entonces, ninguna colisión de nombres real
que evitar; se usó igual el nombre propuesto (`Assignments::SubmissionGroup`/`GroupMembership`) por
claridad — un dominio de trabajo por-tarea es conceptualmente distinto de un homeroom aunque no
hubiera colisión literal que forzara el nombre.

**El hallazgo que simplificó todo el slice**: el fan-out per-student de `Assignments::Publisher`
(v1.21.0) **no necesita ningún cambio**. Publicar SIEMPRE crea una fila `schedules::Assessment` por
estudiante del roster, sin importar `group_work` — ese mecanismo ya era per-student desde el primer
día. Esto significa que "nota grupal" nunca es un concepto nuevo de almacenamiento: es simplemente
`Assignments::GroupGrader` iterando los integrantes de un grupo y llamando a
`Assignments::GradeRecorder` (ya existente, sin tocar) por cada uno — un bulk-set sobre filas que
YA EXISTÍAN, nunca una tabla de "nota de grupo" nueva. El override individual es, literalmente, la
MISMA llamada a `GradeRecorder` que ya existía para tareas individuales — cero código nuevo para esa
parte.

**Generalización de `Submission` — el otro punto de diseño real:** se siguió el patrón exacto que
`conversation_participants` (v1.20.0) ya estableció para "identidad A o identidad B, nunca
ambas/ninguna": `student_id` se volvió nullable, se agregó `submission_group_id`, y un CHECK real
`num_nonnulls(student_id, submission_group_id) = 1`. Una sutileza que HABRÍA sido un bug si no se
hubiera notado en recon: las validaciones `uniqueness` de Rails, a diferencia del índice único de
Postgres, tratan por defecto DOS valores `NULL` como "iguales" (colisión) al validar un scope —
sin `allow_nil: true` explícito en ambas validaciones (`student_id`/`submission_group_id`), la
SEGUNDA entrega grupal de cualquier tarea habría sido rechazada por el modelo con un falso "ya
existe", aunque la BD la hubiera aceptado sin problema. Corregido antes de que apareciera como un
bug real en tests.

**Lo construido:**
- Migración `20260716131320_add_group_work_and_submission_groups.rb`: `assignments.group_work`
  (boolean, default false); tablas nuevas `submission_groups`/`group_memberships` (RLS
  `ENABLE+FORCE`+policy, único `(institution_id, assignment_id, student_id)` en memberships —
  un estudiante en ≤1 grupo POR TAREA); generalización de `submissions` (`student_id` nullable,
  `submission_group_id` nuevo, CHECK XOR, índice único adicional `(institution_id, assignment_id,
  submission_group_id)` — Postgres no colisiona múltiples NULL, así que ambos índices únicos
  coexisten sin conflicto). Corrida en dev y test.
- Modelos `Assignments::SubmissionGroup` (`has_many :students, through: :group_memberships`,
  `has_one :submission`), `Assignments::GroupMembership`; `Assignments::Submission` generalizado
  (XOR + `allow_nil`); `Assignments::Assignment` gana `group_work?` y el
  `before_validation :lock_group_work_after_publish` (descarta cualquier cambio a `group_work` una
  vez `published`/`archived`, sin importar qué action lo intente — defensa en profundidad, no solo
  omitir el checkbox en la vista de edición).
- `Assignments::GroupGrader` (bulk-set reusando `GradeRecorder` por integrante).
  `Assignments::GradingView`/`StudentView` generalizados: `GradingView::Row` gana
  `submission_group`; `StudentView.submission_for` resuelve individual o grupal según
  `assignment.group_work?`; `StudentView.group_for` nuevo (nil = sin grupo asignado todavía, empty
  state, nunca error). `Assignments::SubmissionRecorder` generalizado: para una tarea grupal,
  resuelve el `SubmissionGroup` del ACTOR vía su propia `GroupMembership` — nunca acepta un
  `group_id` del cliente, lo que garantiza que dos integrantes distintos siempre converjan en la
  MISMA fila sin ninguna verificación extra.
- `Assignments::SubmissionGroupsController#create` (nested bajo la tarea, RBAC
  `assignment.manage`) — forma un grupo desde estudiantes del roster aún sin grupo. Sin
  `#destroy`/`#update` este slice (corregir una formación de grupos es un caso de uso separado, no
  pedido explícitamente).
- `AssignmentsController#show` extendido (`@groups`/`@unassigned` cuando `group_work?` y
  publicada); `#grade` acepta `group_scores` (bulk-set, aplicado PRIMERO) además de `scores`
  (override individual, aplicado DESPUÉS — así un submit que llena ambos en el mismo request deja
  ganar al override, coherente con "calificar grupo... el docente puede luego modificar la nota de
  un integrante").
- Vistas: formulario de tarea con el toggle `group_work` (solo visible/efectivo en `draft`); vista
  de calificación extendida con sección "Grupos" (miembros + entrega compartida) y notas grupales
  bulk-set; portal (`_group_aware_submission` compartido entre estudiante y acudiente) con el
  empty state de "sin grupo todavía" antes del formulario de entrega.

**Caso de aceptación, verificado end-to-end:** el docente marca `group_work`, publica, y forma un
grupo — cada estudiante queda en exactamente un grupo (el único lo garantiza); un integrante
entrega y OTRO integrante ve esa MISMA entrega y la edita (una sola fila, verificado por conteo);
un acudiente entrega en nombre de un integrante — mismo grupo, misma fila; una nota grupal deja la
MISMA nota en el `Assessment` de cada integrante; un override individual cambia SOLO esa fila;
re-aplicar la nota grupal re-setea a TODOS, incluido el que tenía override; un estudiante sin grupo
ve el empty state y un intento de entrega da 404 (nunca 500); un estudiante de OTRO grupo de la
misma tarea no puede tocar una entrega ajena (su propio POST siempre resuelve a SU grupo, nunca al
otro); `group_work` intentado cambiar después de publicar no tiene ningún efecto; el CHECK de la BD
rechaza tanto "ninguna identidad" como "ambas identidades" (SQL crudo, no solo el modelo); una tarea
individual (`group_work: false`) sigue funcionando exactamente como v1.22.0 (test de regresión
dedicado); aislamiento cross-tenant verificado con query real bajo RLS.

**Decisión explícita, no un olvido:** `db/seeds.rb` NO se tocó — mismo alcance que las cinco slices
anteriores del ciclo (el archivo sigue sin ningún concepto de `institution_users`/`Assignments::*`).

**Resultado:** 510 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 499; 11 tests
nuevos, todos en `test/integration/group_assignments_test.rb`). `bin/rails zeitwerk:check` verde.
Una migración, aplicada en dev y test.

**Nota operativa, no de producto:** al arrancar este slice, `bin/rails generate` falló porque
`image_processing`/`selenium-webdriver` (ya declaradas en `Gemfile`/`Gemfile.lock`, sin relación con
este trabajo) no estaban instaladas localmente — un `bundle install` las restauró. No fue un cambio
de dependencias, solo materializar lo que ya estaba fijado.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260716131320_add_group_work_and_submission_groups.rb`.
- Modelos: `app/domains/assignments/models/{submission_group,group_membership}.rb` (+ edits a
  `submission.rb`, `assignment.rb`).
- Servicios: `app/domains/assignments/services/group_grader.rb` (+ edits a `grading_view.rb`,
  `student_view.rb`, `submission_recorder.rb`).
- Controllers: `app/controllers/assignments/submission_groups_controller.rb` (+ edits a
  `assignments_controller.rb`, `app/controllers/portals/{student,guardian}_assignments_controller.rb`).
- Vistas: `app/views/assignments/_group_aware_submission.html.erb` (compartido) (+ edits a
  `_form.html.erb`, `assignments/show.html.erb`,
  `app/views/portals/{student,guardian}_assignments/show.html.erb`).
- Config: `config/routes.rb`.
- Proceso: `OPEN_PROCESS.md` (backlog + guardrails nuevos).
- Tests: `test/integration/group_assignments_test.rb`.

### v1.22.0 — 2026-07-15 — `assignments`: entrega de texto, slice 2/4 (ítem #6 del MVP)

**Slice 2 de 4 de `assignments`.** Sobre la base de v1.21.0 (publicar + ver + calificar directo):
el estudiante entrega una respuesta de texto a una tarea publicada; el docente la ve junto a la
nota. Entrega también por el acudiente en nombre del hijo (B1: un menor de K-12 sin login no podría
entregar de otro modo). Solo texto — sin adjuntos (slice 3) ni rúbrica (slice 4).

**Recon (STOP #1):** confirmó el modelo real de v1.21.0 sin ninguna sorpresa material —
`assignments.status` ∈ draft/published/archived; el fan-out (`assessments.assignment_id`, una fila
por matrícula con `score: nil` al publicar); el roster de tres capas
(`Roster.for_subject`); el camino estudiante→matrícula→assessment→assignment ya resuelto por
`Assignments::StudentView.for(student)` (exactamente "las tareas publicadas de las materias en las
que el estudiante está matriculado en el término activo"); la superficie de portal (`Portals::
Student/GuardianAssignmentsController`, solo lectura hasta ahora); la superficie de calificación del
docente (`AssignmentsController#show`, con `@roster`/`@scores` separados — se refactorizó a un
único `Assignments::GradingView`).

**Decisión de la llave de la entrega — el prompt dejaba la puerta abierta a anclarla al
`assessment_id` fanned-out; se confirmó el default (llave en-dominio).** Anclar a `assessment_id`
habría acoplado `submissions`→`schedules` en un eje que no hace falta: la fila `Assessment` de un
estudiante para una tarea es un detalle de implementación del gradebook (existe SOLO porque
`Assignments::Publisher` la fanned-out), no algo que `submissions` debería conocer o depender de.
La llave en-dominio `(assignment_id, student_id)` es más limpia y sigue el mismo principio que ya
guio a `report_cards`/`finance`: un servicio de lectura (`Assignments::GradingView`, mismo espíritu
que `Finance::AccountStatement`) empareja roster+nota+entrega en un solo lugar, nunca un FK cruzado
en el esquema.

**Lo construido:**
- Migración `20260715203148_create_submissions.rb`: `assignment_id`/`student_id` (único compuesto
  `institution_id`-leading — una entrega por estudiante por tarea, last-write-wins, sin historial),
  `body` (text), `submitted_by_user_id` (nullable+nullify, atribución — nunca la identidad
  propietaria, que es siempre `student_id`), `submitted_at`. RLS `ENABLE+FORCE`+policy. Corrida en
  dev y test.
- Modelo `Assignments::Submission` (`#late?`, flag calculado comparando `submitted_at` contra
  `assignment.due_date` — nunca un bloqueo).
- `Assignments::SubmissionRecorder` (upsert `find_or_initialize_by` sobre el único compuesto —
  confía en que el caller ya resolvió `assignment` a través del scope correcto, misma división de
  responsabilidad que `Communication::MessageSender`/`ConversationComposer`).
- `Assignments::StudentView` gana `submission_for` (junto al `score_for` ya existente).
- `Assignments::GradingView` nuevo — el servicio de lectura que pareó roster+assessment+submission
  para la vista del docente, reemplazando los `@roster`/`@scores` sueltos que `AssignmentsController
  #show` armaba antes.
- **El PRIMER write desde un portal en todo el proyecto**: `Portals::StudentSubmissionsController`/
  `GuardianSubmissionsController#create`. El gate es exactamente el mismo query object que ya
  acotaba la LECTURA (`Assignments::StudentView.for(student)`) — nunca `authorize!`, nunca un
  permiso nuevo. Un acudiente resuelve primero al hijo por `GuardianScope` (nunca confía en
  `params[:student_id]` crudo) y LUEGO resuelve la tarea por `StudentView.for(ese hijo)` — dos
  scopes encadenados, la tarea de otro hijo o de otro estudiante 404 en ambos pasos.
- Vistas de portal (`#show` nuevo en ambos `Portals::*AssignmentsController`, formulario de entrega
  compartido `assignments/_submission_form`) y la vista del docente actualizada para mostrar la
  entrega (truncada) + badge "tardía" junto al input de nota.

**Caso de aceptación, verificado end-to-end:** un estudiante entrega texto en su tarea publicada y
el docente la ve en la MISMA vista de calificar; un acudiente entrega en nombre de su hijo —
`submitted_by_user_id` registra al acudiente, `student_id` sigue siendo el hijo; un estudiante NO
puede entregar en una tarea de una materia en la que no está matriculado (404, no 403 — la tarea
simplemente no existe en su scope); un acudiente NO puede entregar por un no-hijo (404); reenviar
actualiza la MISMA fila (verificado por conteo, nunca 2); entregar en un `draft` o un `archived` da
404 (ninguno de los dos aparece en `StudentView.for`); una entrega después de `due_date` se acepta
y se marca tardía, nunca se bloquea; calificar sin entrega funciona igual que siempre, y entregar
nunca mueve la nota ya registrada (los dos ejes verificados independientes en el mismo test); sin
campo de adjunto en el formulario; sin entitlement de `assignments`, el portal SIGUE aceptando la
entrega (mismo gap ya aceptado — `Portals::*` nunca chequea entitlement); aislamiento cross-tenant
verificado con query real bajo RLS.

**Hallazgo de proceso, no de producto:** el primer intento de dos tests fallaba porque, tras hacer
`sign_in_as(student_user, ...)` para probar el portal, el test seguía usando `as_teacher` (que solo
edita los `RoleAssignment` de `@user`) asumiendo que la sesión HTTP también volvía a ser la del
docente — no es así; `with_grants` nunca re-autentica. Corregido re-logueando explícitamente como
`@user` antes de la verificación del lado del docente. Vale como recordatorio para los próximos
slices con superficies staff+portal en el mismo test.

**Decisión explícita, no un olvido:** `db/seeds.rb` NO se tocó — mismo alcance que las cinco slices
anteriores (el archivo es puramente demográfico/académico, sin ningún concepto de
`institution_users`/`Assignments::Assignment`/RBAC).

**Resultado:** 499 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 487; 12 tests
nuevos, todos en `test/integration/submissions_test.rb`). `bin/rails zeitwerk:check` verde. Una
migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260715203148_create_submissions.rb`.
- Modelo: `app/domains/assignments/models/submission.rb`.
- Servicios: `app/domains/assignments/services/submission_recorder.rb`,
  `app/domains/assignments/services/grading_view.rb` (+ edit a
  `app/domains/assignments/services/student_view.rb`).
- Controllers: `app/controllers/portals/student_submissions_controller.rb`,
  `app/controllers/portals/guardian_submissions_controller.rb` (+ edits a
  `app/controllers/portals/{student,guardian}_assignments_controller.rb` para `#show` +
  `app/controllers/assignments/assignments_controller.rb` para usar `GradingView`).
- Vistas: `app/views/assignments/_submission_form.html.erb` (compartido),
  `app/views/portals/{student,guardian}_assignments/show.html.erb` (+ edits a
  `app/views/assignments/_assignment_list.html.erb` y
  `app/views/assignments/assignments/show.html.erb`).
- Config: `config/routes.rb`.
- Tests: `test/integration/submissions_test.rb`.
- Proceso: `OPEN_PROCESS.md` (backlog + guardrails nuevos).

### v1.21.0 — 2026-07-15 — `assignments`: tareas académicas, slice 1/4 (ítem #6 del MVP)

**Ítem #6 del camino crítico de `LINEAMIENTOS_MVP.md`.** El owner definió el ciclo completo de
`assignments` (publicar → ver → entregar texto/adjunto → revisar → calificar directo o por
rúbrica), a construir en ~4 slices. **Este slice es SOLO el #1: publicar + ver + calificar
directo.** El roadmap completo de los slices 2–4 queda registrado en el anexo (§2 abajo), sin
construir nada de eso.

**Recon (STOP #1) — el hallazgo que reescribió el modelo de datos propuesto:**

`grep -riE "assignment" db/migrate/` no devolvió ninguna tabla real — net-new confirmado, y a
diferencia de `finance`/`communication`, **tampoco** había ni entitlement, ni `DOMAIN_KEYS`, ni nav,
ni permisos pre-sembrados: hubo que construir el gating completo, como `attendance`/`report_cards`.

El hallazgo que importó fue sobre `schedules::Assessment`: `belongs_to :enrollment` (NO
`:subject`), y **el `score` vive directamente en esa fila** — no existe ninguna tabla de
"grade-entries" separada; cada `Assessment` YA ES la entrada de nota de UN estudiante (vía su
`Enrollment`, que es estudiante+materia+término). El prompt asumía `assignments.assessment_id`
(FK singular, tarea→un Assessment) — pero eso no puede representar una tarea que aplica a un curso
completo: un roster de 30 estudiantes necesita 30 filas `Assessment`, no una. **Corrección de
diseño**: el FK va en la dirección OPUESTA — `assessments.assignment_id` (nullable, aditivo, mismo
patrón que `enrollments.academic_term_id`, v1.15.0). Una `Assignment` es la PLANTILLA; publicarla
hace *fan-out*: crea una fila `Assessment` por cada matrícula del roster, cada una con `score: nil`
inicialmente — el mismo estado que `report_cards` (v1.17.0) ya trata como "materia sin notas, no
cero". Calificar es un `UPDATE` sobre esa fila ya existente, nunca un `CREATE` paralelo.

Segundo hallazgo, menor: `Schedules::Subject` tiene `grade_level_id` — el mecanismo de scope YA
existente (`Authorization::Assignment::SCOPE_READERS[:grade_level]`) ya cubre recursos `Subject`
sin inventar una dimensión de scope nueva; es el MISMO mecanismo que `Schedules::
GradeEntriesController` ya usaba para `grades.write` (aunque nadie lo había puesto en negro sobre
blanco hasta ahora).

**Matiz sobre `ActiveTermEnrollmentScope` (a diferencia de mensajería, v1.20.0):** aquí SÍ es el
resolver semánticamente correcto — una tarea es para los matriculados en la materia/término, que es
exactamente lo que ese resolver resuelve. La elección de resolver sigue siendo semántica caso por
caso (ver el guardrail correspondiente en `OPEN_PROCESS.md`), no automática por precedente — en
mensajería no aplicaba, aquí sí.

**Lo construido:**
- Migración `20260715195639_create_assignments.rb`: tabla `assignments` (`subject_id`, `title`,
  `instructions`, `due_date`, `status` CHECK draft/published/archived,
  `created_by_institution_user_id` nullable+nullify) + `add_reference :assessments, :assignment`
  (nullable, `on_delete: :nullify`). RLS `ENABLE+FORCE`+policy en `assignments`. Corrida en dev y
  test.
- Modelo `Assignments::Assignment`; `Schedules::Assessment` gana `belongs_to :assignment, optional:
  true`.
- `Assignments::Roster` (tres capas: `ActiveTermEnrollmentScope` ∩ enrollments de ESTA materia en
  el término activo — compuesto explícitamente, el resolver no toma un parámetro de materia).
- `Assignments::Publisher` (fan-out transaccional, idempotente por construcción — solo dispara en
  la transición borrador→publicada).
- `Assignments::GradeRecorder` (`UPDATE` de la fila ya fanned-out — nunca un `CREATE`; localiza la
  fila vía `join(:enrollment).where(assignment_id:, enrollments: { student_id: })`).
- `Assignments::StudentView` (el ÚNICO camino de lectura para el portal — mismo patrón que
  `ReportCards::Computation`/`Communication::Inbox`: una computación, dos superficies).
- `Assignments::SubjectScope` (molde #4, per-row `can?` sobre `Schedules::Subject`).
- Addon-gating completo desde cero: `config/entitlements/assignments.rb`,
  `AddonCatalog::DOMAIN_KEYS`, `SeedCatalog::ADDONS` (`metered: false`), permiso único
  `assignment.manage` (crear/editar/publicar/archivar/calificar — mismo criterio unificado que
  `attendance.record`, sin split como `report_card.view/publish`: no hay una acción "más sensible"
  que lo justifique aquí), `config/navigation/assignments.rb`.
- Supervisión: `Assignments::SubjectsController#index` → `Assignments::AssignmentsController`
  (`index/new/create/edit/update/show/destroy` + `publish`/`archive`/`grade` como member actions —
  grading nunca es un namespace aparte, siempre escribe al ÚNICO gradebook). `#show` renderiza el
  roster con inputs de nota inline (mismo estilo que la toma de asistencia de `attendance`,
  v1.16.0).
- Portal: `Portals::StudentAssignmentsController#index` (self-scope) y `Portals::
  GuardianAssignmentsController#index` (nested per-hijo, mismo criterio que `report_cards`/
  `finance` — contenido sustancial por hijo). Ambos renderizan `assignments/_assignment_list`
  (partial compartido) sobre `Assignments::StudentView`.

**Caso de aceptación, verificado end-to-end:** crear una tarea la deja en `draft` sin ningún
`Assessment` fanned-out; publicarla crea exactamente una fila `Assessment` por estudiante
matriculado en la materia/término activo (ninguna para un estudiante NO matriculado), cada una
`score: nil` — y esa fila ungraded NO rompe `ReportCards::Computation` (contribuye cero líneas,
nunca un cero real); calificar escribe en ESA misma fila (`ReportCards::Computation` la lee
inmediatamente con el valor correcto) y re-calificar actualiza en vez de duplicar; un docente
scopeado a `grade_level_a` gestiona/califica solo materias de ese grado, 403 en materias de otro
grado, y el índice de materias solo muestra las propias; sin `assignment.manage`, 403 y sin tile de
nav; grading antes de publicar es rechazado silenciosamente (no hay fila que actualizar); un
borrador se elimina de verdad, una publicada NUNCA (solo se archiva, y archivar no toca los
`Assessment` ya fanned-out); el portal del estudiante ve la tarea publicada CON su propia nota
(mismo origen que `report_cards`) y nunca ve un borrador; el del acudiente ve solo las de su
propio hijo (404 al adivinar otro); sin entitlement de `assignments`, 403 con "no está habilitado";
aislamiento cross-tenant verificado con query real bajo RLS; `due_date` persiste tal cual
(calendar-forward, sin vista de calendario construida).

**Decisión explícita, no un olvido:** `db/seeds.rb` NO se tocó — mismo alcance que las cuatro
slices anteriores (el archivo es puramente demográfico/académico, sin ningún concepto de
`institution_users`/RBAC/entitlements).

**Resultado:** 487 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 472; 15 tests
nuevos, todos en `test/integration/assignments_test.rb`). `bin/rails zeitwerk:check` verde. Una
migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260715195639_create_assignments.rb`.
- Modelo: `app/domains/assignments/models/assignment.rb` (+ edit a
  `app/domains/schedules/models/assessment.rb`).
- Query object + servicios: `app/domains/assignments/queries/subject_scope.rb`,
  `app/domains/assignments/services/{roster,publisher,grade_recorder,student_view}.rb`.
- Controllers: `app/controllers/assignments/{subjects,assignments}_controller.rb`,
  `app/controllers/portals/{student,guardian}_assignments_controller.rb`.
- Vistas: `app/views/assignments/subjects/index.html.erb`,
  `app/views/assignments/assignments/{index,new,edit,show,_form}.html.erb`,
  `app/views/assignments/_assignment_list.html.erb` (compartido),
  `app/views/portals/{student,guardian}_assignments/index.html.erb` (+ botones nuevos en
  `student_portal/show`/`guardian_students/show`).
- Config: `config/entitlements/assignments.rb`, `config/navigation/assignments.rb`,
  `config/routes.rb`, `app/control_plane/control_plane/addon_catalog.rb`,
  `app/control_plane/control_plane/seed_catalog.rb`.
- Permisos: `app/domains/identity_access/services/seed_permissions.rb`.
- Tests: `test/integration/assignments_test.rb`.
- **Reestructuración editorial**: `OPEN_PROCESS.md` (nuevo — backlog + guardrails movidos desde
  `PROJECT_STATE.md` §11/§12), `PROJECT_STATE.md` (pointer + intro actualizada).

#### Anexo — roadmap completo de `assignments` (slices 2–4, SIN construir)

Registrado aquí tal como lo definió el owner, para que el próximo slice de `assignments` arranque
con el contexto completo — nada de esto existe en el código todavía.

- **Slice 2 — entrega de texto del estudiante.** El estudiante escribe una respuesta de texto sobre
  una tarea `published` desde su portal. Sin diseñar todavía: dónde vive la entrega (¿tabla propia
  `submissions`, o un campo en algo existente?), si hay un estado de entrega (a tiempo/tarde/sin
  entregar) visible para el docente, y si la fecha de entrega real se compara contra `due_date`.
- **Slice 3 — adjuntos** (docx/pdf/jpg/png) + revisión en la app. **Checkpoint de diseño propio,
  obligatorio antes de tocar código** — tres realidades a resolver ahí, no antes:
  1. **Active Storage nunca se ha usado en este repo.** Adoptarlo es una decisión de infraestructura
     nueva (¿qué service usa — disco local en dev, algo real en producción?), no solo "agregar
     `has_one_attached`".
  2. **El serving debe ser tenant-scoped**, nunca la URL pública default de Active Storage (que no
     pasa por RLS ni por ningún gate de la app) — necesita un controller propio que resuelva el
     adjunto a través de `authorize!`/relación antes de servir el blob, mismo espíritu que
     "self-scope"/"RBAC" ya aplican en cualquier otro dato sensible de este repo.
  3. **docx no se renderiza nativo en un navegador** — la app necesita convertir (¿a PDF? ¿a HTML?)
     o limitarse a permitir la descarga sin previsualización. Decidir ahí, no asumir "se muestra
     igual que un PDF".
- **Slice 4 — rúbricas.** Criterios → nota equivalente a la escala 0.0–5.0 que
  `ReportCards::Computation` ya usa. Sin diseñar todavía: si una rúbrica es reusable entre tareas o
  se define por tarea, cómo se pondera cada criterio, y si la nota final calculada desde la rúbrica
  sigue escribiéndose en `schedules::Assessment.score` (consistente con el guardrail de este slice
  1: la nota vive SOLO ahí) o si la rúbrica en sí necesita su propia tabla de criterios+puntajes
  colgando del mismo `Assessment`.

### v1.20.0 — 2026-07-15 — `communication`: mensajería (ítem #5b del MVP, subsistema B, núcleo)

**Ítem #5b del camino crítico de `LINEAMIENTOS_MVP.md`.** Subsistema (B) de `communication`:
mensajería privada tipo correo. Las decisiones de fondo llegaron ya aprobadas en el checkpoint
(modelo multiparte, auditoría confidencial-pero-auditable, auditor = rol de institución, contenido
completo para el auditor, rastro nunca visible a participantes) — las tres preguntas abiertas que
`PROJECT_STATE.md` §8.2 venía registrando desde v1.19.0 quedaron resueltas ahí mismo, no antes.

**Recon (STOP #1):** `grep -riE "conversation|message|participant" db/migrate/` sin resultados
reales (solo coincidencias de nombre en `roster_import_rows`/`announcements`) — confirmado Clase C,
el anexo de §8 solo lo había dibujado. `communication` seguía addon-gated desde v1.19.0 (reusado tal
cual); el nav de anuncios ya existía pero mensajería necesitaba sus propias dos entradas (compose,
auditoría) — la bandeja se queda fuera del registry, mismo criterio que el feed de anuncios.

**Convención de identidad — el hallazgo que fijó el modelo de datos:** `audit_events` guarda
`actor_institution_user_id`; `guardian_students` guarda `guardian_user_id` (FK directa a `users`,
CASCADE, no nullify — es la identidad del vínculo, no un dato de atribución). Un acudiente TAMBIÉN
tiene una fila `institution_users` real (`Core::People::Resolver` la crea siempre, es lo que permite
el login), pero el handle que el resto de la app usa para "esta persona como acudiente" es siempre
el `user_id` global, nunca el `institution_user_id` de esa membresía. Se siguió esa convención:
`conversation_participants`/`messages` usan `institution_user_id` (staff) **XOR**
`guardian_user_id` (acudiente, FK a `users`), con un CHECK real
(`num_nonnulls(institution_user_id, guardian_user_id) = 1`) — verificado que la BD lo rechaza de
verdad insertando SQL crudo que bypasea las validaciones de ActiveRecord, no solo confiando en el
modelo. Las columnas de identidad usan `on_delete: :cascade` (nunca `nullify`) porque una fila sin
ninguna identidad violaría el CHECK — a diferencia de `conversations.created_by_institution_user_id`/
`closed_by_institution_user_id`, que SÍ son atribución opcional y usan `nullify`.

**Ajuste de diseño reportado (no un hallazgo material que detuviera el slice, pero sí una desviación
del molde literal que el prompt sugería):** el selector de destinatarios acotado NO reusa
`Schedules::ActiveTermEnrollmentScope`. Ese resolver responde "¿quién está matriculado por materia
en el término activo?" — una pregunta académica, ajena a "¿de qué estudiantes es responsable este
staff para poder contactar a sus acudientes?". Forzarlo habría excluido, por ejemplo, a un
estudiante recién matriculado sin ninguna materia inscrita todavía. Se preservó la MISMA disciplina
de tres capas (scope RBAC del actor sobre grupos, vía `context.can?` per-row como
`Attendance::GroupScope`/`ReportCards::GroupScope` ∩ estudiantes de esos grupos ∩ acudientes reales
vía `GuardianStudent`), solo que la capa de "hecho crudo" es `GroupManagement::Section#students`
(un hecho de negocio, ya real desde `group_management`), no un resolver académico. Staff, en
cambio, es explícitamente NO acotado (`ComposeRecipients#staff` = todo `institution_user` activo
respaldado por una fila `StaffManagement::StaffMember`, institución-wide) — y ahí surgió un segundo
matiz: "cualquier `institution_user` activo" habría incluido a los acudientes (que también tienen
esa fila), así que la señal correcta es específicamente la presencia de un `StaffMember`, nunca
"tiene cero `role_assignments`" (un staff recién invitado sin rol asignado se vería como acudiente
bajo esa segunda señal).

**Lo construido:**
- Migración `20260715190531_create_conversations_and_messages.rb`: tres tablas, RLS
  `ENABLE+FORCE`+policy en cada una, índices `institution_id`-leading, los dos CHECK de
  exactamente-uno. Corrida en dev y test.
- Modelos `Communication::Conversation` (`#close!`/`#reopen!`, soft), `Communication::
  ConversationParticipant` (`#staff?`/`#guardian?`/`#name`), `Communication::Message`
  (`touch: true` sobre la conversación, para que el ordenamiento de la bandeja por actividad
  reciente salga gratis de Rails).
- `Communication::ComposeRecipients` (destinatarios acotados, tres capas), `Communication::
  ConversationComposer` (transaccional: conversación+participantes+primer mensaje, RE-valida
  destinatarios server-side — un request manipulado que intente agregar un acudiente fuera de
  alcance simplemente lo descarta, verificado con un test dedicado), `Communication::MessageSender`
  (el gate de "responder": participación, nunca `authorize!`; rechaza no-participante o
  conversación cerrada), `Communication::Inbox` (el ÚNICO cómputo de bandeja+no-leídos, compartido
  por el shell de staff y el portal del acudiente — mismo patrón que `AnnouncementFeed`/
  `AccountStatement`/`Computation` de slices anteriores).
- Dos permisos nuevos: `conversation.compose` (iniciar) y `conversation.audit` (auditar, **permiso
  distinto** de compose a propósito — quien puede iniciar no necesariamente puede leer las de
  otros). Acción `conversation_audited` agregada a `IdentityAccess::AuditEventIndex::ACTIONS`
  (primera vez que esa constante recibe una acción escrita desde FUERA de `identity_access` —
  docstring del archivo actualizado para reflejarlo).
- Cuatro controllers, cuatro gates, nunca colapsados: `Communication::ConversationsController`
  (compose, RBAC), `Communication::InboxController` + `Communication::MessagesController`
  (bandeja+responder, participación — staff), `Portals::GuardianInboxController` + `Portals::
  GuardianMessagesController` (mismo, portal del acudiente — sin compose, sin cerrar/reabrir:
  ninguna ruta expone esas acciones para un acudiente, no hay chequeo extra que las bloquee),
  `Communication::ConversationAuditsController` (auditoría, RBAC, log condicional).
- Nav nueva: "Nueva conversación" (`conversation.compose`) y "Auditoría de mensajes"
  (`conversation.audit`) en `config/navigation/communication.rb`. Enlace "Mensajes" nuevo en el
  shell de staff (`shared/_inbox_link.html.erb`, gateado por entitlement, fuera del registry, mismo
  patrón que `_announcements_link.html.erb`) y botón nuevo en el dashboard del acudiente.

**Caso de aceptación, verificado end-to-end:** una conversación de 3 participantes (2 staff + 1
acudiente) — todos ven todos los mensajes; un staff no-participante sin `conversation.audit` no ve
la conversación en su bandeja y recibe 404 al acceder directo (confidencialidad real, no solo
cosmética); la bandeja del staff y la del portal del acudiente devuelven el MISMO set vía
`Communication::Inbox`; el badge de no-leídos refleja `last_read_at`, abrir la conversación lo
actualiza, y el propio mensaje de un participante nunca cuenta como no-leído PARA ÉL (sí para los
demás); cerrar es soft (la fila sobrevive, sale de "activas") y bloquea nuevas respuestas hasta
reabrir; un acudiente fuera del scope RBAC del actor nunca aparece en el selector de destinatarios
aunque se manipule el request; el formulario de composición no tiene ningún buscador; un acudiente
responde en lo suyo pero recibe 403 real al intentar iniciar una conversación; un auditor
GENUINAMENTE ajeno (no el propio creador con el permiso re-otorgado — el test inicial cometió
justo ese error y hubo que corregirlo con un actor real, separado y re-autenticado) que lee una
conversación donde no participa deja un `conversation_audited` real, visible en el visor RBAC-gated
de auditoría; el mismo actor leyendo SU PROPIA conversación (aunque tenga `conversation.audit`) no
loguea nada; el rastro nunca aparece en la bandeja de un participante; el CHECK de la BD rechaza de
verdad una fila sin identidad (SQL crudo, no solo el modelo); `Communication::MessageSender`
rechaza a un no-participante aunque tenga `conversation.audit`; sin entitlement de `communication`,
compose/bandeja/auditoría dan 403 con "no está habilitado"; aislamiento cross-tenant verificado con
query real bajo RLS.

**Decisión explícita, no un olvido:** `db/seeds.rb` NO se tocó — mismo alcance que las cuatro
slices anteriores (`attendance`/`report_cards`/`finance`/`communication` anuncios): el archivo es
puramente demográfico/académico, sin ningún concepto de `institution_users`/RBAC/entitlements.

**Resultado:** 472 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 455; 17 tests
nuevos, todos en `test/integration/messaging_test.rb`). `bin/rails zeitwerk:check` verde. Una
migración (tres tablas), aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260715190531_create_conversations_and_messages.rb`.
- Modelos: `app/domains/communication/models/{conversation,conversation_participant,message}.rb`.
- Query object + servicios: `app/domains/communication/queries/compose_recipients.rb`,
  `app/domains/communication/services/{conversation_composer,message_sender,inbox}.rb`.
- Controllers: `app/controllers/communication/{conversations,inbox,messages,conversation_audits}_controller.rb`,
  `app/controllers/portals/guardian_{inbox,messages}_controller.rb`.
- Vistas: `app/views/communication/conversations/new.html.erb`,
  `app/views/communication/inbox/{index,show}.html.erb`,
  `app/views/communication/conversation_audits/{index,show}.html.erb`,
  `app/views/communication/_message_thread.html.erb` (compartido),
  `app/views/portals/guardian_inbox/{index,show}.html.erb`,
  `app/views/shared/_inbox_link.html.erb` (+ botón nuevo en `guardian_portal/show`, wiring en
  `layouts/application.html.erb`).
- Config: `config/navigation/communication.rb` (dos entradas nuevas), `config/routes.rb`.
- Permisos + auditoría: `app/domains/identity_access/services/seed_permissions.rb`,
  `app/domains/identity_access/services/audit_event_index.rb`.
- Tests: `test/integration/messaging_test.rb`.

### v1.19.0 — 2026-07-15 — `communication`: anuncios (ítem #5 del MVP, subsistema A)

**Ítem #5 del camino crítico de `LINEAMIENTOS_MVP.md`.** `communication` es, en la visión completa,
dos subsistemas: (A) anuncios (difusión de una vía) y (B) mensajería (conversaciones privadas). Este
slice construye SOLO (A) — (B) queda registrada como spec del owner en el anexo (`PROJECT_STATE.md`
§8.2), con sus tres preguntas de diseño abiertas, para su propio slice con su propio checkpoint.

**Recon (STOP #1) — dos hallazgos que corrigieron el plan:**

1. **`communication` YA estaba addon-gated, igual que `finance` (misma lección).**
   `config/entitlements/communication.rb` ya registraba el dominio (con un comentario explícito: "No
   `Communication::` namespace exists yet... this declaration pre-registers the gate"), ya estaba en
   `ControlPlane::AddonCatalog::DOMAIN_KEYS`, y ya tenía una entrada en `ControlPlane::
   SeedCatalog::ADDONS` (`metered: true, unit: "mensajes"` — esa métrica es provisional para la
   FUTURA mensajería, este slice no emite ningún evento de uso). **Diferencia con `finance`:**
   `finance` ya tenía también su entrada en `Navigation::Registry`; `communication` NO — hubo que
   crear `config/navigation/communication.rb` desde cero. Tampoco existían permisos
   `communication.*`/`announcement.*` en el catálogo. Conclusión: cada pieza del gating se verifica
   por separado, nunca se infiere una de la presencia de otra.
2. **`grep -riE "announcement|conversation|message|communication" db/migrate/` no devolvió ninguna
   tabla real** — Clase C confirmado, net-new de verdad (a diferencia de varios recon previos que
   revelaron sorpresas). El borrador de §8 (`PROJECT_STATE.md`) proponía un modelo `conversations`
   unificado con `kind` incluyendo `announcement` — el owner decidió (decisión ya cerrada del
   prompt, §0) que anuncios y mensajería son estructuralmente distintos (difusión sin participantes
   vs. privada con participantes/hilos/estado) y que el modelo de mensajería debe diseñarse fresco en
   su propio slice, no heredar la forma de este borrador viejo. Se creó `announcements` como tabla
   dedicada; §8 se reescribió para reflejarlo.

**Convención de actor:** `audit_events` guarda `actor_institution_user_id` (nullable, `nullify`);
`report_cards` (v1.17.0) usó `published_by_staff_member_id` en su lugar. Para el autor de un anuncio
se siguió la convención de `audit_events` (`author_institution_user_id`) — publicar es una acción
administrativa disponible para cualquiera con el permiso, no una extensión específicamente docente
como la publicación de boletines.

**Lo construido:**
- Migración `20260715155950_create_announcements.rb`: `title`/`body`/`status` (CHECK
  published/retracted, sin estado `draft` — publicar es el acto)/`published_at`/`retracted_at`/
  `author_institution_user_id` (nullable). RLS `ENABLE+FORCE`+policy, índice
  `(institution_id, published_at)`. Corrida en dev y test.
- Modelo `Communication::Announcement` — `#retract!` (soft: `status` + `retracted_at`, nunca
  `destroy`).
- `Communication::AnnouncementScope` (molde #4, institución-wide, para la superficie de gestión) y
  `Communication::AnnouncementFeed` (el ÚNICO camino de lectura — `published`, orden `published_at`
  desc — consumido por staff, portal del acudiente y portal del estudiante por igual).
- Permiso nuevo `announcement.publish` (uno solo, cubre crear/editar/retractar — igual criterio
  unificado que `attendance.record`, a diferencia del split de `report_card.view/publish`: aquí no
  hay una acción "más sensible" que justifique partirlo).
- `config/navigation/communication.rb` (nuevo — no existía). Gestión:
  `Communication::AnnouncementsController#index/new/create/edit/update/retract`,
  `authorize!("announcement.publish")` en cada acción, cualquiera con el permiso gestiona TODOS los
  anuncios de su institución (equipo de comunicaciones pequeño; el autor se guarda para atribución,
  no como límite de edición — decisión reportada, no re-preguntada).
- Lectura por **membresía** (tercer tipo de gate, ver Guardrails): `Communication::FeedController#show`
  (staff, sin `authorize!`, fuera del Registry, enlazado desde el shell vía
  `shared/_announcements_link.html.erb` — mismo patrón que `_self_service_link.html.erb`, pero
  gateado por `Current.entitled_addon_keys.include?("communication")` en vez de ser incondicional).
  `Portals::GuardianAnnouncementsController`/`StudentAnnouncementsController#index` — NO por
  `GuardianScope`/`StudentSelfScope` (un anuncio no es per-hijo/per-self), solo por
  `Current.institution` del usuario del portal. Los tres controllers renderizan el mismo partial
  compartido `communication/_announcement_list`.
- Botones de entrada nuevos en `guardian_portal/show` y `student_portal/show` (el segundo, ahora
  incondicional — a diferencia de "Mis boletines", que sigue condicionado a `@student`, porque leer
  anuncios no depende de tener un registro de estudiante vinculado).

**Caso de aceptación, verificado end-to-end:** un actor con `announcement.publish` crea un anuncio
con atribución de autor real; sin el permiso, 403 en gestión Y sin el tile "Anuncios (gestión)" en el
nav; un staff SIN el permiso, un acudiente (portal) y un estudiante (portal, incluso sin
`GroupManagement::Student` vinculado) ven los anuncios publicados vía el MISMO
`Communication::AnnouncementFeed`; retractar un anuncio lo saca del feed pero la fila sigue existiendo
(`find(id)` no nulo); sin entitlement de `communication`, gestión Y el feed de staff dan 403 con "no
está habilitado" (gate #1 antes que gate #2); **el portal NO chequea entitlement** (mismo gap ya
aceptado de `report_cards`/`finance` — verificado con un test que documenta el comportamiento actual
en vez de asumirlo); aislamiento cross-tenant verificado con query real bajo RLS.

**Decisión explícita, no un olvido:** `db/seeds.rb` NO se tocó — mismo alcance que las tres slices
anteriores (`attendance`/`report_cards`/`finance`): el archivo es puramente demográfico/académico
(no tiene ningún concepto de `institution_users`/RBAC/entitlements), así que sembrar un anuncio de
demo ahí requeriría inventar infraestructura de autor que no encaja con su forma actual.

**Resultado:** 455 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 442; 13 tests
nuevos, todos en `test/integration/communication_test.rb`). `bin/rails zeitwerk:check` verde. Una
migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260715155950_create_announcements.rb`.
- Modelo: `app/domains/communication/models/announcement.rb`.
- Query object + servicio: `app/domains/communication/queries/announcement_scope.rb`,
  `app/domains/communication/services/announcement_feed.rb`.
- Controllers: `app/controllers/communication/announcements_controller.rb`,
  `app/controllers/communication/feed_controller.rb`,
  `app/controllers/portals/guardian_announcements_controller.rb`,
  `app/controllers/portals/student_announcements_controller.rb`.
- Vistas: `app/views/communication/announcements/{index,new,edit,_form}.html.erb`,
  `app/views/communication/feed/show.html.erb`, `app/views/communication/_announcement_list.html.erb`
  (compartido), `app/views/portals/{guardian,student}_announcements/index.html.erb`,
  `app/views/shared/_announcements_link.html.erb` (+ botones nuevos en `guardian_portal/show` y
  `student_portal/show`, wiring en `layouts/application.html.erb`).
- Config: `config/navigation/communication.rb` (nuevo), `config/routes.rb`.
- Permisos: `app/domains/identity_access/services/seed_permissions.rb`.
- Tests: `test/integration/communication_test.rb`.

### v1.18.0 — 2026-07-15 — `finance`: UI de tesorería (ítem #4 del MVP)

**Ítem #4 del camino crítico de `LINEAMIENTOS_MVP.md`.** `finance` es Clase A por modelos
(`Charge`/`Payment`/`PaymentPlan`/`Installment`/`StudentAccount`, reales desde el primer commit)
pero sin ningún controller/ruta/vista — se construye desde cero, no se reemplaza un stub. Tres
decisiones llegaron ya aprobadas: dos superficies (supervisión + estado de cuenta del acudiente);
escritura = registrar pagos/cargos, planes de pago diferidos; y "este slice decide el addon-gating".

**Recon (STOP #1) — tres hallazgos materiales que corrigieron el plan:**

1. **El dinero es `decimal(12,2)`, no `*_cents bigint`** — las cinco tablas usan `t.decimal
   precision: 12, scale: 2` desde `027ec44` (primer commit), anterior a que F6 (cents-bigint) se
   adoptara para el billing del control plane (`ControlPlane::Addon` etc., commits posteriores).
   `decimal`/`BigDecimal` es aritmética exacta en Postgres y en Ruby — no tiene el problema de drift
   de float que F6 existe para prevenir, es solo una representación distinta. El helper `money()` ya
   espera un decimal directo (`number_to_currency(amount, ...)`), confirmando que decimal es la
   forma nativa que el resto del código ya asume. **Decisión: mantener `decimal`, sin migración** —
   el invariante equivalente es "nunca castear a Float, toda la aritmética en `BigDecimal`".
2. **`finance` YA estaba addon-gated, en el nav, y con permisos sembrados — todo desde ANTES de que
   existiera un controller real.** `config/entitlements/finance.rb` (registrado en v1.3.0/S2b, con
   un comentario explícito: "No `Finance::*Controller` exists yet... this declaration pre-registers
   the gate"), `finance` ya en `ControlPlane::AddonCatalog::DOMAIN_KEYS` y en
   `ControlPlane::SeedCatalog::ADDONS` (700.000 cop/mes), `config/navigation/finance.rb` ya apuntando
   a `/finance` con permiso `finance.read`. Y los permisos `finance.read`/`finance.write` YA estaban
   en `IdentityAccess::SeedPermissions::CATALOG`, YA sembrados a `institution_admin` (vía el stub
   `RoleRoster`), y **YA reusados por `Cafeteria::BalancesController`** para su propia función de
   "Saldos" (comentario explícito ahí: "Reuses finance.read... rather than..."). El §2 del prompt
   ("este slice decide el addon-gating") era un no-op — no se agregó ni cambió nada de eso. El §7
   ("agregar `finance.view`/`finance.manage`") tampoco se siguió literal: se reusaron
   `finance.read`/`finance.write` para no crear una segunda superficie de permiso solapada ni romper
   el consumidor cruzado de cafetería.
3. **Ya existían 5 partials de vista pre-construidos** en `app/views/finance/`
   (`_balance_summary`, `_charge_row`, `_payment_status_badge`, `_statement_line`,
   `_payment_plan_card`) con locals planos (no objetos AR) — se ensamblaron en las vistas nuevas en
   vez de duplicar su lógica. `_payment_plan_card` quedó sin usar (tiene su propio TODO, planes
   diferidos). `Payment`/`Charge` ya traían una columna `idempotency_key` con índice único por
   institución, sin usar hasta este slice — se activó como la guarda real de doble-submit en vez de
   inventar una nueva.

**Checkpoint de rol de tesorería:** no existe un rol formal en el catálogo (`IdentityAccess::
RoleRoster` es un stub, igual que confirmó `attendance`/`report_cards`), pero
`test/integration/cafeteria_test.rb` ya usa el `role_key` `"treasury"` como convención de facto para
un actor con `finance.read`. Se siguió esa misma convención en los tests de este slice (con
`finance.write` agregado) — no se agregó ninguna fila nueva a `RoleRoster`.

**Lo construido:**
- Sin migración — los cinco modelos ya existían; RLS `FORCE` ya estaba en las cinco tablas
  (verificado, sin hallazgo material ahí).
- `Finance::AccountScope` — query object nuevo (molde #4), institución-wide por diseño (tesorería es
  función central, no por grupo/homeroom como los dominios académicos).
- `Finance::AccountStatement` — el único camino de lectura del estado de cuenta (saldo, cargos
  pendientes, historial fusionado cronológico), consumido por AMBAS superficies (mismo patrón que
  `ReportCards::Computation`, v1.17.0). Puentea `StudentAccount`→`student_id`→`Charge` porque
  `Charge` no tiene FK a `StudentAccount` (solo a `student` directo).
- `Finance::PaymentRecorder`/`Finance::ChargeCreator` — transaccionales, `account.lock!` (pessimista)
  + guarda de `idempotency_key` (chequeada antes Y después del lock, para cerrar la ventana de
  carrera). `PaymentRecorder` marca un `Charge` como `paid` si los pagos completados contra él ya
  cubren su monto.
- `Finance::AccountsController#index/show`, `Finance::PaymentsController#new/create`,
  `Finance::ChargesController#new/create` — rutas bajo `namespace :finance` con `resources
  :accounts, path: ""` para que `index` caiga exactamente en `/finance` (el path que el nav
  pre-existente ya esperaba).
- Portal: `Portals::GuardianFinanceController#show`, nested bajo `guardian/students/:id/finance`
  (mismo criterio de anidado por-hijo que `report_cards`, v1.17.0, por volumen de contenido) — solo
  lectura, mismo `AccountStatement`, sin `authorize!`, fuera de `Navigation::Registry`, ninguna
  acción de escritura expuesta. Botón "Estado de cuenta" agregado a `guardian_students/show`.

**Caso de aceptación, verificado end-to-end:** registrar un pago de $50.000 baja el saldo a
exactamente `-50000.00` (BigDecimal, sin drift); crear un cargo de $120.000 sube el saldo a
`120000.00`; pagar un cargo por su monto completo lo marca `paid`; una escritura que viola un
`CHECK` de la BD (`method` inválido) revierte TODO — ni el `Payment` ni el cambio de saldo quedan
persistidos (atomicidad real, no solo aserta que "debería"); resubmitir el mismo
`idempotency_key` nunca duplica un pago ni un cargo; un docente sin `finance.read` recibe 403; sin
entitlement de `finance`, 403 con "no está habilitado" antes que cualquier chequeo de RBAC; el
acudiente ve el estado de cuenta de SU hijo (nunca otra familia, 404 al adivinar), sin ninguna
acción de escritura ni formulario en la página, y ve el empty state (no un error) si no tiene hijos
resueltos; supervisión y portal leen la MISMA cifra de saldo para la misma cuenta (mismo
`Finance::AccountStatement`); aislamiento cross-tenant verificado con query real bajo RLS.

**Resultado:** 442 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 428; 14 tests
nuevos, todos en `test/integration/finance_test.rb`). `bin/rails zeitwerk:check` verde. Cero
migraciones — dominio ya real en esquema, solo se construyó UI+servicios+gating (gating ya existía).

**Archivos nuevos/editados:**
- Servicios: `app/domains/finance/services/account_statement.rb`,
  `app/domains/finance/services/payment_recorder.rb`, `app/domains/finance/services/charge_creator.rb`.
- Query object: `app/domains/finance/queries/account_scope.rb`.
- Controllers: `app/controllers/finance/accounts_controller.rb`,
  `app/controllers/finance/payments_controller.rb`, `app/controllers/finance/charges_controller.rb`,
  `app/controllers/portals/guardian_finance_controller.rb`.
- Vistas: `app/views/finance/accounts/{index,show}.html.erb`,
  `app/views/finance/payments/new.html.erb`, `app/views/finance/charges/new.html.erb`,
  `app/views/portals/guardian_finance/show.html.erb` (+ botón nuevo en
  `app/views/portals/guardian_students/show.html.erb`). Reusa los 5 partials pre-existentes de
  `app/views/finance/_*` sin modificarlos.
- Rutas: `config/routes.rb` (`namespace :finance` + nested resource de portal). Sin cambios a
  `config/entitlements/finance.rb`, `config/navigation/finance.rb`,
  `ControlPlane::AddonCatalog::DOMAIN_KEYS`, `ControlPlane::SeedCatalog::ADDONS`, ni
  `IdentityAccess::SeedPermissions::CATALOG` — los cinco ya estaban correctos.
- Tests: `test/integration/finance_test.rb`.

### v1.17.0 — 2026-07-15 — `report_cards`: boletines (ítem #3 del MVP)

**Ítem #3 del camino crítico de `LINEAMIENTOS_MVP.md`**, sobre la mitad de calificaciones ya real de
`schedules` (v1.14.0/v1.15.0). Tres decisiones de diseño llegaron YA aprobadas en el prompt (no
checkpoint de diseño abierto esta vez, a diferencia de `attendance` v1.16.0): dominio `report_cards`
propio addon-gated; snapshot congelado al publicar; dos superficies (supervisión + portal).

**Recon (STOP #1):** confirmado `grep -riE "boletin|report_card" db/migrate/ app/domains/`
sin resultados — dominio net-new real, sin stub previo de ninguna fase. `Schedules::Assessment`
(desde v1.14.0) ya trae `weight` (default 1.0) y `max_score` (default 5.0) — ninguna lógica de
promedio/GPA existía todavía en `schedules`, así que el prompt tenía razón en pedir que este slice
la introdujera, y en `report_cards`, nunca en `schedules`. `Schedules::Enrollment.academic_term_id`
(v1.15.0) es el join real que hace posible filtrar notas por término sin re-derivar nada.
`Schedules::ActiveTermEnrollmentScope.resolve(institution:)` confirmado idéntico a como lo consumió
`attendance` — mismo resolver, sin cambios. Plantilla de addon-gating de `attendance` (v1.16.0)
copiada literal: `config/entitlements/*.rb` de una línea, entrada en
`ControlPlane::AddonCatalog::DOMAIN_KEYS`, `test/models/entitlement/registry_consistency_test.rb`
(genérico, sin tocar). **Hallazgo que ajustó el plan**: `IdentityAccess::RoleRoster` es un catálogo
STUB (documentado como tal en su propio archivo) — `attendance.record` tampoco está ahí, así que
sembrar `report_card.view`/`report_card.publish` a roles reales no tiene un ancla de seed real en
este repo; se agregaron solo a `IdentityAccess::SeedPermissions::CATALOG` (el catálogo global real),
mismo alcance que `attendance` tomó.

**Lo construido:**
- Migración `20260715142947_create_report_cards.rb`: tabla + 2 índices (unicidad
  `(institution_id, student_id, academic_term_id)` + `(institution_id, academic_term_id)`) + CHECK
  de `status` (`draft`/`published` — hoy toda fila persistida es `published`, ver más abajo) +
  `enable_rls`. Corrida en dev y test.
- Modelo `ReportCards::ReportCard` — `readonly? = persisted?`, mismo patrón que
  `ControlPlane::InvoiceLineItem`: una vez publicada, una fila nunca se `update`/`destroy` individual.
- `ReportCards::Computation` — agregación EN VIVO por `(estudiante, término)`: cada
  `Schedules::Assessment` con nota se normaliza a la escala 0.0–5.0 (`score/max_score*5.0`) antes de
  ponderar por `weight`; una materia sin notas cargadas no aporta línea (nunca un cero, el boletín a
  mitad de término es parcial por diseño); `overall_average` es el promedio simple de las líneas por
  materia. Consumida tanto por el preview de supervisión como por `Publisher` — es LA única fuente
  de verdad del cómputo, nunca duplicada.
- `ReportCards::Publisher` — publicación síncrona idempotente: por estudiante, computa, congela el
  snapshot, y regenera la fila con `ReportCard.where(...).delete_all` + `create!` (nunca
  `destroy_all`/`update` — `delete_all` bypassea `readonly?` a propósito, mismo balance que
  `ControlPlane::Billing::PeriodCut` ya documenta para `InvoiceLineItem`; de hecho el primer intento
  usó `destroy_all` y disparó `ActiveRecord::ReadOnlyRecord` en desarrollo, confirmando por qué el
  patrón de `PeriodCut` existe).
- Dos permisos nuevos, split (a diferencia del único `attendance.record`): `report_card.view`
  (previsualizar + ver publicados) y `report_card.publish` (publicar/regenerar) — publicar es una
  acción más sensible que previsualizar, mismo criterio que separó `accommodations.view`/`.manage`.
- `config/entitlements/report_cards.rb` + `report_cards` agregado a
  `ControlPlane::AddonCatalog::DOMAIN_KEYS` + a `ControlPlane::SeedCatalog::ADDONS` (fee plano, sin
  medición — `metered` queda en su default `false`).
- `ReportCards::GroupScope` — query object nuevo (NO reutiliza `Attendance::GroupScope`, filtra por
  `report_card.view`, un permiso distinto).
- Supervisión: `ReportCards::GroupsController#index` (mis grupos) →
  `ReportCards::PublicationsController#new` (preview: roster tomable + promedio en vivo por
  estudiante, sin persistir nada) → `#create` (publica los estudiantes seleccionados vía
  `Publisher`). Nav: `config/navigation/report_cards.rb` ("Boletines", permiso `report_card.view`).
- Portal: `Portals::GuardianReportCardsController#index` (nested bajo el hijo específico, vía
  `GuardianScope.for(user).find(params[:student_id])` — nunca `Student.find` directo) y
  `Portals::StudentReportCardsController#index` (vía `StudentSelfScope`). Ambos: sin `authorize!`,
  fuera de `Navigation::Registry`, consultan solo `status: "published"` — nunca ven un preview. Se
  enlazan desde `guardian_students/show` y `student_portal/show` (botón "Boletines"/"Mis boletines"),
  no desde ningún registry.
- **Decisión explícita, no un olvido**: `db/seeds.rb` NO se tocó — mismo alcance que `attendance`
  (v1.16.0) tampoco lo tocó; el catálogo de addons demo se siembra por el rake task
  `control_plane:seed_catalog` (ya actualizado), no por `db/seeds.rb`, y el prompt dejaba la fila de
  demo condicionada a "si el seed de demo lo amerita" — no lo amerita todavía sin una necesidad real
  de demo end-to-end.

**Modelo de datos — el fork del "draft":** el prompt proponía dos formas posibles (fila desde
draft, estilo `invoices`, vs. cómputo vivo sin fila) y dejaba el default explícito: **cómputo vivo
sin fila**. Se tomó ese default — una fila `report_cards` existe SOLO al publicar, así que hoy el
`status` de cualquier fila persistida es siempre `"published"`; el CHECK sigue permitiendo `"draft"`
por si esa decisión se revierte más adelante, pero no hay código que lo produzca hoy.

**Caso de aceptación, verificado end-to-end:** un docente con `role_assignment` scoped a
`group:9°A` ve solo 9°A en el índice; el preview de 9°A muestra el promedio calculado en vivo de un
estudiante matriculado en el término activo y excluye a uno del grupo que no lo está; publicar
persiste un `ReportCard` congelado por estudiante seleccionado; **editar la nota viva DESPUÉS de
publicar no cambia el boletín ya publicado** (test estrella, verificado con `update_columns` directo
sobre el `Assessment` para evitar cualquier duda de que el read-path esté cacheando en memoria);
re-publicar el mismo (estudiante, término) regenera la fila (mismo `id` no sobrevive — prueba de que
fue `delete_all`+`create!`, no un `update`) sin duplicar; el mismo docente recibe 403 en `group:9°B`
(fuera de su scope); un actor con `report_card.view` pero sin `report_card.publish` no ve el botón
de publicar en la vista Y recibe 403 real si intenta el POST igual (cosmético vs. gate duro, nunca
confundidos); sin entitlement de `report_cards`, la petición da 403 con "no está habilitado" (gate
#1 antes que gate #2); aislamiento cross-tenant verificado con query real bajo RLS; sin
`input[type=search]`/`input[name=q]` en la vista de publicación; el portal del acudiente ve el
boletín publicado de SU hijo y recibe 404 (nunca 200) al adivinar el id del hijo de otra familia; el
portal nunca muestra nada si no se publicó todavía (ni preview, ni draft). Test de regresión
adicional: el headcount de `Core::Headcount::Snapshotter` no se ve afectado por la existencia de
`report_cards` — no se tocó su fuente ni se re-derivó el join de término.

**Resultado:** 428 runs / 0 failures / 0 errors / 1 skip preexistente (baseline 407; 21 tests
nuevos: 17 en `test/integration/report_cards_test.rb`, 4 en
`test/models/report_cards/computation_test.rb`). `bin/rails zeitwerk:check` verde. Una migración,
aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260715142947_create_report_cards.rb`.
- Modelo: `app/domains/report_cards/models/report_card.rb`.
- Servicios: `app/domains/report_cards/services/computation.rb`,
  `app/domains/report_cards/services/publisher.rb`.
- Query object: `app/domains/report_cards/queries/group_scope.rb`.
- Controllers: `app/controllers/report_cards/groups_controller.rb`,
  `app/controllers/report_cards/publications_controller.rb`,
  `app/controllers/portals/guardian_report_cards_controller.rb`,
  `app/controllers/portals/student_report_cards_controller.rb`.
- Vistas: `app/views/report_cards/groups/index.html.erb`,
  `app/views/report_cards/publications/new.html.erb`,
  `app/views/portals/guardian_report_cards/index.html.erb`,
  `app/views/portals/student_report_cards/index.html.erb` (+ botones de entrada nuevos en
  `app/views/portals/guardian_students/show.html.erb` y `app/views/portals/student_portal/show.html.erb`).
- Config: `config/entitlements/report_cards.rb`, `config/navigation/report_cards.rb`,
  `config/routes.rb` (namespace `report_cards` + nested resources de portal).
- Catálogo/permisos: `app/control_plane/control_plane/addon_catalog.rb`,
  `app/control_plane/control_plane/seed_catalog.rb`,
  `app/domains/identity_access/services/seed_permissions.rb`.
- Tests: `test/integration/report_cards_test.rb`, `test/models/report_cards/computation_test.rb`.

### v1.16.0 — 2026-07-14 — `attendance`: asistencia diaria por homeroom (ítem #2 del MVP)

**Ítem #2 del camino crítico de `LINEAMIENTOS_MVP.md`**, ahora que la matrícula/término cerró su
mitad de modelo (v1.15.0). Construye el registro de asistencia — el loop diario que el colegio
piloto exige. Dominio NET-NEW (cero tablas antes de este slice) → checkpoint de diseño obligatorio.

**Recon (STOP #1):** confirmado `grep -i attendance db/migrate/*.rb` sin resultados — Clase C/
net-new real, sin sorpresas esta vez (a diferencia de `student_support` en v1.14.0).
`Schedules::ActiveTermEnrollmentScope.resolve(institution:)` (v1.15.0) confirmado como una relation
`GroupManagement::Student` **componible** — no necesita un parámetro de grupo propio; el caller
simplemente encadena `.where(section_id: group.id)` encima, exactamente el layering que este slice
necesitaba. `GroupManagement::MembershipsController#update` (v1.14.0) confirmado como el patrón de
escritura tenant-scoped a imitar. El wiring de entitlement (`config/entitlements/*.rb` +
`ControlPlane::AddonCatalog::DOMAIN_KEYS` + `registry_consistency_test.rb`) confirmado vía
`counseling` como el ejemplo más reciente.

**Checkpoint de diseño (STOP #2) — decisiones aprobadas:**
1. **Dónde vive**: dominio `attendance` propio, addon-gated, diaria por homeroom — el fork (c) que
   el propio prompt ya recomendaba. Ni `schedules` (grano equivocado — por materia, no por
   homeroom) ni `group_management` (fundacional; asistencia es una capacidad que un colegio podría
   NO comprar, así que addon-gated es lo correcto).
2. **Forma de `attendance_records`**: `institution_id`, `student_id` (FK `students`), `group_id` (FK
   `sections` — el homeroom para el que se tomó, guardado explícitamente y NO derivado del
   `section_id` actual del estudiante, que puede cambiar después de que se tomó la asistencia
   pasada), `date`, `status` (CHECK `present/absent/late/excused`), `recorded_by_staff_member_id`
   (FK `staff_members`), `note`. **Dos desviaciones menores del texto literal del prompt, aprobadas
   explícitamente**: (a) el índice único es `(institution_id, student_id, date)` — tenant-scoped
   compuesto, como cualquier otro índice único del esquema, no el `(student_id, date)` literal del
   prompt; (b) `recorded_by_staff_member_id` es **nullable** — no todo actor tiene una fila
   `StaffManagement::StaffMember` (la transición aditiva de D1 sigue siendo parcial), y exigirlo
   habría bloqueado el registro de asistencia para un actor legítimo sin ese link.
3. **Roster tomable**: la intersección exacta de tres capas — `ActiveTermEnrollmentScope` (hecho
   académico crudo) ∩ el grupo (`.where(section_id:)`, scope de negocio) ∩ el scope RBAC del actor
   (`Attendance::GroupScope`, per-row `can?` sobre `attendance.record`). Un alumno del grupo pero
   sin matrícula en el término activo nunca aparece — ni en el roster ni recibe una fila.
4. **Forma del controller**: `GroupsController#index` (mis grupos, molde #4) → `RecordsController
   #new/#create` (nested bajo `groups`), **sin `GroupsController#show`** — una página de grupo sin
   fecha no tendría nada real que mostrar más allá del link hacia `records#new`, así que el índice
   enlaza directo. Simplificación aprobada explícitamente.

**Lo construido:**
- Migración `20260714205355_create_attendance_records.rb`: tabla + 2 índices + CHECK de `status` +
  `enable_rls` (ENABLE+FORCE+policy+WITH CHECK). Corrida en dev y test.
- Modelo `Attendance::AttendanceRecord`.
- Permiso nuevo `attendance.record` (un solo permiso cubre tomar Y ver, mismo criterio unificado
  que `disciplinary_logs.manage` — sin separación read/write porque no hay nivel de confidencialidad
  aquí).
- `config/entitlements/attendance.rb` + `attendance` agregado a
  `ControlPlane::AddonCatalog::DOMAIN_KEYS` + a `ControlPlane::SeedCatalog::ADDONS` (catálogo de
  demo, para que el addon exista de verdad si alguien corre `control_plane:seed_catalog`).
- `Attendance::GroupScope` — query object nuevo (NO reutiliza `GroupManagement::GroupScope`,
  porque filtra por un permiso DISTINTO — `attendance.record` vs. `groups.view` — y un docente
  puede tener uno sin el otro).
- `Attendance::GroupsController#index` + `Attendance::RecordsController#new/#create` — el `#create`
  hace upsert real por estudiante (`find_or_initialize_by(institution_id:, student_id:, date:)`),
  aprovechando el índice único para que re-tomar el mismo (grupo, fecha) actualice en vez de duplicar.
- Nav: `config/navigation/attendance.rb` ("Asistencia", permiso `attendance.record`).
- Vistas: `attendance/groups/index` (mis grupos + link "Tomar asistencia"),
  `attendance/records/new` (selector de fecha + roster con estado/nota por estudiante).

**Caso de aceptación, verificado end-to-end:** un docente con `role_assignment` scoped a `group:9°A`
ve solo 9°A en el índice; el roster de 9°A excluye a un estudiante del grupo que no está matriculado
en el término activo; tomar asistencia persiste un `AttendanceRecord` por alumno del roster;
re-tomar el mismo (grupo, fecha) actualiza los registros existentes (verificado con conteo,
`1 → 1`, nunca `1 → 2`); el mismo docente recibe 403 al intentar `group:9°B` (fuera de su scope);
sin entitlement de `attendance`, la petición da 403 con el texto "no está habilitado" (gate #1 antes
que gate #2 — confirmado que ambos gates devuelven **el mismo status HTTP** 403, la diferencia real
está en el cuerpo de la respuesta, no en el código); aislamiento cross-tenant verificado con query
real bajo RLS; sin `input[type=search]`/`input[name=q]` en la vista de toma de asistencia (con el
mismo scoping a `main#main` de siempre para excluir el buscador global del shell). Test de
regresión adicional: el headcount de `Core::Headcount::Snapshotter` no se ve afectado por la
existencia de `attendance_records` — no se tocó su fuente ni se re-derivó el join de término.

**Resultado:** 407 runs / 1471 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
397; 10 tests nuevos, todos en `test/integration/attendance_test.rb`). `bin/rails zeitwerk:check`
verde. Una migración, aplicada en dev y test.

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260714205355_create_attendance_records.rb`.
- Modelo: `app/domains/attendance/models/attendance_record.rb`.
- Query object: `app/domains/attendance/queries/group_scope.rb`.
- Controllers: `app/controllers/attendance/{groups,records}_controller.rb`.
- Vistas: `app/views/attendance/groups/index.html.erb`, `app/views/attendance/records/new.html.erb`.
- Config: `config/entitlements/attendance.rb`, `config/navigation/attendance.rb`,
  `app/control_plane/control_plane/addon_catalog.rb` (+`attendance`),
  `app/control_plane/control_plane/seed_catalog.rb` (+`attendance`, catálogo de demo).
- Permiso: `app/domains/identity_access/services/seed_permissions.rb` (+`attendance.record`).
- Test: `test/integration/attendance_test.rb` (nuevo).

Con esto, el ítem #2 del camino crítico del MVP queda cerrado. Próximo candidato según
`LINEAMIENTOS_MVP.md` §7: boletines sobre la libreta ya real de `schedules` (agregación +
mostrarlos en el portal del cuidador).

### v1.15.0 — 2026-07-14 — Matrícula por término real (ítem #1 del camino crítico del MVP)

**Ítem #1 del camino crítico de `LINEAMIENTOS_MVP.md`.** Hace first-class "el estudiante en el
término activo" — hoy inexistente: `enrollments.term` era un string libre sin FK a `academic_terms`
(borde **Cav.**). Es un slice de MODELO fundacional (no de vistas), con checkpoint de diseño
obligatorio antes de tocar esquema.

**Recon (STOP #1) — la corrección que cambió el problema:** el prompt asumía **tres** estructuras
"enrollment-ish" conviviendo (`core.enrollments`, `students.section_id`, `Schedules::Enrollment`).
El recon confirmó que son **dos**, no tres: **no existe ninguna tabla `core.enrollments`** — hay UNA
sola tabla `enrollments` en todo el esquema (`db/migrate/20260703000010_create_academics.rb`), y ya
está modelada como `Schedules::Enrollment` desde el barrido de #4 (v1.14.0). `students.section_id`
(grupo/homeroom) es una dimensión completamente separada, sin relación con término (atada a
`Section.academic_year`, un entero, no a `academic_terms`). Otros hallazgos:
- `Core::RosterImportBatch` ya tenía un FK real a `academic_terms` — el único precedente existente,
  y el patrón de resolución (`Core::AcademicTerm.active.find_by(institution_id:)`) ya usado ahí.
- `Core::Headcount::Snapshotter` confirmado: cuenta `students.status == "active"`, cero dependencia
  de `enrollments`/término — su propio comentario ya documentaba la limitación.
- **`db/seeds.rb` no crea NINGÚN `AcademicTerm`** — el `TERM = "2026-1"` de la demo es un string sin
  ninguna fila real de `academic_terms` detrás. El join, aun cerrado, habría quedado inerte en datos
  de desarrollo sin un ajuste al seed.

**Checkpoint de diseño (STOP #2) — decisiones aprobadas:**
1. **Tabla canónica**: `Schedules::Enrollment` (la única real) gana `academic_term_id` (FK nullable,
   aditiva). `term` (string) sigue existiendo sin tocar — coexistencia, mismo patrón que
   `guardian_students`/`student_guardians`. Sin backfill forzado (aditivo puro).
2. **Ubicación del query object**: `Schedules::ActiveTermEnrollmentScope`
   (`app/domains/schedules/queries/`), no `Core::Access::*` — consulta directamente
   `Schedules::Enrollment`, la tabla que posee; los consumidores cross-domain futuros (asistencia,
   actividades, asignaciones) lo leen por referencia, mismo patrón que `self_service_controller`
   leyendo `StaffManagement::Department`.
3. **Seed fix**: sí, agregar un `AcademicTerm` activo real por institución sembrada + backfillear
   `academic_term_id` en las matrículas sembradas — para que el join tenga datos reales que resolver
   desde el primer `bin/rails db:seed`, no solo en tests.
4. **Wiring del único write-path real**: sí, `GradeEntriesController#create` (v1.14.0, el único lugar
   del código que crea un `Enrollment` hoy) también resuelve y guarda el término activo — un cambio
   de una línea sobre una llamada existente, no una vista nueva (F5 respetado).

**Lo construido:**
- Migración `20260714201234_add_academic_term_to_enrollments.rb`: `add_reference :enrollments,
  :academic_term` (nullable, `on_delete: :nullify`) + índice `(institution_id, academic_term_id)`.
  Corrida en dev y test.
- `Schedules::Enrollment belongs_to :academic_term, optional: true`.
- `Schedules::ActiveTermEnrollmentScope.resolve(institution:)` — resuelve `GroupManagement::Student`
  distintos con al menos una `Enrollment` en el término activo de la institución. Sin buscador
  (Habeas Data); no identity-gated (es un hecho crudo, cada consumidor aplica su propio RBAC encima,
  igual que `TeacherManagement::TeacherScope`); se apoya en el invariante "un solo término activo"
  (`Core::AcademicTerm.active`) sin reimplementarlo.
- `GradeEntriesController#create` resuelve `Core::AcademicTerm.active.find_by(...)` y lo asigna al
  crear el `Enrollment`.
- `db/seeds.rb`: nuevo helper `build_active_term(iid)` — un `AcademicTerm` activo (código `2026-1`,
  igual a la constante `TERM` ya usada) por institución sembrada; `build_enrollments` ahora recibe
  `academic_term_id:` y lo escribe en el `insert_all!` masivo. `reset_institution!` limpia también
  `Core::AcademicTerm` al re-sembrar.

**F3 verificado (el riesgo #1 del prompt):** se agregó un test de regresión dedicado en
`Core::Headcount::SnapshotterTest` que siembra tres estudiantes con el MISMO `status: "active"` pero
tres estados de matrícula distintos (matriculado en el término activo, matriculado solo en un
término pasado, sin matrícula alguna) y confirma que el headcount cuenta a los tres por igual — la
prueba directa de que el nuevo join no se coló en la fuente de facturación. **B2** (fechado de
`role_assignments` vs. calendario lectivo) — sin cambios, confirmado como borde distinto.

**Resultado:** 397 runs / 1428 assertions / 0 failures / 0 errors / 1 skip preexistente (baseline
387; 10 tests nuevos: 8 unitarios de `ActiveTermEnrollmentScope` —incluye cross-tenant bajo RLS real
y el caso "enrollment legacy sin `academic_term_id`"—, 1 de regresión de headcount, 1 de integración
en `schedules_test.rb` probando que el write-path real ahora sí guarda el término). `bin/rails
zeitwerk:check` verde. Una migración, aplicada en dev y test.

**Nota de verificación honesta:** no se pudo correr `bin/rails db:seed` de punta a punta contra la
base de datos de desarrollo local en esta sesión — falla en `reset_institution!` por una
`ControlPlane::Subscription` preexistente que bloquea el borrado de una institución demo (un estado
de datos de desarrollo de una sesión manual anterior, no causado por este slice ni relacionado con
el cambio). Se verificó la sintaxis del script (`ruby -c`) y la lógica completa vía la suite de
tests (base de datos de test separada, sin ese estado preexistente).

**Archivos nuevos/editados:**
- Migración: `db/migrate/20260714201234_add_academic_term_to_enrollments.rb`.
- Modelo: `app/domains/schedules/models/enrollment.rb` (+`belongs_to :academic_term`).
- Query object (nuevo): `app/domains/schedules/queries/active_term_enrollment_scope.rb`.
- Controller: `app/controllers/schedules/grade_entries_controller.rb` (resuelve+guarda término activo).
- Seeds: `db/seeds.rb` (`build_active_term`, `build_enrollments` con `academic_term_id:`,
  `reset_institution!` incluye `Core::AcademicTerm`).
- Tests: `test/models/schedules/active_term_enrollment_scope_test.rb` (nuevo),
  `test/models/core/headcount/snapshotter_test.rb` (+regresión F3),
  `test/integration/schedules_test.rb` (+2 tests sobre `academic_term_id`).

Con esto, el ítem #1 del camino crítico del MVP (`LINEAMIENTOS_MVP.md` §7) queda cerrado. Próximo
candidato según ese documento: `attendance` (asistencia, net-new, con su propio checkpoint de diseño).

### v1.14.1 — 2026-07-14 — patch editorial: `LINEAMIENTOS_MVP.md`

El usuario compartió un documento de lineamientos de MVP para un perfil de cliente concreto (colegio
K-12: extracurriculares, comunicación interna/externa, asignaciones académicas/responsabilidades, y
calendario compartido con cuidadores). El documento mismo aclara que **no es un prompt de
implementación** — es la guía que va a alimentar los slices siguientes, respetando en cada dominio
nuevo la misma disciplina recon-first que el resto del proyecto.

Se preguntó explícitamente qué hacer con él antes de actuar (guardarlo como referencia, actualizar
el backlog, o arrancar el primer slice del camino crítico ya) — el usuario eligió **guardarlo como
documento del proyecto + actualizar el backlog del magro**, sin tocar código.

**Qué dice el documento (resumen, el detalle completo vive en `LINEAMIENTOS_MVP.md`):**
- **Principio de encaje**: todo lo externo (comunicación, calendario, asignaciones, actividades)
  cuelga del portal del cuidador vía `Core::Access::GuardianScope` — nunca una segunda puerta RBAC
  para acudientes. Un addon = un dominio; los nuevos (`extracurriculars`, `communication`,
  `calendar`, `assignments`) se habilitan por entitlement, igual que los existentes.
- **Reconcilia el pedido contra v1.14.0 real**, no contra un estado asumido: la libreta de notas
  (`Schedules::Assessment`) ya existe — el MVP construye boletines encima, no una libreta nueva;
  `finance` ya tiene modelos reales — el MVP construye la UI de tesorería, no el modelo; la
  matrícula (`students.section_id`) ya escribe real — falta solo cerrar el join con
  `academic_terms` (B2/Cav.), no construir matrícula desde cero.
- **Cuatro dominios genuinamente net-new** (sin ninguna tabla hoy, cada uno con su propio checkpoint
  de diseño al construirse, al estilo CHECKPOINT E): `attendance` (asistencia), `assignments`
  (asignaciones académicas — decisión ya resuelta de ser dominio propio, no faceta de
  `communication`), `calendar`, `extracurriculars`.
- **`student_support`/`counseling`/`cafeteria`/`transportation` reales no aplican a este perfil de
  cliente** — no es que el backlog general los excluya, es que este MVP concreto no los pide.
- Camino crítico propuesto (§7 del documento): cerrar matrícula/término primero (desbloquea casi
  todo lo demás) → asistencia → boletines → tesorería → comunicación → asignaciones → calendario →
  extracurriculares → portal del cuidador ampliado → provisioning + correo real.

**Resultado:** `LINEAMIENTOS_MVP.md` creado (hermano de `PROJECT_STATE.md`/`HISTORIA.md`/
`CONCEPTOS_TECNICOS.md`). `PROJECT_STATE.md` §11 (backlog) actualizado con una nota que apunta a
este documento como el que reordena/prioriza el backlog para ese perfil de cliente. Ningún archivo
de código tocado; ninguna migración; suite sin cambios (387/0/1, sin necesidad de re-correr).

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
