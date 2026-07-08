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
