# edu_platform — Estado del proyecto (magro)

> **Qué es este documento.** La **fuente única de verdad del contexto vivo** del proyecto
> `edu_platform`: invariantes decididos, estado de lo construido, bordes abiertos, backlog y
> guardrails. Es el que se lee/pega cada iteración para decidir el próximo slice.
>
> **Split editorial (v1.5.1):** este doc solía cargar también el changelog completo y las
> narrativas de "cómo se construyó" cada pieza — eso ahora vive en **`HISTORIA.md`** (archivo
> append-only, hermano de este archivo), y se carga solo cuando hace falta el *por qué* de algo.
> Aquí solo queda lo que se necesita para decidir qué sigue.
>
> **El repositorio sigue siendo la fuente de verdad del código.** Ante discrepancia entre lo escrito
> aquí y lo que hay en disco, gana el repositorio, y se corrige este documento en la siguiente versión.

---

## Metadatos de versión

| Campo | Valor |
|---|---|
| **Versión del documento** | `v1.9.0` |
| **Fecha** | 2026-07-10 |
| **Tests** | 342 runs / 0 fallos / 1 skip preexistente (suite completa, en serie — ver Guardrails) |
| **Estado en una línea** | Identidad real (login+MFA, invitaciones, gestión de personas, alta batch de estudiantes Y acudientes por CSV) + plano de control con track de billing completo S0→S4 + RBAC del inquilino real (`IdentityAccess::PermissionCheck`, P1 cerrado) + `Core::RosterImport` real para ambos kinds + **`Core::Access::GuardianScope` real + portales de acudiente/estudiante sobre datos reales de relación** (siguiente: vistas de autoservicio docente/coordinador/director + visor de auditoría — ver `HISTORIA.md`). |

### Convención de versionado de ESTE documento

- **MAJOR** (`vX.0.0`): cambia una decisión de arquitectura asentada (tenancy, modelo de identidad, planos), o se reestructura el mapa de dominios.
- **MINOR** (`v1.X.0`): se cierra una iteración (se implementa un módulo/dominio), se resuelve un borde abierto, o se añade un dominio/plano.
- **PATCH** (`v1.0.X`): correcciones, aclaraciones, ajustes de redacción, reconciliación con el repo, reorganización editorial.

Cada cambio de código se registra en el **Changelog de `HISTORIA.md`**. Nunca se borra historia: las decisiones revertidas se marcan como *supersedidas*, no se eliminan.

---

## 1. Resumen ejecutivo

`edu_platform` es un **SaaS educativo multi-tenant** (K-12 y educación superior) construido como
**monolito Rails 8 vanilla**, optimizado sin piedad para un **desarrollador solo que lo mantendrá
por años**: código aburrido, explícito y greppable sobre abstracciones ingeniosas. Filosofía
37signals. Se agota PostgreSQL nativo + Rails nativo antes de proponer cualquier herramienta externa.

El sistema tiene **dos planos** con reglas de seguridad opuestas:

- **Plano de inquilino** (la app del colegio): dominios de negocio scoped por `institution_id` bajo RLS.
- **Plano de control** (panel de plataforma): cross-tenant, por encima de RLS, solo super-admin — catálogo de addons, entitlements y billing por uso.

Una institución "enciende" dominios comprando addons (entitlement), y dentro de ella el acceso se
resuelve por **RBAC con scope** (rol + alcance). Son dos compuertas **en serie**: primero *¿la
institución puede?* (`entitled?`, real desde S2b), luego *¿el usuario dentro puede?* (`authorize!`,
real desde P1, `IdentityAccess::PermissionCheck`). **Ambas compuertas son reales.**

---

## 2. Stack bloqueado (no sustituir)

| Capa | Elección | Notas |
|---|---|---|
| **Ruby** | 4.0.x con **YJIT** | ZJIT es experimental — **NO usar ni depender de él**. |
| **Rails** | 8.1.x | Autenticación **nativa** de Rails 8 (`has_secure_password`, `Session`, concern `Authentication`, `Current`). **Sin Devise.** **Ya implementada.** |
| **PostgreSQL** | 18 GA | Nativo: `uuidv7()`, RLS + FORCE, `WITHOUT OVERLAPS`, `UNIQUE NULLS NOT DISTINCT`, JSONB, FTS nativo, pgvector. **Sin extensiones para UUID.** |
| **Async / cache / cable** | Solid Queue / Solid Cache / Solid Cable | **Sin Redis, sin broker, sin Sidekiq, sin Elasticsearch.** Correos ya van por Active Job sobre Solid Queue (`deliver_later` en `OtpMailer`/`InvitationMailer`); importación pesada (roster) todavía no existe. |
| **Front-end** | Propshaft + importmap (sin Node/build), turbo-rails + stimulus-rails, CSS vanilla con `tokens.css` y `@layer` | **Sin Tailwind, sin Sass, sin gema de componentes, sin icon-font.** |
| **Tests** | Minitest (default) | **Sin RSpec.** |
| **Autorización** | RBAC casero sobre PG | **Sin Pundit / CanCan / rolify.** `IdentityAccess::PermissionCheck` es el resolver real (P1, cerrado) — real-only, fail-closed: sin `RoleAssignment` que aplique, cero permisos. |
| **Eventing cross-dominio** | In-process (`ActiveSupport::Notifications` / bus liviano en app + service objects en los bordes) | **Nunca** un broker distribuido. |

> **PK universal:** UUID vía default de columna PG18 `default: -> { "uuidv7()" }`. Los IDs legibles de
> negocio (`student_code`, etc.) son columnas aparte, tenant-scoped, con unique compuesto.
> Soft-delete vía `deleted_at` donde ya se use. `institution_users` usa en cambio `status`
> (`active`/`suspended`, CHECK en BD) en lugar de soft-delete — una membresía suspendida sigue
> existiendo y siendo auditable, no desaparece.

---

## 3. Arquitectura asentada (verdad de base — construir encima, NO reabrir)

### 3.1 Tenancy — row-level (shared-schema)

- Toda tabla tenant-owned lleva `institution_id`.
- **RLS es el backstop de BD** (`ENABLE` + `FORCE ROW LEVEL SECURITY`, para que muerda incluso al owner de la tabla).
- El **scoping primario** es explícito en Rails vía **Query objects / `Tenant::Resolver` + `Tenant::Guc`** (nombres reales en el repo — no `CurrentTenant`), **NUNCA `default_scope`**.
- Predicado RLS: `institution_id = current_setting('app.current_institution_id')::uuid`, con `WITH CHECK` gemelo en INSERT/UPDATE.
- El GUC se fija con `SET LOCAL` dentro de una transacción por request (`TenantScoped#within_tenant`, `around_action`) o por job (`ApplicationJob#around_perform`, con `Tenant::Guc.reset!` explícito — ver Guardrails).
- Existe un **seam de resolución de tenant** (`Tenant::Resolver::SubdomainStrategy`, para futuro sharding horizontal). El sharding en sí **NO** se construye (YAGNI a escala solo-dev).

### 3.2 Identidad — global, multi-institución

- `institutions` y `users` son **GLOBALES** (sin RLS). Todo lo demás tenant-owned es **tenant-scoped**.
- **Una persona = un `users`** (login único por `email`, `citext`, único global); puede pertenecer a varias instituciones vía `institution_users`. Confirmado y en producción de código (⚠-1, cerrado — ver `HISTORIA.md`).
- Resolución de tenant **por subdominio** (`institutions.slug`), vía `Tenant::Resolver`.
- `student` y `guardian` son **entidades-persona, NO roles RBAC**. Su acceso se resuelve por **relación** (`students.user_id`, `guardian_students`), no por `role_assignments`. Un menor de K-12 puede existir sin `user_id`; un acudiente siempre tiene login (⚠-2, cerrado — ver `HISTORIA.md`). La tabla `guardian_students` real ya existe (dominio `core`), en paralelo a la legacy `student_support.student_guardians` (ambas coexisten a propósito; no se migró la legacy). **Confirmado en v1.8.0:** la membresía `institution_users` de un acudiente no es opcional/cosmética — `SessionsController#authenticate_credentials` exige `user.memberships.active.exists?(institution_id:)` para autenticar, así que sin ella un acudiente no podría loguear ni después de completar su invitación. `Core::People::Resolver` la crea; **cero `role_assignments`** siempre (un acudiente no es staff).

### 3.3 Roles de Postgres y realidad operativa de BD

- **`edu_app_runtime`** — sirve la app. `NOSUPERUSER`, **sin `CREATE`** en `public`, **sin `BYPASSRLS`**.
- **`edu_migrator`** — corre migraciones. Tiene `CREATE`. Debe tenerlo en **todas** las bases (primaria **y** las tres Solid: cache/queue/cable).
- **`edu_bi_reader`** (rol auditado) — **único** rol con `BYPASSRLS`; solo para lecturas cross-tenant de super-admin / BI (nombre real en `lib/tasks/roles.rake`). **El runtime nunca hace lecturas cross-tenant.**
- **Migraciones corren con `bin/migrate`** (que exige `EDU_MIGRATOR_PASSWORD` no vacío), **NO** con `rails db:migrate` (cuidado: conecta con el rol runtime, sin `CREATE`, y falla).
- `schema_format = :sql`. Las bases Solid se pueblan por *schema load* desde `db/*_structure.sql` (no tienen carpeta de migraciones).
- Ver Guardrails (§13) para los gotchas operativos durables (`EDU_MIGRATOR_PASSWORD`, migrar dev vs. test, timestamps de migración).

### 3.4 Estructura de código — bounded contexts sin Packwerk

`app/domains/<dominio>/` es autoload root. Zeitwerk **colapsa** `app/domains/*/{models,queries,services,jobs,policies}` (ver `config/application.rb`), así que la capa intermedia NO aparece en el nombre de la constante:
- `app/domains/core/models/user.rb` → `Core::User` (no `Core::Models::User`).
- `app/domains/identity_access/services/otp/issuer.rb` → `IdentityAccess::Otp::Issuer`.
- `app/domains/core/services/people/resolver.rb` → `Core::People::Resolver`.

Librería de componentes compartidos en `app/views/shared/`; se **reutiliza antes de crear local** y se **promueve a `shared/` cuando un componente se usa en ≥2 dominios**.
El **plano de control vive FUERA de `app/domains/*`** — namespace propio `app/control_plane/`, montado en `/control_plane`, con su propio layout y auth real (`platform_admins` + MFA, S0).

---

## 4. Mapa de dominios

> Un **addon = un dominio (1:1)**. La institución habilita dominios comprando addons.

### Tier A — dominios base (existentes)

| Dominio | Propósito | Posee / notas |
|---|---|---|
| `core` | Espina académica **+ identidad de personas** | `students`, matrícula (`enrollments`), acudientes (`guardian_students`), cursos, `academic_terms` (con índice de "un solo término activo"), `grade_levels`, `disciplinary_logs`. También posee `Core::User`, `Core::InstitutionUser`, `Core::Session`, `Core::People::Resolver`, y `Core::Headcount::{Snapshotter,SnapshotJob}` (S3a) — la identidad y el pipe de headcount viven aquí, no en `identity_access` ni en el control plane. Casi todo le hace FK. |
| `teacher_management` | Docentes | Perfiles, `departments` (áreas), cualificaciones. |
| `group_management` | Grupos | `groups` (`kind` homeroom/…), membresía/rosters. `students.user_id` y `students.national_id` (cifrado) viven en el modelo de este dominio (`GroupManagement::Student`). |
| `schedules` | Horarios/timetabling | Rooms, patrones de reunión. Usa PG18 `WITHOUT OVERLAPS` (doble-booking de aula/profesor). Depende de `academic_terms`. |
| `student_support` | Bienestar | Convivencia, **historia médica (dueño)**, acomodaciones. Sensible. Tabla legacy `student_guardians` coexiste con `core.guardian_students` (no migrada; ver §3.2). |
| `cafeteria` | Alimentación | Checkout con **bloqueo por alérgeno** (lee `student_support`). Wallet/saldo, transacciones idempotentes. |
| `transportation` | Rutas | Rutas, paradas, check-in/out de abordaje. Notifica a acudientes (Turbo Streams/Solid Cable — diferido). |
| `analytics_bi` | Reporting | Vistas materializadas, read models. Lectura cross-tenant **solo** por rol auditado con `BYPASSRLS` (`edu_bi_reader`); nunca runtime. Sigue en fase stub. |

### Tier B — identidad/roles

| Dominio | Propósito |
|---|---|
| `identity_access` | IAM/RBAC **+ onboarding**. Posee el catálogo global `roles`/`permissions`/`role_permissions`, `role_assignments` (tenant, scope por columnas explícitas), `invitations`, `email_otps`, `audit_events`, los servicios `Otp::*` e `Invitations::*`, `Audit`, y el controller/vistas de `people`. **No posee** `users`/`institution_users` (son de `core`); referencia por FK. |

### Tier B-bis — confirmados

| Dominio | Propósito |
|---|---|
| `counseling` | Psicoorientación. **Carve-out de `student_support`.** Casos/expedientes, sesiones/notas, remisiones, planes de intervención. Puede *leer* (no poseer) la historia médica de `student_support`. **Frontera de confidencialidad más estricta** que convivencia. |
| `finance` | Tesorería/cartera **dentro** del tenant (el colegio cobra pensiones a acudientes). Cargos, pagos, estados de cuenta, planes de pago. **≠ billing de plataforma.** Tenant-scoped. |
| `communication` | Hub de comunicación. Ver §8 (anexo). Sigue en fase stub. |

### Tier C — candidatos (crear SOLO bajo confirmación explícita)

`staff_management` **o** `human_resources` (personal no docente; **CHECKPOINT E pendiente** — ver §11) · `admissions` (pipeline aspirante→matriculado) · `library`.

### Orden de dependencias (creación / migraciones)

1. `core`, `teacher_management`, `group_management` (proveen destinos de scope).
2. `identity_access` (referencia los anteriores por FK).
3. `schedules`, `student_support`, `cafeteria`, `transportation`, `analytics_bi`.
4. `counseling` y `finance` (FK a `core`; `counseling` puede leer `student_support`).
5. `communication` (FK a `core` e `identity_access`; consume notificaciones del resto).
6. Tier C, según se confirmen.

---

## 5. RBAC — rol + scope

El rol dice **qué**; la asignación dice **sobre qué**. Toda autorización responde a:
*"¿tiene un rol que incluya este permiso **con un alcance que cubra este recurso**?"*.

### Catálogo — `permissions` global; `roles`/`role_permissions` tenant-scoped con RLS

> **Corrección P1 (v1.6.0):** el recon de P1 confirmó contra el disco que **solo `permissions` es
> global** (sin `institution_id`, sin RLS). `roles` y `role_permissions` SÍ son tenant-scoped
> (`institution_id NOT NULL` + `FORCE ROW LEVEL SECURITY`) — versiones previas de este doc los
> daban por globales. Implicación operativa: el catálogo de roles se siembra **por institución**
> (bajo GUC), no una sola vez para toda la plataforma.

- **`roles`**: `key` (slug greppable: `teacher`, `area_lead`, `academic_coordinator`, `coexistence_coordinator`, `counselor`, `dean`, `principal`, `institution_admin`, …), `name`, `system` (boolean; la columna real se llama `system`, no `is_system`). **No existe** columna `assignable_scope_types` en el esquema real — es un concepto solo del panel admin decorativo de `identity_access` (`IdentityAccess::RoleRoster`, un stub aparte del RBAC real), no algo que el motor valide.
- **`permissions`**: `key` (`teachers.view`, `teacher.evaluate`, `students.read`, `people.manage`, …), `description`. Catálogo completo en `IdentityAccess::SeedPermissions::CATALOG` — este SÍ es global.
- **`role_permissions`**: relaciona `role_id`+`permission_id`, tenant-scoped (ver arriba), `ON DELETE CASCADE`.

### Asignaciones — TENANT-SCOPED, con RLS

- **`role_assignments`**: el corazón del scope. Columnas de alcance **explícitas** (no polimórfico, pero **SÍ con FK real** a `departments`/`grade_levels`/`sections` respectivamente — confirmado en P1, no inventar lecturas contra ids que no correspondan a filas reales): `scope_department_id` / `scope_grade_level_id` / `scope_group_id` (las no usadas en NULL = institución-wide), `valid_from` / `valid_until` (fechado efectivo — columnas agregadas en P1, no existían antes; ver Guardrails y `HISTORIA.md`). **DECIDIDO** — no re-preguntar.

### Roles de plataforma (globales, cross-tenant)

- **super-admin** auditado y **`bi_auditor`** (solo lectura BI) — sobre el rol Postgres `BYPASSRLS`, nunca runtime.

### Catálogo de roles de staff (sobre `institution_users`)

Académicos/docentes (`teacher`, `area_lead`), coordinación (`academic_coordinator`, `coexistence_coordinator`), dirección (`principal`, `dean`), registro (`academic_secretary`, `registrar`), bienestar (`counselor`, `psychologist`, `social_worker`), clínico (`medical_staff` — dueño de historia médica), servicios (`cafeteria_staff`, `transport_coordinator`, `driver`, `route_monitor`), administración (`institution_admin`), BI (`bi_auditor`). Casi todos requieren **scope**, no rol suelto.

> `student` y `guardian` **no** están en este catálogo: son entidades-persona, acceden por portal.
> `institution_users.role` (columna string libre, default `"member"`) **no es** este catálogo RBAC —
> es un campo heredado, sin lectores en el código todavía (P2, abierto — ver §11).

---

## 6. Vistas + navegación (regla de 3 clics)

### 6.1 Principios

1. **Funcionalidad sobre estética.** Vistas aburridas, legibles, componibles con `shared/`. Cero rediseño.
2. **Regla de 3 clics.** Cualquier vista de trabajo se alcanza en **≤ 3 clics** desde el dashboard.
3. **Rol + scope, no solo rol.** Puerta dura en el controlador; reflejo cosmético en la vista.
4. **Reutilizar > reconstruir.**
5. **Multi-rol y multi-institución.** El shell resuelve institución activa + roles efectivos por request.

### 6.2 Árbol de navegación (profundidad 3)

```
CLIC 0  Dashboard (landing por rol)   → tiles SOLO de dominios que el rol permite y la institución tiene entitled
CLIC 1  Índice de dominio             → ya pre-filtrado por scope
CLIC 2  Registro (show)               → una entidad
CLIC 3  Detalle / acción              → pestaña del show o formulario
```

Piezas transversales (ya construidas): barra de navegación por rol + entitlement (si no hay
permiso del dominio o el addon no está habilitado, el tile **desaparece** — no "deshabilitado"),
selector de institución, selector de "actuando como" (opcional), dashboard por rol (2–5 atajos),
buscador global acotado por scope, portales de persona (student/guardian, **ahora sobre datos
reales de relación** vía `Core::Access::GuardianScope`/`StudentSelfScope`, v1.9.0 — sin
`authorize!`, gateados por relación, no por RBAC), vista **403 amable** (RBAC) y página
**"módulo no habilitado"** (entitlement, distinta del 403).

**Capa PRE-login:** layout separado (`layouts/auth`, sin nav de dominio ni selector de institución)
para `sessions/`, `email_otps/`, `invitations/`, y como fallback cuando la página de entitlement
dispara sin `Current.institution` resuelta — deliberadamente minimalista.

### 6.3 Las dos compuertas en serie

**Compuerta #1 (entitlement) — real de punta a punta desde S2b.** `Entitlement::Controller`
(concern único, incluido una vez en `ApplicationController`) corre un `before_action` que consulta
`Current.entitled_addon_keys` (memo por request sobre `Core::Institution#entitled?` →
`ControlPlane::Entitlements::Check`) y corta con la página "módulo no habilitado" **antes** de que
la acción llegue a `authorize!`. Ver §7.1 para el detalle del mecanismo.

**Compuerta #2 (RBAC) — real (P1, cerrado).**
- **`IdentityAccess::PermissionCheck`** (`app/domains/identity_access/services/permission_check.rb`): resuelve *"¿puede U ejecutar A sobre R?"* con scope, una vez por request (memoizado). Lee `role_assignments` reales (vigentes, `.effective_now`) → `roles` → `role_permissions` → `permissions`. **Real-only, fail-closed**: sin `RoleAssignment` aplicable, cero permisos — no hay fallback a ninguna persona stub.
- **`can?(permission, resource = nil)`** (helper de vista): mostrar/ocultar acciones — **solo cosmética**.
- **`authorize!(permission, resource)`** (concern de controlador, `Authorization::Controller`): **puerta dura, llamada a mano al inicio de cada acción** — la que protege de verdad. Resuelve siempre contra `IdentityAccess::PermissionCheck` (el seam ya tenía el `if defined?` esperando; el fallback a `Authorization::StubResolver`/`StubAssignments` queda muerto en runtime, confirmado con `rails runner`).
- Los índices filtran por **Query object de scope**, nunca `default_scope`. `PermissionCheck#scope_for` existe para que un dominio filtre directo (en vez de recorrer+`can?` fila por fila), pero su adopción es **incremental por dominio** — ningún dominio lo consume todavía; `teacher_management` sigue con el patrón per-row `can?`, igual de válido.

### 6.4 Matriz rol × dominio y caso de aceptación de referencia

La matriz completa rol×dominio vive en `HISTORIA.md` (referencia estable, no cambia seguido).
Caso de aceptación que la valida end-to-end: `teacher_management`, **real desde P1** (antes probado
solo contra la persona stub). María = `(teacher, group:10-A)`, `(teacher, group:11-B)`,
`(area_lead, department:Matemáticas)`, sembrada como `role_assignments` reales.
`authorize! teacher.evaluate` = **sí** sobre un docente de Matemáticas, **no** sobre uno de
Sociales; y no ve al resto de la institución. El descriptor de scope (recurso expone
`department_id`/`group_id`) solo se cableó de verdad en `teacher_management` — el resto de dominios
sigue con su catálogo de recursos en stub (backlog #4), aunque ahora las ASIGNACIONES que los
autorizan ya son reales en todos los dominios probados (ver `HISTORIA.md` v1.6.0).

### 6.5 Patrones canónicos (la "convención de la casa")

Cinco esqueletos que hacen converger a todos los dominios: (1) Query object de índice con scope,
(2) controlador con `authorize!` al inicio, (3) gating con `can?` en vista, (4) pestañas gateadas por
permiso, (5) auto-registro de navegación en archivo propio del dominio (no editar un partial central).

---

## 7. Plano de control · addons, entitlements y billing de plataforma

> **No es un dominio.** Vive en `app/control_plane/` (fuera de `app/domains/*`), cross-tenant, por
> encima de RLS. **Billing de plataforma ≠ dominio `finance`**: aquí la plataforma cobra al colegio;
> en `finance` el colegio cobra a los acudientes. Servido por el rol runtime normal
> (`edu_app_runtime`), **sin `BYPASSRLS`** — estas tablas son globales y no necesitan cruzar tenants
> para leerse. **Track de billing completo (S0→S4)** — pendiente solo emisión real de uso por
> dominio (S3b, requiere M1) y riel de pago (fuera de alcance de v1).

### 7.1 El gate de entitlements (dos compuertas en serie)

1. **Entitlement** (control plane): *¿la institución PUEDE usar este dominio?* → contrato/plan.
2. **RBAC con scope** (`identity_access`): *¿el usuario DENTRO puede?* → rol + alcance.

**Real de punta a punta desde S2b — con datos reales, no solo diseño.** El punto único de
verificación es `Core::Institution#entitled?(addon_key)` (delega en
`ControlPlane::Entitlements::Check` de S2a); `Current.entitled_addon_keys` lo memoiza una vez por
request (`Core::Access::EntitledAddonKeys.for(institution)`). Del lado del inquilino, **una sola
pieza** — el concern `Entitlement::Controller`, incluido una vez en `ApplicationController` — infiere
el `addon_key` del namespace del controller y corta con la página "módulo no habilitado" **antes**
de que la acción llegue a `authorize!`; la nav (`ApplicationHelper#nav_items`) filtra por el mismo
memo antes de aplicar el `can?` cosmético existente. Los fundacionales (`core`,
`teacher_management`, `group_management`, `identity_access`) **nunca** pasan por este gate — su
ausencia de `Entitlement::Registry` (declaración tenant-side propia, `config/entitlements/*.rb`, un
archivo por dominio addon-gated) ES la señal de "no gateado", sin necesitar una lista aparte.
`Entitlement::Registry` **no referencia `ControlPlane::AddonCatalog::DOMAIN_KEYS` en runtime** — solo
un test (`test/models/entitlement/registry_consistency_test.rb`) cruza ambas listas para atrapar
drift. El código de cada dominio no se ramifica — se enciende/apaga por institución desde un solo
lugar. **Gate #2 (RBAC) es real desde P1** (`IdentityAccess::PermissionCheck`) — **ambas compuertas
son reales**; orden #1→#2 verificado intacto (`entitlement_gate_test.rb`).

### 7.2 Estado de las piezas (tabla de estado)

| Pieza | Slice | Estado | Invariante clave |
|---|---|---|---|
| `platform_admins` (+ MFA propio) | S0 | ✅ Real | Aparte de `Core::User`, no un flag. MFA (`ControlPlane::Otp::*`) independiente de `IdentityAccess::Otp::*`. |
| `addons` | S1 | ✅ CRUD real | 1 addon = 1 dominio addon-able (F14); `ControlPlane::AddonCatalog::DOMAIN_KEYS` es la lista canónica; retiro suave, nunca hard-delete. |
| `plans` / `plan_price_tiers` | S1 | ✅ CRUD real | Tarifa base por alumno + tiers hijos explícitos (no JSONB); sin FK a `addons` (F9); pricing no se aplica a nada hasta que se firma una subscription. |
| `subscriptions` | S2a | ✅ CRUD real | **Snapshot inmutable** al firmar (`price_tiers_snapshot` jsonb + escalares) — nunca re-lee el catálogo vivo después; una activa por institución; `institution_id` FK global, no tenancy. |
| `institution_entitlements` (`ControlPlane::Entitlement`, no `InstitutionEntitlement`) | S2a | ✅ CRUD real | Overrides negociados **almacenados** (aplicados recién en S4); un activo por institución+addon; retirar un addon con entitlements activos se bloquea (F10-bis). Predicado: `ControlPlane::Entitlements::Check.entitled?`. |
| Gate de entitlement en el inquilino | S2b | ✅ Real | Ver §7.1 — `Entitlement::Controller` + `Entitlement::Registry` + nav filtrada. Único touch histórico en `app/domains/*` fue en `core`. |
| `student_headcount_snapshots` | S3a | ✅ Real | Empujado por el tenant bajo su propio GUC (`Core::Headcount::SnapshotJob`, hereda `ApplicationJob`), nunca leído en vivo por el control plane. Cuenta `students.status == "active"` — **no** matrícula en término activo (limitación conocida, ver Guardrails). Un snapshot por `(institution, as_of_date)`. |
| `usage_events` / `usage_daily_rollups` | S3a | ✅ Pipe real, sin emisión | `ControlPlane::Usage::Ingest` idempotente (no-op en duplicado), exige `metered: true`, no exige entitlement activo. `RollupJob` idempotente (recomputa, nunca incrementa). Sin GUC (tablas globales). **Ningún dominio emite eventos reales (S3b, requiere M1).** |
| `invoices` / `invoice_line_items` | S4 | ✅ Corte real | `ControlPlane::Billing::PeriodCut` produce factura **borrador**, nunca auto-emitida; aplica overrides (`coalesce`) y el snapshot congelado por primera vez; idempotente (re-cortar un draft reemplaza líneas vía `delete_all`, que bypasea a propósito el `readonly?` de `InvoiceLineItem`); rechaza sin subscription activa (H9) o sobre una factura `finalized`. Sin GUC. **Finalizar ≠ cobrar** — no hay riel de pago en v1. |

> El detalle narrativo de "cómo se construyó" cada pieza (decisiones H1–H9, F-numeradas, bugs
> encontrados durante el desarrollo) vive en `HISTORIA.md` → Changelog + "Narrativa detallada: modelo
> de datos del plano de control".

### 7.3 Modelo de cobro: híbrido

**Implementado desde S4.** Tres piezas ortogonales: **base por alumnos** (`base_seats`) + **fee por
addon** (`addon_fee`) + **overage por uso** (`usage_overage`). El **corte de periodo**
(`ControlPlane::Billing::PeriodCut`, invocable manual/rake vía `ControlPlane::Billing::PeriodCutJob`
— schedule recurrente diferido) produce una **factura borrador** (`draft`) para revisión humana —
**nunca auto-emitida**. Finalizar (`Invoice#finalize!`) es una acción manual y auditada de
`platform_admin`; **finalizar ≠ cobrar** — no existe riel de pago en v1. Las líneas de
`usage_overage` dan cero/ausentes hoy porque `usage_daily_rollups` está vacío hasta que S3b cablee
emisión real por dominio — la maquinaria del corte ya está completa y probada con rollups
sintéticos.

---

## 8. Dominio `communication` (anexo de diseño — stub)

Dos facetas que no se aplanan: **comunicación humana** (persona↔persona) y **notificaciones del
sistema** (sistema→persona). Borrador de tablas (tenant-scoped, RLS): `conversations` (`kind` ∈
direct/channel/parent_thread/announcement), `conversation_participants` (institution_user **o**
guardian, patrón exactamente-uno), `messages` (con hilos), `tags`/`taggings`, `mentions`, y la
faceta de notificaciones (`notifications`, `notification_preferences`, plantillas).

**Colisión de nombres a evitar:** *canales de discusión* (Slack-like) vs. *canales de entrega* de
notificaciones (in-app/email/push) — nombrar distinto (`_channel_*` vs `_delivery_channel_badge`).
**Tiempo real (Turbo Streams/Solid Cable) diferido.** Los correos de OTP e invitación **no** pasan
por este dominio — van directo por `ApplicationMailer`/Active Job; centralizar todo envío saliente
aquí sería una decisión de arquitectura nueva, no asumida hoy.

---

## 9. Módulo de autenticación / onboarding

> Principio rector: **una cuenta debe corresponder de forma verificable a un ser humano real**
> (mitigación de ciberacoso, cuentas de desecho, datos de menores).

**Qué existe (real, no solo diseñado):** nadie se autorregistra — la institución crea los registros
(`Core::People::Resolver`) y la persona completa su cuenta vía invitación
(`IdentityAccess::Invitations::Completer`); login nativo Rails 8 + MFA por correo (OTP,
rate-limited, anti-enumeración, lockout a 5 intentos); auditoría append-only real a nivel de rol de
BD (`REVOKE UPDATE/DELETE`); gestión de personas (crear/invitar/reenviar/suspender/reactivar) con
permiso `people.manage`; suspensión con efecto real (bloquea login y quita grants en la siguiente
request); `national_id` cifrado determinísticamente en ambos lados (`Core::User` global,
`GroupManagement::Student` tenant-scoped) como identificador de *alcance*, nunca credencial.
Detalle completo de cómo se construyó (⚠-1/⚠-2 cerrados, el gotcha de `has_secure_password`, la
tabla pieza-por-pieza) en `HISTORIA.md`.

### 9.1 Pendiente real (no implementado, no solo "vista futura")

1. ~~`Core::RosterImport::Parser` / `Validator` / `Committer`~~ — ✅ **real para AMBOS kinds**
   (estudiantes v1.7.0, acudientes v1.8.0 — ver `HISTORIA.md`). Estructura por-kind (G7):
   `Core::RosterImport::Strategy.for(kind, institution:)` → `Strategies::{Students,Guardians}`;
   `Parser`/`Validator`/`Committer` son kind-agnósticos, nunca ramifican. Estudiantes: upsert
   DIRECTO de `GroupManagement::Student` por `national_id`, sin `Core::People::Resolver` (ese
   resolver crea `Core::User`, un estudiante K-12 normalmente no tiene login). Acudientes: **sí**
   vía `Resolver` (crea `Core::User` + membresía `institution_users`, **cero `role_assignments`** —
   un acudiente no es staff) + `find_or_create` aditivo del link `guardian_students` (nunca borra un
   link ausente del CSV). Ninguna migración fue necesaria en ninguno de los dos slices.
2. ~~`Core::Access::GuardianScope`~~ — ✅ **cerrado (v1.9.0)**. Portales de estudiante/acudiente
   cableados a datos reales de relación (`GuardianScope`/`StudentSelfScope`); los stubs
   `Portals::{Guardian,Student}Dashboard` se eliminaron. Caso de aceptación de seguridad (cross-
   tenant + revocados + sin buscador) verificado end-to-end — ver `HISTORIA.md`.
3. **Vistas de "mis datos" con datos reales** para docente/coordinador/director sobre el término
   activo (estudiante/acudiente ya quedaron resueltos en el ítem 2). Lo construido es superficie de
   administración y auth compartida, no autoservicio de esas otras personas ya autenticadas. **Ahora
   el pendiente inmediato del track de onboarding.**
4. **Visor de `audit_events`** + **bandeja de discrepancias reportadas**. Los datos ya se escriben;
   no existe ninguna vista que los liste. Pieza más barata de construir de las que faltan —
   `shared/_audit_entry_row` ya existe.
5. **`IdentityAccess::Expirer`/`BounceHandler` sin disparador real** — `Expirer` corre
   oportunísticamente desde `PeopleController#index` (no hay job recurrente en Solid Queue);
   `BounceHandler` no está conectado a ningún webhook real. (`Resender` no se construye — `Issuer`
   ya invalida-y-recrea.)
6. **`IdentityAccess::PermissionCheck` real** — ✅ **cerrado** (P1, v1.6.0) — ver `HISTORIA.md`. Nota
   operativa: cada persona nueva creada vía `PeopleController` necesita `RoleAssignment` reales para
   tener acceso (ya no hay persona stub que la cubra por defecto) — el punto de extensión para
   asignar rol al crear persona **no se construyó** (follow-up señalado, no bloqueante hoy porque
   `PeopleController` sigue siendo el único camino de alta y es un flujo manual/administrado).
7. **Job de Solid Queue que reestablece el GUC de tenant** — ✅ **cerrado**, primer caso real en
   S3a (`Core::Headcount::SnapshotJob`). El patrón durable a copiar vive en Guardrails (§13); el
   relato completo del bug encontrado vive en `HISTORIA.md`.

### 9.2 Consideraciones legales (Colombia) — vigentes

Datos de menores y Habeas Data (Ley 1581 + decreto de datos de NNA): documento y datos de menores
como sensibles desde el diseño; minimizar dónde vive el documento en claro (ya mitigado con cifrado
determinístico); registrar el tratamiento. El eslabón crítico es la **captura del correo en
matrícula** → su validación es deber institucional explícito (todavía no hay UI de matrícula que lo
capture). Rate limiting/bloqueo en login, OTP y completado — **implementado**. Nunca exponer
directorios de estudiantes ni autocompletar por documento/nombre — `Core::Access::GuardianScope`
(✅ real, v1.9.0) **nació y se mantiene sin buscador** — verificado con test que inspecciona la
firma del método (no acepta término de búsqueda) y con aserciones sobre la vista (sin
`input[type=search]`/`input[name=q]`/`form[action*=search]`).

---

## 10. Decisiones abiertas / bordes a resolver

> Los bordes ya cerrados (⚠-1, ⚠-2, B1) tienen el razonamiento completo en `HISTORIA.md` — aquí
> solo el estado.

| # | Borde | Contexto | Estado |
|---|---|---|---|
| ⚠-1 | Identidad global vs. un-correo-un-tenant | — | ✅ Cerrado — ver `HISTORIA.md`. No re-abrir sin razón de negocio explícita. |
| ⚠-2 | Dónde vive el campo de documento | — | ✅ Cerrado — ver `HISTORIA.md`. |
| **E** | **CHECKPOINT E: `teacher_management` → `staff_management`** | Personal no docente (cocina, transporte, etc.) sin dominio claro. D1 (generalizar) vs D2 (dominio HR nuevo). Ya existe un `staff_management` mínimo (solo cierra un nav huérfano) que **no** resuelve este checkpoint. | 🔴 Abierto. Recomendado D1. Cerrar antes de crear Tier C de personal. |
| B1 | Estudiantes sin login | `students.user_id` nullable. | ✅ Confirmado como diseño (ver `HISTORIA.md`). Consistencia en portales ya documentada (v1.9.0): un estudiante sin `user_id` propio simplemente no tiene cuenta con la que entrar al portal en primer lugar (no hay sesión que iniciar); uno CON `user_id` pero cuyo registro aún no se resolvió ve el empty state de `Core::Access::StudentSelfScope`, nunca un error. |
| **B2** | **Fechado efectivo de asignaciones vs. `academic_terms`** | ¿`role_assignments.valid_from/until` se acopla a ciclos lectivos o es independiente? | 🔴 Abierto. Las columnas `valid_from`/`valid_until` **ya existen** (agregadas en P1, calendario simple, sin FK a `academic_terms`) — la pregunta de si acoplarlas a ciclos lectivos sigue sin decidirse; hoy son fechas de calendario independientes. |
| **M1** | **Unidad de metering por dominio medido** | El control plane solo consume rollups; `addons.unit` sigue provisional. | 🔴 Abierto. Se fija cuando cada dominio medido defina su evento facturable — bloquea S3b. |
| P1 | `IdentityAccess::PermissionCheck` real | — | ✅ Cerrado (v1.6.0) — ver `HISTORIA.md`. |
| **P2** | **Rol libre `institution_users.role`** | Columna string sin lectores en el código (ver §5). Puede generar confusión con el RBAC real. | 🔴 Abierto. Decidir si se elimina, se documenta como legacy, o se conecta a algo. |
| **Cav.** | **Headcount de `base_seats` no filtra por matrícula/término** | `Core::Headcount::Snapshotter` cuenta `students.status == "active"`, no matrícula en el `academic_term` activo — `enrollments.term` es un string libre sin FK a `academic_terms`, no existe ese join en el esquema actual. S4 factura sobre ese mismo número tal cual. | 🔴 Abierto (limitación conocida, no bloqueante). Antes de "arreglarlo" hay que decidir explícitamente cómo conectar `enrollments`↔`academic_terms` — no asumir una convención de nombres no verificada. |

---

## 11. Próximas iteraciones (backlog ordenado)

> Orden sugerido por dependencia y riesgo. Cada iteración cierra con actualización de este documento (bump de versión) y una entrada en `HISTORIA.md`.

1. **Módulo de autenticación/onboarding — lo que queda** (ver §9.1), en orden recomendado:
   1. ~~`Core::RosterImport::Parser/Validator/Committer`~~ — ✅ **cerrado para ambos kinds**
      (estudiantes v1.7.0, acudientes v1.8.0). Estructura por-kind ya lista para un tercer kind si
      alguna vez hiciera falta (`Strategy.for` + una nueva `Strategies::*`, sin tocar orquestación).
   2. ~~`Core::Access::GuardianScope` + portales de estudiante/acudiente~~ — ✅ **cerrado (v1.9.0)**, ver `HISTORIA.md`.
   3. **Vistas de autoservicio reales para docente/coordinador/director** sobre el término activo (estudiante/acudiente ya resueltos en el punto anterior). **Cabeza de fila ahora.**
   4. Visor de `audit_events` + bandeja de discrepancias (barato — los datos ya existen).
   5. Batch-invite tras el alta de acudientes, full-async de parse+validar, y purga de `roster_import_rows` post-commit — hardening documentado, no construido (ver `HISTORIA.md` v1.7.0).
   5. Job recurrente para `Invitations::Expirer` y webhook real para `Invitations::BounceHandler` (opcional / según necesidad real de producción, no bloqueante).
2. **Cerrar CHECKPOINT E** (`staff_management` vs `human_resources`) y, si aplica, scaffold del dominio de personal no docente.
3. ~~Cablear la puerta de auth real (gate #2, RBAC)~~ — ✅ **P1 cerrado (v1.6.0)**, ver `HISTORIA.md`.
4. **Vistas de negocio por dominio** que aún estén en stub → conectarlas a modelos reales, dominio por dominio (empezando por `core` y `teacher_management` con el caso de aceptación de §6.4). El descriptor de scope de P1 solo se cableó de verdad en `teacher_management`; el resto de dominios (student_support, group_management, schedules, counseling, cafeteria, transportation) sigue con su catálogo de recursos en stub y se adopta aquí, incrementalmente, dominio por dominio.
5. **Plano de control — pendientes del track de billing** (S0→S4 completo, ver §7):
   1. **S3b — emisión real por dominio**: cablear cada dominio medido para llamar `ControlPlane::Usage::Ingest` en su evento facturable real. **Requiere cerrar M1 primero** (unidad de metering por dominio). Slice transversal, tocará `app/domains/*` — mismo patrón de "una sola pieza" que S2b, no ramificar por dominio. Una vez cerrado, las líneas `usage_overage` del corte dejarán de dar cero — no hace falta tocar `PeriodCut` para eso, ya las suma correctamente.
   2. **Riel de pago** — fuera de alcance de v1. Finalizar una factura la congela; no la cobra ni la envía.
   3. **Hardening documentado, no construido**: exclusion constraint `int4range`/`daterange` con GiST por `plan_id` (tiers) o por `(institution_id, addon_id)` (entitlements) para prohibir solapamiento a nivel de BD, al estilo `WITHOUT OVERLAPS` de `schedules`; prorrateo de `addon_fee`; edición manual de líneas de un borrador; tabla `billing_periods` explícita.
   4. **RBAC intra-plano** (roles/scopes de `platform_admin`) — sigue sin construirse; cualquier `platform_admin` autenticado administra el catálogo/subscriptions/entitlements/headcount/uso/facturas completos.
   5. **Provisioning de instituciones** (crear/editar una institución desde el control plane) — hoy solo se listan read-only.
   6. **Schedule recurrente** de `Core::Headcount::SnapshotJob`, `ControlPlane::Usage::RollupJob` y `ControlPlane::Billing::PeriodCutJob` — diferido (todos quedan invocables manual/rake); mismo tratamiento que `Invitations::Expirer`.
6. **Metering real** por dominio medido (= S3b arriba): definir el evento facturable de cada uno (cierra M1) y llamar `ControlPlane::Usage::Ingest` desde ahí — el pipe genérico, el rollup idempotente, y el corte de periodo que los suma (S4) ya existen, no hay que reconstruirlos.
7. **Tiempo real** (Turbo Streams sobre Solid Cable, sin Redis): `transportation` (abordaje) y `communication` (canales). Hoy diferido.
8. **`communication` a fondo**: migraciones de `conversations`/`messages`/`tags`, mensajería con padres, canales.
9. **`analytics_bi`**: vistas materializadas + reporte cross-tenant auditado (rol `BYPASSRLS`, `edu_bi_reader`).
10. **Endurecer auditoría** (append-only — ya implementado a nivel de BD) y terminar la bandeja de discrepancias del roster (ver ítem 1.4 arriba).

---

## 12. Guardrails operativos (recordatorio permanente)

- Migraciones: **`bin/migrate`**, nunca `rails db:migrate`. `edu_migrator` con `CREATE` en las 4 bases.
- **Migrar development NO migra test** — correr también `RAILS_ENV=test bin/migrate` tras cada migración nueva, o el test suite falla con `NoMethodError` (no con un error de SQL) sobre la columna/tabla nueva.
- `EDU_MIGRATOR_PASSWORD` es solo de entorno, nunca vive en el repo. Si se pierde en dev local, resetear con `psql` (auth `trust` del superusuario del SO) vía `ALTER ROLE edu_migrator PASSWORD '...'` — nunca dejar la contraseña en archivos temporales tras usarla.
- **Timestamps de migración no pueden ser >24h futuros respecto al reloj real de la máquina** (Rails 8 valida `version.to_i < (Time.now.utc + 1.day).strftime(...)`) — generar el timestamp con el reloj real al momento de escribir el archivo, no proyectando una fecha narrativa.
- **Suite de tests: correr en serie.** La paralelización por fork (`workers: :number_of_processors`, default cuando la suite pasa ~50 tests) **crashea el proceso Ruby** en esta máquina (YJIT + fork). `PARALLEL_WORKERS=1 bin/rails test` corre limpia (Rails respeta esa env var como override de `parallelize`, sin tocar `test_helper.rb`). Un crash de proceso ≠ fallo de test — no asumirlo sin correr en serie primero.
- **Sin `default_scope`** para tenancy ni scope de rol — siempre Query objects.
- **RLS con `FORCE`**; runtime sin `BYPASSRLS`; cross-tenant solo por el rol auditado (`edu_bi_reader`).
- **`authorize!` en el controlador** (puerta dura, llamada a mano dentro de cada acción); `can?` en la vista solo cosmético.
- **Sin `RoleAssignment` real que aplique = cero permisos (fail-closed), siempre** (P1, cerrado) — no hay fallback a ninguna persona stub en runtime; `Authorization::StubAssignments`/`StubResolver` quedan retirados (solo `StubResolver` sigue vivo como contexto fijo para un caso de test puntual, ver `HISTORIA.md`). Cada persona nueva creada vía `PeopleController` necesita `RoleAssignment` reales para tener acceso — importante para onboarding real.
- **`has_secure_password` con `validations: false` en `Core::User`** — un `password_digest` nulo es un estado válido (persona invitada, no completada). No "arreglar" agregando de vuelta la validación de presencia por defecto sin releer la narrativa en `HISTORIA.md` (§9.4 original).
- **Suspender (`institution_users.status`) bloquea login y quita grants reales en la siguiente request** (confirmado, P1) — `Current#resolve_institution_user` solo resuelve membresías `active`, así que sin `institution_user_id` el motor real (`IdentityAccess::PermissionCheck`) no carga ningún `role_assignment`: cero permisos, de verdad. NO destruye sesiones ya abiertas de otras instituciones del mismo usuario.
- **Sin gemas nuevas** salvo bottleneck documentado e irresoluble con lo nativo. `bcrypt` no cuenta como nueva — es la gema que el propio scaffold de Rails deja comentada para `has_secure_password`.
- Propshaft sin `@import`/Sass; importmap sin build; **tokens-only** (no tocar `tokens.css` salvo token faltante justificado); accesibilidad AA.
- Cross-domain siempre por **FK + stub** hasta que exista el modelo real; no inventar tablas de otros dominios.
- El **plano de control fuera de `app/domains/*`** — no scopearlo por `institution_id` por costumbre.
- **Zeitwerk colapsa `app/domains/*/{models,queries,services,jobs,policies}`** — un archivo en `app/domains/<d>/services/<ns>/foo.rb` define `<D>::<Ns>::Foo`, NO `<D>::Services::<Ns>::Foo`. Verificar con `bin/rails zeitwerk:check` antes de dar por buena una constante nueva.
- **Gate #1 (entitlement) siempre antes de gate #2 (RBAC)** — `Entitlement::Controller` (una sola pieza, incluida una vez en `ApplicationController`) corre antes de que la acción llegue a `authorize!`; un módulo no habilitado nunca revela detalles de RBAC. Ver §7.1.
- **Los dominios fundacionales nunca se gatean por entitlement** — su ausencia de `Entitlement::Registry` (`config/entitlements/*.rb`) ES la señal de "no gateado"; no existe (ni debe crearse) una lista aparte de "fundacionales".
- **`Entitlement::Registry` no referencia `ControlPlane::AddonCatalog::DOMAIN_KEYS` en runtime** — solo `test/models/entitlement/registry_consistency_test.rb` cruza ambas listas. No "simplificar" el runtime del inquilino para que lea la constante del control plane directamente; ese acoplamiento es exactamente lo que este seam evita.
- **`sign_in_as_member` (test helper) otorga entitlement de todos los dominios gateados por defecto** — la institución efímera de test se comporta como un tenant completamente aprovisionado. Un test que necesite el escenario "no entitled" debe **revocar** el dominio específico, no asumir que parte sin ninguno.
- **`sign_in_as_member` (P1) también otorga por defecto un `RoleAssignment` real institución-wide** (`grant_default_role: false` para optar por "cero grants"). Un test que necesite un escenario de scope MÁS ANGOSTO llama a `with_grants`/`grant_role!` (test_helper.rb) — `with_grants` **revoca primero** cualquier asignación existente antes de sembrar la nueva (los `RoleAssignment` reales solo SUMAN, no se reemplazan entre sí como sí hacía swapear `Authorization::StubAssignments.all`).
- **`scope_department_id`/`scope_grade_level_id`/`scope_group_id` tienen FK real** (a `departments`/`grade_levels`/`sections`) — sembrar un `RoleAssignment` con scope real exige que esa fila exista primero (`grant_role!` lo hace por `find_or_create_by!(id: scope_id)`). Reusar el mismo id fijo entre archivos de test distintos es seguro porque cada test corre en su propia transacción revertida (fixtures transaccionales) — no hay colisión entre tests.
- **Todo job nuevo que toque datos tenant-scoped debe heredar `ApplicationJob`** (no reinventar el manejo del GUC) — ese mecanismo incluye un `Tenant::Guc.reset!` explícito en el `ensure`, no solo confiar en que el `COMMIT` de la transacción limpie el `SET LOCAL` (dentro de un test envuelto en una transacción englobante, la transacción del job es un SAVEPOINT, y Postgres no limpia `SET LOCAL` al liberar un savepoint).
- **Verificar "el GUC no se filtró" con una query real bajo RLS, nunca con una relectura de `current_setting()`** — esa relectura puede devolver un valor obsoleto por el query cache de ActiveRecord dentro de una transacción, dando un falso positivo de fuga (o, peor, un falso negativo). La prueba real es: sin ningún GUC fijado, ¿una tabla RLS-protegida devuelve cero filas?
- **El headcount cuenta `GroupManagement::Student.status == "active"` de la institución, sin filtrar por `enrollments`/`academic_terms`** — `enrollments.term` es un string libre sin FK a `academic_terms`; no existe ese join en el esquema actual. `academic_term_label` en el snapshot es solo una etiqueta descriptiva del término activo, nunca un filtro del conteo. No "arreglar" esto para que parezca más preciso sin antes decidir explícitamente cómo conectar `enrollments`/`academic_terms` (ver §10, Cav.). **S4 factura sobre ese mismo número tal cual** — la limitación es heredada, no nueva.
- **El corte de periodo (`ControlPlane::Billing::PeriodCut`) nunca re-lee el catálogo vivo** — solo el `price_tiers_snapshot`/`base_price_per_student_cents` congelados en `subscriptions` al firmar (S2a). Si un futuro cambio "optimiza" esto para leer `plans`/`plan_price_tiers` directamente, rompe la garantía de snapshot inmutable que todo el track de billing (S2a→S4) depende de sostener.
- **Los overrides se aplican con `coalesce(override, catálogo)` campo por campo, nunca de-todo-o-nada** — un entitlement puede tener override de fee pero no de cupo, por ejemplo. `source_ref` de cada línea registra si se aplicó un override, para que la factura sea defendible sin tener que abrir la base de datos.
- **`InvoiceLineItem#readonly?` bloquea `update`/`destroy` de una fila individual, pero `PeriodCut` regenera un `draft` con `invoice.line_items.delete_all`** (bulk SQL, bypasea `readonly?` a propósito) — no confundir "una línea no se edita nunca" con "un borrador no se regenera nunca". Solo `delete_all`/`create!` desde el servicio, nunca `destroy`/`update` de una línea suelta.
- **Nunca escribir código después de un `.enqueue`/`.enqueue_for` que dependa del GUC del tenant seguir fijado** (RosterImport, v1.7.0) — bajo el adaptador de test de ActiveJob (`perform_enqueued_jobs`) un job se ejecuta SINCRÓNICAMENTE, y `ApplicationJob#around_perform` resetea incondicionalmente el GUC en su `ensure` al terminar; cualquier query tenant-scoped (p. ej. un `Audit.log`) que corra DESPUÉS de encolar en la misma acción puede fallar RLS aunque siga siendo, técnicamente, la misma request. Esto no es solo un artefacto de test — cualquier adaptador de cola que corra inline expone lo mismo. Ordenar siempre: auditar/hacer trabajo tenant-scoped **antes** de encolar, nunca después.
- **Cifrar un valor suelto dentro de una columna `jsonb` (no un atributo `encrypts` completo)** — usar la API de bajo nivel `ActiveRecord::Encryption.encryptor.encrypt/decrypt(valor, key_provider: ActiveRecord::Encryption.key_provider, cipher_options: { deterministic: true })` (ver `Core::RosterImport::Cipher`), NO la macro declarativa `encrypts` (que opera sobre un atributo AR entero, no sobre una clave dentro de un hash jsonb). Mismo cifrado determinístico que cualquier `encrypts ..., deterministic: true` existente, así que sigue siendo comparable contra esos atributos vía query normal (Rails encripta el lado de la query de forma transparente).
- **Al enmascarar un dato sensible para mostrarlo en una vista, nunca reveles más de la mitad de los caracteres** — una regla de "muestra los últimos 4" revela el valor COMPLETO si el dato tiene 4 caracteres o menos (encontrado real en RosterImport's preview, v1.7.0, no solo hipotético). Calcular el tramo visible como `[largo/2, N].min`, nunca un valor fijo sin tope relativo al tamaño real. (v1.8.0: esta regla se movió de un helper de vista a `Core::RosterImport::Cipher.mask` — cada strategy decide qué se enmascara en su propio `preview_columns`; la vista nunca decide qué es sensible.)
- **Un acudiente (`Core::RosterImport` kind `guardians`) obtiene SIEMPRE cero `IdentityAccess::RoleAssignment`** — no es staff, su acceso es por relación (`guardian_students`), nunca por RBAC. `Core::People::Resolver` ya garantiza esto por construcción (nunca toca `role_assignments`); no "arreglar" esto agregando un rol "para que el portal funcione" cuando `GuardianScope` se construya — el portal se gatea por relación, no por permiso.
- **El upsert de un link `guardian_students` (o cualquier vínculo similar) es SIEMPRE aditivo: un CSV/import nunca borra un vínculo ausente del archivo** — solo crea vínculos nuevos o re-afirma (actualiza `relationship`, reactiva si estaba `revoked`) los que el archivo menciona. Desvincular es una acción explícita y separada, nunca un efecto secundario de un re-import. Verificado con un test dedicado ("el link ausente del CSV sobrevive"), no solo inferido.
- **Estrategia por-kind para pipelines multi-tipo (`Core::RosterImport::Strategy.for`)** — cuando un mismo pipeline (parse→validar→commit) debe soportar variantes con reglas distintas, extraer un objeto-estrategia por variante (columnas, validación, upsert, preview) y mantener la orquestación compartida sin ningún `if kind == ...`. Añadir un tipo nuevo es agregar una clase, no editar las existentes ni sus tests.
- **El portal de una persona (estudiante/acudiente) se gatea SIEMPRE por relación (`Core::Access::GuardianScope`/`StudentSelfScope`), nunca por RBAC** — ninguno de los dos tiene ni necesita `authorize!`; el query object explícito+scoped ES la puerta. No agregar un rol/permiso "para que el portal funcione" cuando se cablee un dominio nuevo dentro de él (backlog #4) — el gate sigue siendo la relación, el entitlement (si aplica al dominio colgado) se resuelve aparte. Y **`GuardianScope` nace y se mantiene sin buscador** — ninguna versión futura le agrega un parámetro de término/búsqueda; es el invariante de Habeas Data no negociable de este proyecto.
- **El filtro por término lectivo sigue diferido a B2 — `GuardianScope` (como el headcount de S3a) no filtra por `academic_term`** — `enrollments.term` sigue siendo un string libre sin FK a `academic_terms`; no inventar ese join para "que se vea más preciso". El término activo puede mostrarse como etiqueta descriptiva (mismo patrón que `Core::Headcount::Snapshotter`), nunca como condición de un scope de seguridad.

---

## 13. Changelog

El changelog completo (`v1.0.0` → `v1.9.0`) vive en **`HISTORIA.md`**. Entrada de esta versión:

- **`v1.9.0` — Onboarding: `Core::Access::GuardianScope` + portales reales.** Query object real
  (`GuardianScope`/`StudentSelfScope`, junto a `EntitledAddonKeys` en `services/access/` — no en
  `queries/access/` como se asumía) que resuelve "mis acudidos"/"mi propio registro" contra
  `guardian_students`/`students.user_id`. Portales de acudiente y estudiante retiran su stub y
  quedan sobre datos reales, gateados por relación (cero RBAC). Se agregó una ruta nueva
  (`/portal/guardian/students/:id`) para el resumen de solo lectura por hijo, siempre resuelta a
  través del scope. Caso de aceptación de seguridad verificado end-to-end: aislamiento cross-tenant,
  exclusión de links revocados, cero superficie de búsqueda. Sin migraciones. Narrativa completa en
  `HISTORIA.md`.
- **`v1.8.0` — Onboarding: RosterImport de acudientes.** Extiende `Core::RosterImport` al kind
  `guardians`: `Core::People::Resolver` crea `Core::User`+membresía (cero `role_assignments`), y
  `guardian_students` se upserta aditivo/no-destructivo (nunca borra un link ausente del CSV).
  Se extrajo una estrategia por-kind (`Strategy.for` → `Strategies::{Students,Guardians}`) de
  `Parser`/`Validator`/`Committer` (antes hardcodeados a estudiantes) sin romper ningún test
  existente. Sin migración. Hallazgo clave del recon: la membresía del acudiente no es cosmética —
  `SessionsController` la exige para autenticar; el portal de acudiente sigue 100% stub. Narrativa
  completa en `HISTORIA.md`.
- **`v1.7.0` — Onboarding: RosterImport de estudiantes.** `Core::RosterImport::{Parser,Validator,
  Committer}` real para `GroupManagement::Student` (acudientes = slice siguiente). Upsert directo
  por `national_id`, NO vía `Core::People::Resolver` (ese resolver crea `Core::User`, fuera de
  alcance aquí). `national_id` cifrado dentro del jsonb de `roster_import_rows` (API de bajo nivel,
  sin migración de columna); el CSV crudo nunca se persiste (`has_one_attached :file` retirado del
  modelo). `Core::RosterImport::CommitJob` — segundo job real con el mecanismo de GUC de S3a. Una
  migración (`resolved_record_id`). Dos bugs reales encontrados y corregidos en la verificación
  (orden auditoría/encolado bajo GUC; máscara de `national_id` que revelaba el valor completo para
  ids cortos). Narrativa completa, discrepancias de esquema y detalle de verificación en
  `HISTORIA.md`.
- **`v1.6.0` — P1: RBAC real.** `IdentityAccess::PermissionCheck` reemplaza `Authorization::
  StubResolver`/`StubAssignments` en runtime — real-only, fail-closed. Ambas compuertas (entitlement
  + RBAC) son reales. Caso de aceptación de María (`teacher_management`) pasa contra
  `role_assignments` reales. Migración nueva (`valid_from`/`valid_until` en `role_assignments`).
  Narrativa completa, hallazgos del recon (roles/role_permissions tenant-scoped no globales, FK
  reales en las columnas de scope, el radio de impacto de 14 archivos de test) y detalle de
  verificación de seguridad en `HISTORIA.md`.
- **`v1.5.1` — split editorial**: magro (contexto vivo, este archivo) + `HISTORIA.md` (changelog +
  narrativas + bordes cerrados). Sin cambios de estado del código ni del repo — solo reorganización
  de documentación.
