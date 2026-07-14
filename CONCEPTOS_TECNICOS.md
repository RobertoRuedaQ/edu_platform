# edu_platform — Conceptos técnicos clave

> **Qué es este documento.** Catálogo de los conceptos de diseño, arquitectura y seguridad que
> sostienen el proyecto — pensado para que quien no los tenga frescos pueda familiarizarse con
> `edu_platform` sin tener que releer todo el código de una vez. Cada concepto trae: qué es, por qué
> se usa aquí específicamente, y dónde verlo en código real para estudiarlo de primera mano.
>
> Complementa a `PROJECT_STATE.md` (que documenta *qué* se construyó y en qué estado está). Este
> archivo documenta el *vocabulario* y las *ideas* detrás de esas decisiones.

---

## 1. Multi-tenancy y aislamiento de datos

**Row-level multi-tenancy (shared-schema).**
Todos los inquilinos (instituciones) comparten las mismas tablas; cada fila lleva `institution_id`.
Es la alternativa "barata" frente a *schema-per-tenant* o *database-per-tenant*: más simple de
operar para un dev solo, a costa de que el aislamiento depende al 100% de que el filtro por
`institution_id` nunca falle.
📍 `db/structure.sql` — cualquier tabla con columna `institution_id`.

**Row-Level Security (RLS) de Postgres, con `FORCE`.**
Es el motivo por el que el punto anterior no da miedo: la base de datos misma rechaza filas fuera
de tenant, aunque la app tenga un bug. `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` (el
`FORCE` es clave: sin él, el dueño de la tabla se salta la política). Una *policy* con
`USING`/`WITH CHECK` compara `institution_id` contra un GUC de sesión.
📍 Cualquier migración de tabla tenant-scoped, ej. `db/migrate/20260708000004_create_academic_terms.rb`.

**GUC (Grand Unified Configuration) de Postgres + `SET LOCAL`.**
El mecanismo que conecta Rails con RLS: `set_config('app.current_institution_id', ..., true)` fija
una variable de sesión SOLO para la transacción actual (`is_local => true`), así nunca sobrevive a
la siguiente request que reutilice esa misma conexión del pool.
📍 `lib/tenant/guc.rb`.

**Defensa en profundidad (defense in depth).**
El principio general detrás de los dos puntos anteriores: el filtro explícito en Rails (Query
objects) es la primera línea; RLS es el respaldo si la primera falla. Nunca se confía en una sola
capa.

**Resolución de tenant por subdominio.**
El inquilino no se pasa como parámetro; se deriva del subdominio de la request
(`acme.eduplatform.app` → institución "acme"). Esto es lo que permitió resolver el link de
invitación (que llega antes de cualquier sesión) sin inventar mecanismos especiales.
📍 `lib/tenant/resolver.rb`.

---

## 2. Seguridad de identidad y autenticación

**Principio de menor privilegio a nivel de roles de base de datos.**
Tres roles Postgres distintos según lo que necesitan hacer: `edu_app_runtime` (solo DML, sin
`CREATE`, sin `BYPASSRLS`), `edu_migrator` (DDL), `edu_bi_reader` (el único con `BYPASSRLS`,
auditado, para BI cross-tenant). Ningún rol tiene más poder del que su trabajo exige.
📍 `lib/tasks/roles.rake`.

**Autenticación nativa de Rails 8.**
`has_secure_password` (bcrypt por debajo) + un modelo `Session` persistido en base de datos (no
solo cookie) + `ActiveSupport::CurrentAttributes` para el contexto de request. Es el patrón que
generan los scaffolds nuevos de Rails 8, sin Devise.
📍 `app/controllers/concerns/authentication.rb`, `app/models/current.rb`.

**`CurrentAttributes` (patrón "Current").**
Una forma de tener "globales" seguras por request: se resetean automáticamente al final de cada
ciclo de ejecución, así que nunca se filtran datos de un usuario a la siguiente request (a
diferencia de una variable de clase o un singleton real).
📍 `app/models/current.rb`.

**MFA por OTP (one-time password) de un solo uso.**
Código numérico de vida corta (TTL), con: (a) solo se guarda el *hash* SHA-256 del código, nunca el
código en claro; (b) comparación con `ActiveSupport::SecurityUtils.secure_compare` (comparación en
tiempo constante, para no filtrar información por *timing attack*); (c) bloqueo tras N intentos
fallidos.
📍 `app/domains/identity_access/services/otp/`.

**Patrón "digest-only" para secretos.**
Ni el código OTP ni el token de invitación se guardan en claro en la base de datos; solo su digest.
Si la base de datos se filtra, los secretos activos no se filtran con ella.
📍 `app/domains/identity_access/services/otp/`, `IdentityAccess::Invitations::Issuer`.

**Anti-enumeración.**
Respuestas idénticas para "usuario no existe" vs. "contraseña incorrecta" vs. "no tiene membresía
en este tenant" — para que un atacante no pueda usar el formulario de login para averiguar qué
correos existen.
📍 `SessionsController#authenticate_credentials`.

**Rate limiting nativo de Rails 8.**
`rate_limit to:, within:` — throttling declarativo a nivel de controlador, sin gema externa, usado
en login, OTP e invitaciones.

**Encriptación determinística (`encrypts ..., deterministic: true`).**
Cifra el documento nacional en reposo, pero de forma que el mismo valor en claro siempre produce el
mismo ciphertext — el único modo que permite mantener un índice único sobre una columna cifrada.
Trade-off consciente: es menos seguro que la encriptación no-determinística (permite comparar
igualdad por fuerza bruta si alguien tiene acceso a la BD), pero es el precio de poder garantizar
"este documento no puede repetirse".

**Auditoría append-only reforzada a nivel de permisos de BD.**
No es solo una convención de "no hagas update a esto": el rol `edu_app_runtime` tiene
`REVOKE UPDATE, DELETE` sobre `audit_events`. Ni un bug ni un desarrollador descuidado puede
reescribir el historial desde la app.

**Referencia laxa en vez de asociación polimórfica real (`target_type`/`target_id`).**
`AuditEvent` guarda el tipo/id de a qué le pasó el evento como columnas sueltas, no como
`belongs_to :target, polymorphic: true`. Resolver el label de ese target es un `case` explícito
sobre las pocas clases reales con las que `Audit.log` se invoca — nunca
`ActiveRecord::Base.const_get` sobre el string arbitrario de la columna, que sería instanciar una
clase a partir de input no confiable.
📍 `AuditEvent#target_label`.

**Filtro sobre catálogo cerrado, no búsqueda libre (anti-directorio).**
El visor de auditoría filtra por actor (el propio staff de la institución) y por acción (tomada de
un `Hash` cerrado de acciones conocidas, `AuditEventIndex::ACTIONS`), nunca por texto libre sobre
personas — así el visor no puede convertirse accidentalmente en un buscador de estudiantes/personas
(Habeas Data). Un valor de acción que no está en el catálogo se ignora en vez de romper la query.
📍 `IdentityAccess::AuditEventIndex`.

**Índice compuesto a la medida del `ORDER BY` real, no genérico.**
`audit_events` crece sin límite (append-only); paginar "más reciente primero" por institución
necesita un índice `(institution_id, created_at DESC)` específico — los índices que ya existían
(institution+action, institution+target) no sirven para ese `ORDER BY` y degradarían a ordenar la
tabla completa en cada página a medida que el log crece.
📍 `db/migrate/20260714000001_add_institution_and_created_at_index_to_audit_events.rb`.

**Cifrado a nivel de campo dentro de un `jsonb` (API de bajo nivel de Active Record Encryption).**
`roster_import_rows` guarda cada fila del CSV como `jsonb`, pero el documento nacional dentro de ese
payload se cifra campo a campo con la API de bajo nivel de `encrypts` (no el `jsonb` completo) — así
el resto de columnas del payload queda legible para debug/soporte sin exponer el dato sensible.
📍 `app/domains/core/services/roster_import/cipher.rb`.

**No persistir el archivo crudo cuando la tabla de adjuntos no tiene RLS.**
El CSV subido para un alta batch nunca se guarda como adjunto (`has_one_attached` fue removido
adrede): las tablas de Active Storage no están protegidas por RLS, así que adjuntar el archivo
crudo habría sido una fuga cross-tenant. Solo sobrevive el resultado ya parseado/cifrado fila por
fila.
📍 `app/domains/core/services/roster_import/parser.rb`.

**Modelo "nadie se autorregistra".**
Decisión de producto con raíz en seguridad/legal (datos de menores, anti-suplantación): la cuenta
la crea la institución; la persona solo la *completa*. El documento de identidad es "conocible, no
secreto" — nunca es credencial de acceso, solo llave de conciliación.

---

## 3. Patrones de diseño Ruby/Rails

**Service objects / PORO (`.call`).**
Clases pequeñas, una responsabilidad, punto de entrada `self.call(...)` que delega a una instancia.
Evita el "modelo gordo" y el "controlador gordo".
📍 Cualquier archivo en `app/domains/*/services/`.

**Result object con `Data.define`.**
En vez de lanzar excepciones para fallos *esperados* (código OTP incorrecto, contraseña débil), los
servicios devuelven un objeto inmutable `Result` con `success?`/`error`. Las excepciones quedan
reservadas para lo verdaderamente excepcional.
📍 `IdentityAccess::Otp::Result`, `IdentityAccess::Invitations::Result`.

**Query objects en vez de `default_scope`.**
Cualquier filtro de scope (tenant, rol, alcance) es un objeto explícito que se llama a propósito,
nunca un scope automático oculto que se te olvida que existe (y que además interfiere con RLS de
formas sutiles).

**Patrón Resolver / find-or-create idempotente.**
`Core::People::Resolver` encuentra a la persona por documento o correo antes de crear, y usa
`find_or_create_by!` para la membresía — garantiza "un humano = un único `users`" sin duplicados ni
condiciones de carrera obvias.

**Puerta dura vs. cosmética (`authorize!` vs. `can?`).**
Separación explícita entre lo que *protege de verdad* (el controlador, antes de ejecutar la acción)
y lo que solo *decora la vista* (mostrar/ocultar un botón). Un error clásico es proteger algo solo
con `can?` en la vista — aquí está prohibido por convención.

**Fail-closed real-only (sin fallback a un stub sobre-privilegiado).**
`IdentityAccess::PermissionCheck` reemplazó un resolver stub que, ante cualquier duda, otorgaba de
más. La regla ahora es la contraria: si no hay un `RoleAssignment` real que aplique, el permiso es
cero — nunca hay una persona/rol "por defecto" a la que caer de vuelta. Memoizado una vez por
request para no repetir la misma resolución en cada `authorize!`/`can?` de la misma request.
📍 `app/domains/identity_access/services/permission_check.rb`.

**El scope de identidad como el propio gate (sin RBAC).**
Para superficies "mis datos" (guardián, estudiante, staff viendo lo suyo) no hay `authorize!` ni rol
alguno de por medio: el scope mismo (`GuardianScope`, `StudentSelfScope`, `StaffProfileScope`) *es*
la autorización — filtra siempre por institución + identidad del actor + estado de vínculo activo,
nunca por un parámetro de búsqueda. Un guardián con cero `RoleAssignment` igual llega a los datos de
su propio hijo; un estudiante fuera de su alcance da 404, no un registro vacío ni un error.
📍 `app/domains/core/services/access/guardian_scope.rb`,
`.../staff_profile_scope.rb`, `.../student_self_scope.rb`.

**Strategy por variante (`Strategy.for(kind)`) para no bifurcar el pipeline entero.**
`RosterImport::{Parser,Validator,Committer}` son agnósticos de "tipo de carga" (alumno vs.
guardián); solo `Strategy.for(kind)` decide las diferencias reales (columnas esperadas, qué hace
"duplicado", si crea `Core::User` o no). Evita que cada orquestador tenga un `if kind == ...` propio
y permite agregar un tercer kind sin tocar los tres orquestadores.
📍 `app/domains/core/services/roster_import/strategy.rb`.

---

## 4. Arquitectura de código

**Bounded contexts sin framework (Zeitwerk "colapsado").**
`app/domains/<dominio>/` actúa como raíz de autoload propia; Zeitwerk colapsa las carpetas
intermedias (`models/`, `services/`, etc.) para que el nombre de la constante sea
`Dominio::Clase`, no `Dominio::Services::Clase`. Da separación por dominio sin necesitar una gema
como Packwerk.
📍 `config/application.rb`, sección de autoload.

**RBAC con alcance explícito (rol + scope).**
En vez de un booleano "es admin sí/no", cada asignación de rol lleva columnas explícitas de alcance
(`scope_department_id`, `scope_group_id`, etc.) en vez de una asociación polimórfica genérica — más
verboso, pero grep-eable y sin la magia de `belongs_to :scopeable, polymorphic: true`.

**Catálogo de permisos granular (`recurso.acción`).**
Claves tipo `teacher.evaluate`, `roles.manage`, `people.manage` en vez de roles monolíticos.
Permite separar capacidades que en la vida real son de personas distintas (un registrador puede
invitar personas sin poder otorgar rol de admin).

**Supervisión (RBAC + scope) vs. autoservicio (identidad) — la frontera que separa TODA vista de
una persona.**
*Qué es.* Dos superficies de lectura que pueden mostrar EXACTAMENTE las mismas tablas pero por
caminos de acceso opuestos, y nunca se mezclan. **Autoservicio** ("mis datos", `/mis_datos`, los
portales de estudiante/acudiente) muestra lo que el actor **posee o le pertenece** — se resuelve por
identidad (un `Core::Access::*Scope` explícito ES la puerta; ver el concepto de scope de identidad,
arriba), **nunca** pasa por `authorize!`, y **nunca** vive en `Navigation::Registry`. **Supervisión**
(`teacher_management`, `staff_management`, y los seis dominios de negocio que vienen) muestra a
**otras personas** dentro del alcance RBAC del actor — SIEMPRE pasa por `authorize!` + el scope del
`role_assignment` vigente, y SIEMPRE vive en el registry (filtrado por `can?`).
*Por qué son dos mecanismos, no uno con un parámetro.* Mezclarlos invierte el fail-closed: un
autoservicio gateado por permiso dejaría a un staff con cero `RolePermission` (normal, ver
`Core::Access::StaffProfileScope`) sin ver ni su propio perfil. Una supervisión gateada solo por
identidad dejaría a cualquiera ver a cualquiera, porque "soy yo" no es una pregunta de alcance sobre
terceros.
*Ejemplo canónico de que conviven sin pisarse.* `teacher_management`/`staff_management` desde
v1.13.0: `/mis_datos` lee `StaffManagement::StaffMember`/`Department` por identidad (self-scope, sin
`authorize!`); `/teacher_management/teachers` y `/staff_management/staff` leen las MISMAS tablas por
RBAC + scope (`TeacherScope`/`StaffScope`, con `authorize!` al inicio). Ningún dato nuevo, ningún
modelo nuevo — solo dos query objects distintos sobre el mismo dato, cada uno con su propia puerta.
*Invariante.* Si una vista de autoservicio muestra a alguien que no es el actor, se salió del
autoservicio (es supervisión, backlog #4). Si una vista de supervisión no tiene `authorize!` al
inicio de la acción, es un bug, no una superficie de identidad disfrazada.
📍 `app/controllers/self_service_controller.rb` (autoservicio) vs.
`app/controllers/teacher_management/teachers_controller.rb` +
`app/controllers/staff_management/staff_controller.rb` (supervisión).

**Molde de vista de negocio por dominio (#4, PROJECT_STATE.md §6.6): índice-con-scope → show →
acción gateada per-row.**
*Qué es.* La forma concreta y ya construida (no solo teórica) de los cinco esqueletos de §6.5,
fijada la PRIMERA vez sobre `teacher_management` para que los otros seis dominios de #4 la copien
sin reinventarla: (1) un query object de índice — relation real filtrada por `institution_id`
explícito + `context.can?(permiso, fila)` fila por fila vía `.select`, nunca `default_scope`; (2)
un controller con `authorize!(permiso[, recurso])` al inicio de CADA acción — la puerta dura; (3)
`can?` solo cosmético en la vista (mostrar/ocultar un botón, nunca proteger); (4) pestañas de un
`show` gateadas por permiso cuando aplica (la pestaña se muestra, la ACCIÓN dentro se oculta); (5)
auto-registro de la entrada de nav en un archivo propio del dominio (`config/navigation/<dominio>.rb`),
nunca editando un partial central.
*Por qué per-row `can?` y no `PermissionCheck#scope_for`.* Ambos son equivalentes (§6.3) —
`scope_for` existe como un seam para que un dominio lo adopte si quiere evitar cargar cada fila, pero
ningún dominio lo consume todavía. Este molde fija per-row como el "aburrido" a copiar
precisamente porque YA estaba probado (`TeacherScope` original, contra el stub) — cambiar de patrón
Y de fuente de datos en el mismo slice habría sido dos riesgos a la vez.
*Dónde se prueba primero y por qué.* `teacher_management` es el ÚNICO dominio con descriptor de
scope real desde P1 (el caso de aceptación de María, §6.4) — probar el molde donde lo difícil
(el scope real) ya funciona, antes de portarlo a dominios cuyo catálogo de recursos sigue en stub.
*Invariantes.* (1) El resource pasado a `can?`/`authorize!` debe responder a los lectores de
`Authorization::Assignment::SCOPE_READERS` (`department_id`/`group_id`/`grade_level_id`/`route_id`)
— si el dato real no tiene esa columna, se expone vía `delegate ... allow_nil: true` a quien sí la
tenga (nunca se inventa una columna nueva). (2) Un recurso "no vinculado" (nil en el delegate) nunca
matchea un scope específico — solo un grant institución-wide lo cubre; es un estado normal, no un
error. (3) Una acción sin modelo destino real (p. ej. `teacher.evaluate` sin `Evaluation`) se cablea
como GATE real primero — el workflow/CRUD es un slice aparte, nunca se bloquea el gate esperando el
modelo.
📍 `app/domains/teacher_management/queries/{teacher_scope,department_scope}.rb`,
`app/domains/staff_management/queries/staff_scope.rb`,
`app/controllers/teacher_management/*`, `config/navigation/{teacher_management,staff_management}.rb`.

**Staff generalizado / docente como especialización (D1, no D2).**
*Qué es.* Un solo hogar de datos para TODO el personal (`StaffManagement::StaffMember`: empleo,
número de empleado, categoría, departamento, tipo de vinculación), y el docente NO es un dominio
aparte sino una **especialización opcional** de ese registro: `TeacherManagement::Teacher` agrega
las columnas exclusivamente docentes (`teacher_code`, `faculty`, `teaching_assignments`) y se liga a
su `StaffMember` vía un FK **nullable, aditivo** (`teachers.staff_member_id`) — no una jerarquía STI,
no una tabla por categoría de personal.
*Por qué D1 (generalizar) sobre D2 (dominio HR aparte).* Cocina/transporte/mantenimiento/seguridad/
administración comparten el 90% de sus atributos con un docente (institución, número de empleado,
tipo de vinculación, estado, departamento) — modelarlos como un dominio de RR.HH. totalmente
separado habría duplicado ese 90% y obligado a decidir, ARTIFICIALMENTE, en cuál de los dos dominios
vive cada permiso/reporte que toque "cualquier miembro del staff" (p. ej. el autoservicio "mis
datos", que no le importa si sos docente o no). Generalizar con el docente como caso particular deja
un solo lugar para esa pregunta.
*Cómo se modela el discriminador.* `staff_members.staff_category` (`teaching|kitchen|transport|
maintenance|security|admin|other`, `CHECK` constraint) distingue el TIPO de empleo; la presencia (o
no) de una fila `teachers` con `staff_member_id` apuntando de vuelta es lo que distingue si además
tiene la extensión docente. `departments.kind` (`academic|operational`) generaliza igual de lejos:
un departamento no tiene por qué ser una materia académica. `staff_members.department_id` es
**nullable** a propósito — el personal no académico no tiene por qué tener un departamento asignado.
*Relación con RBAC y con `StaffProfileScope`.* El catálogo de roles (`cafeteria_staff`,
`transport_coordinator`, `driver`, `teacher`, …) y sus `role_assignments` no cambian en nada por
esto — siguen siendo el mecanismo real de "qué puede hacer" y "sobre qué alcance". Lo que este
modelado resuelve es "de quién es el registro de empleo", que es una pregunta *distinta* de RBAC.
`Core::Access::StaffProfileScope` (v1.10.0) es el punto donde esto se vuelve visible: lee
`StaffManagement::StaffMember` directamente y nunca `Teacher`, así que un docente y un no-docente se
resuelven exactamente igual — la especialización docente es un detalle que el autoservicio ni
necesita mirar.
*Invariantes.* (1) El link `teachers.staff_member_id` es **opcional en ambos sentidos**: un
`StaffMember` puede no tener extensión docente (la mayoría del personal), y un `Teacher` puede no
tener el link poblado todavía (transición aditiva, sin backfill forzado) — ninguno de los dos casos
es un error, son estados normales. (2) Nunca forzar `department_id` `NOT NULL` para "arreglar" un
reporte que asuma que todo el staff tiene departamento académico — el nullable es el invariante, no
un descuido. (3) No inventar una migración de "generalizar staff" sin antes verificar si ya existe
esta forma — este concepto se cerró en `HISTORIA.md` v1.12.0 (CHECKPOINT E) precisamente porque el
recon encontró que ya estaba construido desde el primer commit del repo, antes incluso del track de
onboarding.
📍 `app/domains/staff_management/models/staff_member.rb`,
`app/domains/teacher_management/models/teacher.rb`,
`db/migrate/20260706000001_create_staff_management.rb`,
`db/migrate/20260706000002_link_teachers_to_staff_members.rb`,
`app/domains/core/services/access/staff_profile_scope.rb`.

---

## 5. Postgres específico

**UUIDv7 como PK.**
A diferencia de UUIDv4 (aleatorio puro), UUIDv7 lleva un componente de timestamp al inicio, así que
los IDs son ordenables por tiempo de creación — mejor localidad de índice (menos fragmentación de
B-tree) que UUIDv4, sin perder las ventajas de un UUID (generable sin coordinación central, no
filtra conteo de filas como un serial).

**`schema_format = :sql` (structure.sql en vez de schema.rb).**
Necesario porque el DSL Ruby de `schema.rb` no puede expresar políticas RLS, `CHECK` constraints
con nombre, ni roles/grants — solo un volcado SQL crudo los captura.

**Índices únicos parciales (`WHERE ...`).**
Ej.: "un solo término activo por institución", "una invitación viva por persona" — la unicidad no
es sobre toda la tabla, solo sobre el subconjunto de filas que importa.

---

## 6. Testing y operación

**Bases de datos separadas por `RAILS_ENV`.**
`development` y `test` son bases físicamente distintas; migrar una no migra la otra.

**Separación de credenciales por entorno vía ENV, nunca en el repo.**
`EDU_MIGRATOR_PASSWORD` no vive en ningún archivo versionado.

---

## Ver también

- `PROJECT_STATE.md` — estado actual del proyecto: qué está construido, qué falta, bordes abiertos.
