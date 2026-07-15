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
| **Versión del documento** | `v1.20.0` |
| **Fecha** | 2026-07-15 |
| **Tests** | 472 runs / 0 fallos / 1 skip preexistente (suite completa, en serie — ver Guardrails) |
| **Estado en una línea** | Identidad real + RBAC/entitlement reales + portales de persona + autoservicio de staff + auditoría + CHECKPOINT E + #4 barrido (`teacher_management`/`group_management`/`schedules`-calificaciones/`counseling`) + matrícula por término real (`Schedules::ActiveTermEnrollmentScope`, v1.15.0) + `attendance` (v1.16.0) + `report_cards` (v1.17.0) + `finance` (v1.18.0) + `communication` subsistema (A) anuncios (v1.19.0) + **`communication` subsistema (B) mensajería (ítem #5b del MVP): conversaciones multiparte, participante `institution_user` o `guardian_user` (CHECK exactamente-uno), CUATRO caminos de acceso nunca colapsados (compose RBAC / bandeja-participación / responder-participación / auditoría RBAC con log condicional append-only) — `communication` queda completo salvo diferidos anotados (fan-out 1:1, threading, tags, acudiente-inicia)**. `LINEAMIENTOS_MVP.md` ordena lo que sigue: `assignments` es el próximo ítem. |

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
| `core` | Espina académica **+ identidad de personas** | Acudientes (`guardian_students`), `academic_terms` (con índice de "un solo término activo" — **corrección de recon**: `students`/matrícula/`disciplinary_logs` NO viven aquí, ver `group_management`/`schedules`/`student_support`). Posee `Core::User`, `Core::InstitutionUser`, `Core::Session`, `Core::People::Resolver`, y `Core::Headcount::{Snapshotter,SnapshotJob}` (S3a) — la identidad y el pipe de headcount viven aquí, no en `identity_access` ni en el control plane. Casi todo le hace FK, incluido `Schedules::Enrollment.academic_term_id` desde v1.15.0 (cierra la mitad de modelo de Cav./B2). |
| `staff_management` | **Staff generalizado (D1, CHECKPOINT E cerrado)** | `StaffManagement::StaffMember` — empleo/vinculación de TODO el personal (`staff_category` incl. `teaching`), `Department` (`kind` academic/operational, referenciado por `role_assignments.scope_department_id`), `EmploymentPeriod` (profundidad HR opcional). `department_id` **nullable** — un no-académico no necesita departamento académico. Fundacional (sin `Entitlement::Registry`). |
| `teacher_management` | Docentes — **especialización de staff (D1)** | `Teacher` es la extensión docente de un `StaffManagement::StaffMember` (`teachers.staff_member_id`, FK **nullable**, aditiva — un docente puede o no tener el link poblado). Posee lo exclusivamente docente: `teacher_code`, `faculty` (universidad), `teaching_assignments` (materia). Departamentos/perfil base viven en `staff_management`, no aquí. |
| `group_management` | Grupos | `groups` (`kind` homeroom/…), membresía/rosters. `students.user_id` y `students.national_id` (cifrado) viven en el modelo de este dominio (`GroupManagement::Student`). |
| `schedules` | Libreta de notas (real) **+** horarios/timetabling (Clase C, sin tabla) | **Real**: `Subject`/`Enrollment`/`Assessment` (calificaciones, v1.14.0); `Enrollment.academic_term_id` conecta con `academic_terms` (v1.15.0 — `Schedules::ActiveTermEnrollmentScope` es el resolver canónico de "matriculado en el término activo"). **Sin tabla real** (Clase C): rooms/patrones de reunión — `WITHOUT OVERLAPS` de PG18 es diseño, no implementación. |
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
| `finance` | Tesorería/cartera **dentro** del tenant (el colegio cobra pensiones a acudientes). Cargos, pagos, estados de cuenta, planes de pago. **≠ billing de plataforma.** Tenant-scoped. **UI real desde v1.18.0**: `StudentAccount`/`Charge`/`Payment` (existían desde el primer commit) ahora tienen superficie de supervisión (molde #4, `finance.read`/`finance.write` — permisos que YA existían y ya reusaba `Cafeteria::BalancesController`) y portal del acudiente (solo lectura, mismo camino de lectura — `Finance::AccountStatement`). Dinero en `decimal(12,2)`, NO `*_cents bigint` (ver Guardrails). `PaymentPlan`/`Installment` (planes de pago/cuotas) siguen **sin UI**, diferidos a su propio slice — no alimentan el saldo hoy. |
| `communication` | Hub de comunicación. Ver §8 (anexo). **Ambos subsistemas reales**: (A) anuncios (v1.19.0, `Communication::Announcement`, difusión org-wide, RBAC para publicar + lectura por membresía); (B) mensajería (v1.20.0, `Conversation`/`ConversationParticipant`/`Message`, multiparte, participante `institution_user` **o** `guardian_user` — CHECK exactamente-uno, cuatro caminos de acceso RBAC/participación/auditoría). Diferidos anotados en §8.2 (fan-out 1:1, threading, tags, acudiente-inicia). |
| `attendance` | **Asistencia diaria por homeroom (v1.16.0, item #2 del MVP)** — dominio NET-NEW, real desde el día uno (sin fase stub). `AttendanceRecord` (`student_id`+`group_id`+`date`, único `(institution_id, student_id, date)`). Consume `Schedules::ActiveTermEnrollmentScope` (nunca re-deriva el join a término); molde #4 completo (per-row `can?`, `authorize!`, nav). Addon-gated. Por-materia diferido. |
| `report_cards` | **Boletines (v1.17.0, item #3 del MVP)** — dominio NET-NEW, addon-gated, lee `schedules` por FK (nunca posee `Subject`/`Enrollment`/`Assessment`). `ReportCard` (`student_id`+`academic_term_id`, único `(institution_id, student_id, academic_term_id)`) — snapshot **congelado al publicar** (`lines_snapshot` jsonb + `overall_average`, nunca recomputado al leer un publicado). "Draft" es cómputo vivo sin fila (`ReportCards::Computation`, consumido tanto por el preview de supervisión como por `ReportCards::Publisher`). Dos superficies: supervisión (molde #4, `report_card.view`/`report_card.publish`) y portal (por relación, solo publicados, sin `authorize!`, fuera de `Navigation::Registry`). Consume `Schedules::ActiveTermEnrollmentScope` igual que `attendance`. Asistencia en el boletín y escala Decreto 1290 diferidos. |

### Tier C — candidatos (crear SOLO bajo confirmación explícita)

`admissions` (pipeline aspirante→matriculado) · `library`. (`staff_management` ya NO es candidato —
CHECKPOINT E cerrado v1.12.0, ver §10/`HISTORIA.md`: existe y resuelve el staff generalizado desde
el primer commit del repo.)

### Orden de dependencias (creación / migraciones)

1. `core`, `staff_management`, `teacher_management` (extensión docente de `staff_management`), `group_management` (proveen destinos de scope).
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
buscador global acotado por scope, portales de persona (student/guardian, sobre datos reales de
relación vía `Core::Access::GuardianScope`/`StudentSelfScope`, v1.9.0), **autoservicio de staff
("mis datos", `/mis_datos`) sobre datos reales por identidad** (`Core::Access::StaffProfileScope`/
`StaffRoleAssignmentsScope`, v1.10.0) — ninguna de estas tres superficies pasa por `authorize!`,
todas se gatean por identidad/relación, no por RBAC, y viven fuera de `Navigation::Registry`
(cuyas entradas SIEMPRE filtran por `can?`) — vista **403 amable** (RBAC) y página **"módulo no
habilitado"** (entitlement, distinta del 403).

**La INVERSIÓN respecto a lo anterior: el visor de `audit_events` + bandeja de discrepancias**
(`/identity_access/audit_events`, v1.11.0) **SÍ es una superficie administrativa RBAC-gateada**
(`authorize!("audit_events.read")`) y **SÍ vive en `Navigation::Registry`** — es la lectura de
"quién hizo qué", no "mis propios datos", así que la puerta correcta es RBAC, no identidad. La
bandeja de discrepancias es la MISMA query pre-filtrada al marcador de `DiscrepancyReporter`, nunca
una tabla nueva. `audit_events` sigue append-only (`REVOKE UPDATE/DELETE` a nivel de rol de BD);
esta vista solo lee.

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
solo contra la persona stub) y **desde v1.13.0 real también contra las VISTAS** (índice/show/acción,
no solo el `authorize!` unitario — ver §6.6). María = `(teacher, group:10-A)`, `(teacher,
group:11-B)`, `(area_lead, department:Matemáticas)`, sembrada como `role_assignments` reales, contra
un `TeacherManagement::Teacher`/`StaffManagement::Department` reales (ya no la ex-`TeacherRoster`/
`DepartmentRoster` en memoria). `authorize! teacher.evaluate` = **sí** sobre un docente de
Matemáticas, **no** sobre uno de Sociales; y no ve al resto de la institución. El descriptor de
scope (recurso expone `department_id` vía `Teacher#department_id` delegado a
`StaffManagement::StaffMember`, y `Department#department_id` aliasa `id`) solo se cableó de verdad
en `teacher_management` — el resto de dominios sigue con su catálogo de recursos en stub (backlog
#4), aunque ahora las ASIGNACIONES que los autorizan ya son reales en todos los dominios probados
(ver `HISTORIA.md` v1.6.0).

### 6.5 Patrones canónicos (la "convención de la casa")

Cinco esqueletos que hacen converger a todos los dominios: (1) Query object de índice con scope,
(2) controlador con `authorize!` al inicio, (3) gating con `can?` en vista, (4) pestañas gateadas por
permiso, (5) auto-registro de navegación en archivo propio del dominio (no editar un partial central).

### 6.6 Molde de vista de negocio por dominio — implementación de referencia: `teacher_management`

**#4 (vistas de negocio por dominio) arranca aquí (v1.13.0, slice 1).** Los cinco esqueletos de §6.5
dejaron de ser solo un principio: `teacher_management` es ahora su **implementación real de
referencia**, contra la que los seis dominios restantes (`core`, `student_support`,
`group_management`, `schedules`, `counseling`, `cafeteria`, `transportation`) se copian en slices
posteriores — no se reinventan.

- **Esqueleto #1 (query object)**: `TeacherManagement::TeacherScope`/`DepartmentScope`,
  `StaffManagement::StaffScope` — relation real + `institution_id` explícito + **per-row `can?`**
  vía `.select`, nunca `default_scope`, nunca `PermissionCheck#scope_for` (§6.3: ambos son
  equivalentes; per-row es el que este molde fija como el "aburrido" a copiar).
- **Esqueleto #2/#3** (`authorize!`/`can?`): `TeachersController`/`DepartmentsController`/
  `StaffController`/`TeacherEvaluationsController` — puerta dura al inicio de cada acción, `can?`
  solo cosmético en la vista (botón "Nueva evaluación").
- **Esqueleto #4** (pestañas gateadas): `teachers/show` — tabs "Perfil"/"Evaluaciones", la acción
  dentro de una pestaña se oculta con `can?`, nunca la pestaña misma (un `secretary` de solo lectura
  sigue viendo el estado de evaluaciones, solo no el botón de crear una).
  **Esqueleto #5** (auto-registro de nav): `config/navigation/{teacher_management,
  staff_management}.rb` — ya existía desde antes de #4, sin cambios.
- **Es supervisión, NO autoservicio** (frontera dura — ver `CONCEPTOS_TECNICOS.md`): estas vistas
  muestran a OTRAS personas dentro del alcance del actor; se gatean por RBAC + scope y viven en
  `Navigation::Registry`. La contracara exacta de `/mis_datos` (v1.10.0, identity-gated, sin
  `authorize!`, fuera del registry) — no confundir las dos superficies para un mismo dominio.
- **`evaluate` sin modelo destino (BV6)**: no existe `TeacherManagement::Evaluation` — este slice
  cableó el GATE real (per-row, sobre un `Teacher` real) y la afordancia en vista; el `create` sigue
  siendo un stub sin persistencia (`flash` únicamente). Construir el modelo de evaluación real es
  follow-up, no parte de #4 slice 1.
- **Sin migraciones** — el descriptor de scope real (`staff_members.department_id`,
  `teachers.staff_member_id`) ya existía desde CHECKPOINT E (v1.12.0); este slice solo leyó contra
  él en vez de contra los rosters en memoria.

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

## 8. Dominio `communication` (anexo de diseño)

Dos subsistemas que NO se aplanan en un solo modelo — decisión cerrada en v1.19.0, supersede el
borrador anterior de este anexo (que proponía una tabla `conversations` unificada con `kind`
incluyendo `announcement`; recon de v1.19.0 confirmó que no existía nada real todavía y el owner
decidió separarlos por ser estructuralmente distintos):

### 8.1 Subsistema (A) — Anuncios — ✅ real desde v1.19.0

Difusión de una vía, org-wide dentro del tenant (staff + acudientes + estudiantes con cuenta, sin
segmentar por grado/grupo). Tabla dedicada `announcements` (`title`/`body`/`status` ∈
published/retracted/`author_institution_user_id`/`published_at`/`retracted_at`) — **no** reutiliza
ningún modelo de mensajería. Publicar/editar/retractar es RBAC (`announcement.publish` +
`Navigation::Registry`); leer es **membresía** (cualquier miembro activo, sin `authorize!`, fuera
del Registry, enlazado aparte — ver Guardrails, "tercer tipo de gate"). Retract es SIEMPRE soft
(`status`), nunca `destroy`. Camino de lectura único (`Communication::AnnouncementFeed`) compartido
por staff y ambos portales. Ver `HISTORIA.md` v1.19.0 para la narrativa completa.

### 8.2 Subsistema (B) — Mensajería — ✅ núcleo real desde v1.20.0

Las tres preguntas de diseño quedaron resueltas en el checkpoint (no re-abrir sin razón de negocio
explícita — mismo tratamiento que ⚠-1/⚠-2):

1. **Modelo de hilo = multiparte** (no hub-and-spoke): 2+ participantes, todos ven todos los
   mensajes en una misma conversación. El fan-out 1:1 "director → cada cuidador en privado" queda
   como **fast-follow** — un helper de composición que crea N conversaciones de 2, sin cambiar el
   modelo base.
2. **Auditor = rol de institución** (`conversation.audit`), nunca el super-admin de plataforma.
3. **El auditor ve contenido completo**; el rastro **no** se surfacea a los participantes (solo
   vive en `audit_events`, RBAC-gated).

**Modelo real:** `conversations` (`subject`, `status` ∈ active/closed, `created_by_institution_
user_id`/`closed_by_institution_user_id` — atribución, nullable+nullify), `conversation_
participants` (`institution_user_id` **XOR** `guardian_user_id` — CHECK `num_nonnulls(...) = 1`,
CASCADE en ambas identidades porque son la identidad del registro, no atribución opcional;
`last_read_at` para no-leídos), `messages` (mismo XOR para el emisor, sin `parent_message_id` —
threading diferido, se agrega aditivo cuando se construya). Sin tabla de tags (diferido).

**Cuatro caminos de acceso, nunca colapsados** (ver Guardrails): iniciar (RBAC,
`conversation.compose`, destinatarios acotados — staff de la institución ∪ acudientes de
estudiantes en el scope RBAC del actor, **nunca** un directorio) → bandeja/responder (participación,
sin `authorize!`, camino de lectura único `Communication::Inbox` compartido por staff y el portal
del acudiente) → auditar (RBAC, `conversation.audit`, permiso **distinto** de compose, loguea
`conversation_audited` en `audit_events` solo si el accesor NO es participante).

**Diferidos, anotados, no construidos:** difusión 1:1 a todos los cuidadores (fast-follow sobre la
base multiparte); threading (`parent_message_id`); tags/clasificación por temática; mensajería
iniciada por el acudiente (bloqueada por Habeas Data — "quién puede contactar a quién libremente"
necesita su propio diseño de directorio acotado); videollamada + acta (futuro lejano). Ver
`HISTORIA.md` v1.20.0 para la narrativa completa y los hallazgos de recon.

<details>
<summary>Preguntas originales del checkpoint (resueltas arriba — histórico)</summary>

1. ~~"Director ↔ todos los cuidadores": ¿hilo grupal o hub-and-spoke?~~ → multiparte, ver arriba.
2. ~~¿Quién audita?~~ → rol de institución, ver arriba.
3. ~~Frontera de confidencialidad: ¿contenido completo o solo metadata? ¿rastro visible a los
   participantes?~~ → contenido completo para el auditor; rastro nunca visible a participantes, ver
   arriba.

</details>

**Colisión de nombres a evitar** (seguía aplicando del borrador anterior): *canales de discusión*
(Slack-like, si mensajería termina adoptando el concepto) vs. *canales de entrega* de notificaciones
(in-app/email/push) — nombrar distinto (`_channel_*` vs `_delivery_channel_badge`) si ambos
terminan existiendo. **Tiempo real (Turbo Streams/Solid Cable) diferido** para ambos subsistemas.
Los correos de OTP e invitación **no** pasan por este dominio — van directo por
`ApplicationMailer`/Active Job; centralizar todo envío saliente aquí sería una decisión de
arquitectura nueva, no asumida hoy. La faceta de **notificaciones del sistema** (sistema→persona,
`notifications`/`notification_preferences`/plantillas) tampoco se ha diseñado — queda fuera de
ambos subsistemas descritos arriba, un tercer subsistema (C) a definir si hace falta.

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
3. ~~Vistas de "mis datos" con datos reales para docente/coordinador/director~~ — ✅ **cerrado
   (v1.10.0)**. `/mis_datos`, identity-gated (`Core::Access::StaffProfileScope`/
   `StaffRoleAssignmentsScope`), sin `authorize!`. "Mis grupos"/"mi departamento" se derivan de los
   `scope_group_id`/`scope_department_id` de los propios `role_assignments` vigentes del actor — no
   existe ningún vínculo directo profesor↔grupo en el esquema (`sections` no tiene
   `homeroom_teacher_id`). "Mi horario" queda como **vista previa** (reusa el stub de `schedules`,
   filtrado por identidad, nunca por RBAC) — ese dominio no tiene ninguna tabla real todavía, ni
   siquiera parcial. Ver `HISTORIA.md`.
4. ~~Visor de `audit_events` + bandeja de discrepancias reportadas~~ — ✅ **cerrado (v1.11.0)**.
   `IdentityAccess::AuditEventIndex` (tenant-scoped, filtros actor/acción/fecha sobre un conjunto
   conocido, paginado) alimenta tanto el visor (`/identity_access/audit_events`) como la bandeja
   (`/identity_access/audit_events/discrepancies`, misma query con `action` fijo al marcador de
   `DiscrepancyReporter`). RBAC-gateado (`audit_events.read`, permiso nuevo), a diferencia de las
   superficies self-service. Hallazgo del recon: faltaba un índice `(institution_id, created_at)`
   real para paginar ordenado — única migración del slice. Ver `HISTORIA.md`.
5. **`IdentityAccess::Expirer`/`BounceHandler` sin disparador real** — `Expirer` corre
   oportunísticamente desde `PeopleController#index` (no hay job recurrente en Solid Queue);
   `BounceHandler` no está conectado a ningún webhook real. (`Resender` no se construye — `Issuer`
   ya invalida-y-recrea.) Único remanente (opcional) del track de onboarding.
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
| **E** | **CHECKPOINT E: `teacher_management` → `staff_management`** | Personal no docente (cocina, transporte, etc.) sin dominio claro. D1 (generalizar) vs D2 (dominio HR nuevo). | ✅ **Cerrado (D1, v1.12.0)** — ver `HISTORIA.md`. Recon reveló que D1 **ya estaba resuelto en el esquema desde el primer commit** (`637a998`, anterior al track de onboarding): `StaffManagement::StaffMember` es el empleo generalizado de TODO staff (`staff_category` incl. `teaching`, `department_id` nullable); `TeacherManagement::Teacher` es su extensión docente vía `teachers.staff_member_id` (FK nullable, aditiva). No fue necesaria ninguna migración ni rename — el gap real era que nadie lo había verificado end-to-end para un staff NO docente ni corregido este documento (que describía `staff_management` como "solo cierra un nav huérfano", cierto de la vista pero no del modelo). Las vistas de directorio (`StaffManagement::StaffRoster`/`TeacherManagement::TeacherRoster`) siguen en stub — eso es backlog #4, no este checkpoint. |
| B1 | Estudiantes sin login | `students.user_id` nullable. | ✅ Confirmado como diseño (ver `HISTORIA.md`). Consistencia en portales ya documentada (v1.9.0): un estudiante sin `user_id` propio simplemente no tiene cuenta con la que entrar al portal en primer lugar (no hay sesión que iniciar); uno CON `user_id` pero cuyo registro aún no se resolvió ve el empty state de `Core::Access::StudentSelfScope`, nunca un error. |
| **B2** | **Fechado efectivo de asignaciones vs. `academic_terms`** | ¿`role_assignments.valid_from/until` se acopla a ciclos lectivos o es independiente? | 🔴 Abierto. Las columnas `valid_from`/`valid_until` **ya existen** (agregadas en P1, calendario simple, sin FK a `academic_terms`) — la pregunta de si acoplarlas a ciclos lectivos sigue sin decidirse; hoy son fechas de calendario independientes. |
| **M1** | **Unidad de metering por dominio medido** | El control plane solo consume rollups; `addons.unit` sigue provisional. | 🔴 Abierto. Se fija cuando cada dominio medido defina su evento facturable — bloquea S3b. |
| P1 | `IdentityAccess::PermissionCheck` real | — | ✅ Cerrado (v1.6.0) — ver `HISTORIA.md`. |
| **P2** | **Rol libre `institution_users.role`** | Columna string sin lectores en el código (ver §5). Puede generar confusión con el RBAC real. | 🔴 Abierto. Decidir si se elimina, se documenta como legacy, o se conecta a algo. |
| **Cav.** | **Headcount de `base_seats` no filtra por matrícula/término** — **mitad de MODELO cerrada (v1.15.0), mitad de FACTURACIÓN sigue abierta a propósito** | `enrollments.academic_term_id` (FK real, nullable) ya conecta `Schedules::Enrollment`↔`academic_terms` — `Schedules::ActiveTermEnrollmentScope` resuelve "estudiantes matriculados en el término activo" de verdad. **Pero** `Core::Headcount::Snapshotter` sigue contando `students.status == "active"`, deliberadamente sin tocar (F3) — S4 sigue facturando sobre ese mismo número. | 🟡 **Medio cerrado.** El join ya existe y es consumible por slices académicos (asistencia, notas-por-término, actividades, asignaciones — ver `LINEAMIENTOS_MVP.md`). Facturar sobre "matriculado en el término activo" en vez de `status == "active"` es una **decisión separada y explícita**, no reabierta aquí — ver Guardrails (§12) y `HISTORIA.md` v1.15.0. |

---

## 11. Próximas iteraciones (backlog ordenado)

> Orden sugerido por dependencia y riesgo. Cada iteración cierra con actualización de este documento (bump de versión) y una entrada en `HISTORIA.md`.

> **`LINEAMIENTOS_MVP.md`** (hermano de este archivo, desde v1.14.1) fija el alcance de un primer MVP
> concreto (colegio K-12: extracurriculares, comunicación, asignaciones académicas/responsabilidades,
> calendario del cuidador) y **reordena/reprioriza** los ítems de este backlog para ese perfil de
> cliente — léelo antes de elegir el próximo slice si el trabajo apunta a ese MVP. Camino crítico
> propuesto ahí (§7): ~~cerrar matrícula/término (B2/Cav.)~~ **✅ mitad de modelo cerrada (v1.15.0)**
> → ~~`attendance` (net-new)~~ **✅ cerrado (v1.16.0)** → ~~`report_cards` (boletines, net-new)~~
> **✅ cerrado (v1.17.0)** → ~~UI de tesorería (`finance`)~~ **✅ cerrado (v1.18.0)** →
> ~~`communication` anuncios~~ **✅ cerrado (v1.19.0)** → ~~`communication` mensajería~~ **✅ núcleo
> cerrado (v1.20.0)** → **`assignments` (net-new, siguiente)** → `calendar` (net-new) →
> `extracurriculars` (net-new) → portal del cuidador ampliado → provisioning + correo real. Dominios
> `student_support`/`counseling`/`cafeteria`/`transportation` reales no aplican
> a este perfil (no se piden) — no confundir con "backlog general cerrado".

1. **Módulo de autenticación/onboarding — lo que queda** (ver §9.1), en orden recomendado:
   1. ~~`Core::RosterImport::Parser/Validator/Committer`~~ — ✅ **cerrado para ambos kinds**
      (estudiantes v1.7.0, acudientes v1.8.0). Estructura por-kind ya lista para un tercer kind si
      alguna vez hiciera falta (`Strategy.for` + una nueva `Strategies::*`, sin tocar orquestación).
   2. ~~`Core::Access::GuardianScope` + portales de estudiante/acudiente~~ — ✅ **cerrado (v1.9.0)**, ver `HISTORIA.md`.
   3. ~~Vistas de autoservicio reales para docente/coordinador/director~~ — ✅ **cerrado (v1.10.0)**, ver `HISTORIA.md`.
   4. ~~Visor de `audit_events` + bandeja de discrepancias~~ — ✅ **cerrado (v1.11.0)**, ver `HISTORIA.md`. Con esto el track de onboarding queda cerrado salvo el punto 5 (opcional) abajo.
   5. Batch-invite tras el alta de acudientes, full-async de parse+validar, y purga de `roster_import_rows` post-commit — hardening documentado, no construido (ver `HISTORIA.md` v1.7.0).
   5. Job recurrente para `Invitations::Expirer` y webhook real para `Invitations::BounceHandler` (opcional / según necesidad real de producción, no bloqueante — único remanente del track).
2. ~~Cerrar CHECKPOINT E~~ (`staff_management` vs `human_resources`) — ✅ **cerrado (D1, v1.12.0)**, ver `HISTORIA.md`. Ya estaba resuelto en el esquema; este slice fue verificación + corrección de doc, sin migración.
3. ~~Cablear la puerta de auth real (gate #2, RBAC)~~ — ✅ **P1 cerrado (v1.6.0)**, ver `HISTORIA.md`.
4. **Vistas de negocio por dominio** — molde fijado (§6.6) en `teacher_management` (v1.13.0) y
   **barrido a los dominios cableables (v1.14.0)**:
   - ✅ **Cerrados (Clase A — modelos reales, molde aplicado)**: `teacher_management` +
     `staff_management` (v1.13.0); `group_management` (`Section`/`Student`, con escritura real de
     matrícula — `students.section_id` sí existe, a diferencia de `teacher.evaluate`); `schedules`
     **mitad de calificaciones** (`Subject`/`Enrollment`/`Assessment`, con registro de nota real);
     `counseling` (`Case`/`SessionNote`/`Referral`, carve-out sensible con caso de seguridad
     dedicado — ver `HISTORIA.md`).
   - 🔴 **Bloqueados-en-esquema (Clase C — sin tabla real, NO cablear sin un slice de modelado
     aparte)**: `cafeteria` (solo `DietaryRestriction` es real; menú/checkout/saldo no tienen
     ninguna tabla propia); `transportation` (cero modelos reales — ni siquiera parcial);
     `schedules` **mitad de horario/timetable** (`rooms`/`meeting_patterns` no existen);
     `student_support` — **corrección importante**: `disciplinary_logs`/`medical_history`/
     `accommodations` NO tienen ninguna tabla real (a diferencia de lo que un recon superficial
     asumiría por la presencia de query objects/rosters) — es Clase C igual que `transportation`,
     no un carve-out "sensible pero cableable".
   - ~~**`finance`**: Clase A por modelos, sin controller/ruta/vista~~ — ✅ **cerrado (v1.18.0)**:
     lectura+registro real de cargos/pagos (supervisión + portal del acudiente). `PaymentPlan`/
     `Installment` siguen sin UI (diferido a su propio slice — no alimentan el saldo).
   - `core` no es candidato de #4 en sí — no tiene controllers propios; sus recursos de negocio
     (`students`, etc.) ya viven en `group_management`.
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
- **El headcount cuenta `GroupManagement::Student.status == "active"` de la institución, NUNCA matrícula/término — a propósito, y esto sigue así aunque el join YA exista (v1.15.0, F3).** `enrollments.academic_term_id` (FK real) y `Schedules::ActiveTermEnrollmentScope` existen y son consumibles desde v1.15.0 — pero el headcount de facturación (S3a/S4) deliberadamente NO los usa. `academic_term_label` en el snapshot sigue siendo solo una etiqueta descriptiva, nunca un filtro del conteo. Facturar sobre "matriculado en el término activo" en vez de `status == "active"` es una **decisión de negocio separada y explícita** (reabrir Cav. del lado de facturación) — nunca un efecto colateral de cablear un consumidor académico del nuevo query object. Verificado con un test de regresión dedicado (`Core::Headcount::SnapshotterTest`, v1.15.0).
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
- **`GuardianScope`/`StudentSelfScope` siguen sin filtrar por término, por elección, no por limitación de esquema** — desde v1.15.0 el join `enrollments.academic_term_id`↔`academic_terms` SÍ existe (`Schedules::ActiveTermEnrollmentScope`), así que ya no es cierto que "no hay cómo". Estos self-scopes resuelven "mis hijos activos"/"mi propio registro" por relación pura, sin necesidad de acotar por término — agregarlo sería scope creep, no una corrección. Si un slice futuro quisiera "mis hijos matriculados este término" como una vista DISTINTA, compone `ActiveTermEnrollmentScope` aparte; no se modifica el self-scope existente.
- **El autoservicio de staff se gatea por identidad (self-scope en `services/access/`), nunca por `authorize!`** — muestra solo datos **propios** (perfil, roles vigentes, grupos/departamento derivados de las propias `role_assignments`). Mostrar a OTRA persona (mis colegas de departamento, mis estudiantes) es supervisión (backlog #4, RBAC con scope), no autoservicio — cruzar esa línea saca la vista de esta sección. Ninguna de estas superficies (student/guardian/staff) vive en `Navigation::Registry`, porque esa lista SIEMPRE filtra por `can?`; se enlazan aparte (header del shell / portal).
- **El filtro de término activo es real solo donde el FK existe** — `role_assignments.effective_now` (P1); `enrollments.academic_term_id`↔`academic_terms` (v1.15.0, matrícula por término, cierra la mitad de modelo de Cav.). **La salvedad B2 sigue vigente para `role_assignments.valid_from/until`** (fechado independiente del calendario lectivo, sin FK a `academic_terms` — un borde DISTINTO al de matrícula, no tocado por v1.15.0). `schedules`' mitad de horario/timetable sigue sin ninguna tabla real (ni parcial) — cualquier tile que lo use hoy es necesariamente vista previa sobre el stub existente, marcada como tal, nunca presentada como dato real. El headcount de facturación sigue sin filtrar por término A PROPÓSITO (ver el guardrail de headcount, arriba) — no confundir "el join ya existe" con "todo lo que toca estudiantes ya filtra por término".
- **El visor de auditoría se gatea por RBAC (`authorize!`), a diferencia de las superficies self-service — y `audit_events` es append-only: ninguna vista lo muta.** Un futuro "marcar atendida" (si se construye) **es un evento nuevo append** (`Audit.log` de, p. ej., `discrepancy_acknowledged`) con estado **derivado** de su presencia — nunca un `UPDATE` sobre la fila original (la BD ya lo impediría: `REVOKE UPDATE, DELETE ON audit_events FROM edu_app_runtime`).
- **Los filtros del visor de auditoría nunca son un directorio de estudiantes** — actor/acción/fecha sobre metadata, con acción tomada de un **conjunto conocido** (`IdentityAccess::AuditEventIndex::ACTIONS`), jamás texto libre ni autocompletado de personas (Habeas Data, mismo invariante que `GuardianScope`). El filtro de actor sí lista al STAFF de la propia institución (no son menores; es la misma superficie ya visible en "Personas").
- **El staff vive en UN SOLO hogar (`staff_management`), y el docente es una especialización, no un dominio aparte** (CHECKPOINT E, D1, v1.12.0) — `StaffManagement::StaffMember` es el empleo generalizado de TODO staff (`department_id` **nullable** para no-académicos); `TeacherManagement::Teacher` es su extensión docente vía `teachers.staff_member_id` (FK **nullable, aditiva** — el link puede faltar sin que el perfil base esté incompleto). `Core::Access::StaffProfileScope` ya resuelve a ambos por identidad, sin distinguir. Esto **ya estaba en el esquema desde el primer commit** — no inventar una migración de "generalizar staff" sin releer `HISTORIA.md` v1.12.0 primero. Los directorios `StaffRoster`/`TeacherRoster`/`DepartmentRoster` **ya son reales** desde v1.13.0 (ver abajo).
- **El molde de vistas de negocio (#4) es `teacher_management` (los cinco esqueletos de §6.6, per-row `can?`); los demás dominios lo COPIAN, no lo reinventan** — un slice de #4 sobre `core`/`student_support`/`group_management`/`schedules`/`counseling`/`cafeteria`/`transportation` que introduce un query object de índice con una forma distinta a `TeacherScope`/`DepartmentScope`/`StaffScope` (institución explícita + per-row `can?` vía `.select`, nunca `default_scope`, nunca forzar `PermissionCheck#scope_for`) debe justificar por qué, no asumirlo por defecto.
- **#4 es supervisión: RBAC + scope + `Navigation::Registry`; la contracara del autoservicio (identidad, `/mis_datos`) — no confundir las dos superficies para un mismo dominio.** Un índice que muestra a OTRAS personas dentro del alcance del actor SIEMPRE lleva `authorize!` y vive en el registry; uno que muestra "lo mío" nunca lleva `authorize!` y nunca vive ahí. `teacher_management`/`staff_management` ya tienen ambas superficies simultáneamente y son el ejemplo canónico de que no se pisan: `/mis_datos` (autoservicio) y `/teacher_management/*`+`/staff_management/staff` (supervisión) leen las MISMAS tablas por caminos de acceso completamente distintos.
- **Triage A/B/C/S antes de cablear CUALQUIER dominio de #4** (barrido v1.14.0) — antes de aplicar el molde §6.6 a un dominio nuevo, verificar contra el disco (no contra la presencia de un query object/roster, que puede ser 100% stub) si sus tablas de negocio SON reales. `student_support` parecía cableable (tenía `queries/`/`services/` con nombres "reales") y resultó ser Clase C completo — cero migración para `disciplinary_logs`/`medical_history`/`accommodations` en todo el repo. **La señal real es `grep create_table` en `db/migrate/`, nunca la presencia de un archivo con nombre de query object.** Ver `CONCEPTOS_TECNICOS.md` para la taxonomía completa (A/B/C/S).
- **Un dominio con modelos reales pero CERO vista/controller (`finance`) no es lo mismo que un stub a reemplazar** — cablearlo es construir desde cero (rutas, controller, nav), no swapear una fuente de datos. Tratarlo como su propio slice de alcance distinto, no como un ítem más del barrido de #4.
- **`students.section_id`/`Schedules::Assessment` ya existían como target real** — a diferencia de `teacher.evaluate` (v1.13.0, sin modelo destino), la acción de matrícula de `group_management` y el registro de nota de `schedules` SÍ se cablearon como escritura real completa, no solo el gate. La regla general (BV6): cablear el gate siempre; el workflow completo SOLO si el modelo destino ya existe — verificarlo caso por caso, no asumir "gate-only" por defecto.
- **`Schedules::ActiveTermEnrollmentScope` es EL resolver canónico de "estudiante matriculado en el término activo"** (v1.15.0, cierra la mitad de modelo de Cav./B2) — todo slice académico futuro (asistencia, notas-por-término, actividades, asignaciones, ver `LINEAMIENTOS_MVP.md`) lo CONSUME, no re-deriva su propio join a `academic_terms`. No es identity-gated (a diferencia de `GuardianScope`/`StudentSelfScope`) ni RBAC-scoped por sí mismo — resuelve el hecho académico crudo; cada consumidor aplica su propio scope de RBAC encima (mismo layering que `TeacherManagement::TeacherScope`). Solo un término activo por institución (invariante de BD ya existente) — el query NUNCA reimplementa esa resolución, solo lee `Core::AcademicTerm.active`.
- **"Roster tomable" = resolver académico ∩ scope de negocio ∩ scope RBAC — tres capas, nunca colapsadas en una** (`attendance`, v1.16.0, primer consumidor real de `ActiveTermEnrollmentScope`): (1) `ActiveTermEnrollmentScope.resolve(institution:)` — el hecho crudo, institución completa; (2) `.where(section_id: group.id)` — el scope de NEGOCIO (este grupo/homeroom); (3) `authorize!("attendance.record", group)` + el query object per-row (`Attendance::GroupScope`) — el scope de RBAC del actor (sus propios grupos). El mismo layering aplica a todo slice académico futuro que "actúe sobre los alumnos de un grupo en el término activo" (notas-por-término, actividades, asignaciones) — no reinventar el orden ni colapsar las tres capas en una sola query ad hoc.
- **Un dominio net-new addon-gated real desde el día uno (sin fase stub) es un patrón válido** (`attendance`, v1.16.0) — a diferencia de los dominios de la Fase 0 (que nacieron 100% stub y se cablearon después, backlog #4), un dominio construido HOY con recon-first + checkpoint de diseño no necesita pasar por una fase de roster en memoria: el modelo real, el query object y las vistas se construyen en el mismo slice.
- **Un snapshot congelado al publicar NUNCA se recomputa al leer** (`report_cards`, v1.17.0) — `ReportCards::Publisher` llama a `ReportCards::Computation` UNA sola vez, en el momento de publicar, y persiste el resultado en `lines_snapshot`/`overall_average`. Ningún controller/vista de un `ReportCard` ya publicado vuelve a tocar `Schedules::Assessment`; editar una nota viva después de publicar nunca cambia lo ya publicado (verificado con un test de regresión dedicado, el análogo del test de headcount). El "draft" es la única superficie que lee en vivo (`ReportCards::Computation`, consumido también por el preview de supervisión) — nunca hay una fila con `status: "draft"` hoy (ver el modelo de datos: la fila solo existe al publicar).
- **`ReportCard#readonly?` (= `persisted?`, mismo patrón que `ControlPlane::InvoiceLineItem`) bloquea `update`/`destroy` de una fila individual — la regeneración va SIEMPRE por `delete_all` + `create!` desde `ReportCards::Publisher`, nunca por un `destroy_all`/`update` sobre el AR object.** `destroy_all` instancia cada registro y llama a `#destroy`, que Rails bloquea si `readonly?` es true (a diferencia de `delete_all`, que emite el DELETE en bulk sin pasar por el guard) — el mismo error que atrapó a este slice en desarrollo (`ActiveRecord::ReadOnlyRecord` al intentar `destroy_all`). Mismo balance que `ControlPlane::Billing::PeriodCut` ya documenta para `InvoiceLineItem`: "una línea no se edita nunca" ≠ "un snapshot no se regenera nunca".
- **El portal de una persona (§ guardrail de arriba, `GuardianScope`/`StudentSelfScope`) sigue sin chequear `Entitlement::Registry`** (`report_cards`, v1.17.0, mismo patrón ya implícito en `cafeteria`/`transportation`'s portal stubs) — `Entitlement::Controller` infiere el `addon_key` del namespace del controller (`Portals::*`, nunca registrado), así que ningún controller de portal queda gateado por addon hoy. Es una superficie ya aceptada, no un gap nuevo de este slice — si algún día se decide gatear el portal también, es una decisión de diseño explícita (probablemente `gated_by_addon`), no un efecto colateral de cablear un dominio addon-gated más.
- **`report_cards` es el segundo consumidor real (tras `attendance`) del layering de tres capas de §"Roster tomable" — y confirma que la RBAC puede partirse en dos permisos (`report_card.view`/`report_card.publish`) sobre las MISMAS tres capas**, a diferencia de `attendance.record` (un solo permiso). Publicar es una acción más sensible que previsualizar (mismo espíritu que el split `accommodations.view`/`accommodations.manage`) — un dominio futuro con esa misma asimetría debe partir el permiso, no forzar uno solo por "seguir el molde de attendance" literalmente.
- **El dinero de `finance` (`student_accounts.balance`, `charges.amount`, `payments.amount`, `payment_plans.total_amount`, `installments.amount`) es `decimal(12,2)`, NO `*_cents bigint`** (`finance`, v1.18.0) — comiteado en el primer commit del repo, antes de que F6 (cents-bigint) se adoptara para el billing del control plane. `decimal`/`BigDecimal` es aritmética exacta en Postgres/Ruby, no tiene el problema de drift que F6 previene — es una representación DISTINTA, igualmente segura, no una violación de F6 disfrazada. **No migrar estas columnas a bigint-cents "para unificar" sin una razón de negocio explícita** — el invariante real y no negociable aquí es "nunca castear a Float, toda la aritmética de saldo en `BigDecimal`", verificado con tests que comparan `BigDecimal` exacto, nunca `Float`. F6 (cents-bigint) sigue vigente para todo lo que nace en el control plane (`ControlPlane::Addon`/`Invoice*`/`Subscription`) — los dos esquemas de dinero coexisten a propósito, por historia, no por descuido.
- **Toda escritura de dinero pasa por un servicio, nunca por el controller directo, y es transaccional con row lock (`account.lock!`) sobre `StudentAccount`** (`Finance::PaymentRecorder`/`Finance::ChargeCreator`, v1.18.0) — el `Payment`/`Charge` y el update del saldo ocurren en la MISMA transacción; si cualquier paso falla (p. ej. un `method`/`status` que viola el `CHECK` de la BD), la transacción entera revierte y no queda ni el registro de dinero ni el saldo tocado (verificado con un test de atomicidad dedicado). El lock es pessimista (`.lock!`, serializa) sobre el `lock_version` optimista que la tabla YA tenía desde el primer commit — ambos coexisten sin conflicto porque el lock pessimista impide que la condición de carrera que el optimista detectaría llegue a ocurrir.
- **Idempotencia de pago/cargo: el controller genera un `idempotency_key` una sola vez en `#new` (campo oculto), y el servicio lo usa como guarda — un re-submit del MISMO formulario nunca duplica** (`finance`, v1.18.0) — `Finance::Payment`/`Finance::Charge` YA tenían una columna `idempotency_key` con índice único por institución desde el primer commit (sin usar hasta este slice); el servicio chequea esa clave ANTES y DESPUÉS de tomar el lock (para cerrar la ventana de carrera entre el pre-check y adquirir el lock), y el índice único de la BD es el backstop final si dos requests corrieran verdaderamente en paralelo.
- **Un solo camino de lectura del estado de cuenta (`Finance::AccountStatement`), consumido por supervisión Y portal** (`finance`, v1.18.0) — mismo patrón que `ReportCards::Computation` (v1.17.0): una sola computación, dos superficies, así que las cifras nunca pueden discrepar entre sí. `Finance::Charge` no tiene FK a `Finance::StudentAccount` (solo a `student_id` directo) — este servicio es el único lugar que puentea cuenta→estudiante→cargos, no reinventar ese puente en otro lugar.
- **`finance` ya estaba addon-gated, en `Navigation::Registry` y con sus permisos (`finance.read`/`finance.write`) sembrados desde ANTES de que existiera un controller real** (`config/entitlements/finance.rb`/`ControlPlane::AddonCatalog::DOMAIN_KEYS`/`config/navigation/finance.rb`, todos desde v1.3.0/S2b) — un recon que asuma "dominio sin gating porque no tiene UI todavía" puede estar equivocado; verificar siempre contra `Entitlement::Registry.domains`/`ControlPlane::AddonCatalog::DOMAIN_KEYS`, nunca contra la presencia de un controller. **`finance.read` también lo reusa `Cafeteria::BalancesController`** (su propia función de "Saldos", sin relación con este slice) — cualquier cambio futuro al significado de `finance.read` debe revisar ese consumidor cruzado.
- **El portal de una persona sigue sin chequear `Entitlement::Registry`, ahora confirmado también para `finance`** (mismo gap ya aceptado de `cafeteria`/`transportation`/`report_cards`, v1.17.0) — un acudiente podría ver el estado de cuenta de su hijo aunque la institución no tenga el addon `finance` contratado. Es el caso que más motivaría cerrar ese gap (dinero, no solo notas/asistencia) — pero sigue siendo una decisión de diseño separada (`gated_by_addon` explícito en los controllers de `Portals::*`), no algo que este slice decidiera resolver.
- **Planes de pago/cuotas (`PaymentPlan`/`Installment`) siguen sin ninguna UI y NO alimentan el saldo** (`finance`, v1.18.0, confirmado por recon de modelo: `Installment` no tiene ningún callback/servicio que lo conecte a `StudentAccount.balance`) — el estado de cuenta de este slice es completo y correcto SIN ellos, no una vista parcial. Cablearlos es su propio slice futuro (gestión de cuotas + su propio efecto sobre el saldo, a decidir ahí).
- **"Membresía" es un TERCER tipo de gate, distinto de RBAC y de self-service/relación** (`communication` anuncios, v1.19.0) — RBAC (`authorize!` + scope + `Navigation::Registry`) protege una acción/recurso específico; self-service/relación (`GuardianScope`/`StudentSelfScope`) protege "lo mío"; membresía protege "cualquier miembro activo de esta institución, sin distinción de rol" — más amplio que ambos, pero todavía tenant-scoped (nunca cross-tenant). Su forma: sin `authorize!`, sin permiso, fuera de `Navigation::Registry`, enlazado aparte (mismo `shared/_self_service_link.html.erb`-style partial, ver `shared/_announcements_link.html.erb`), gateado por `Current.entitled_addon_keys.include?(domain)` en vez de por `can?`. El controller sigue viviendo bajo el namespace del dominio (`Communication::FeedController`), así que `Entitlement::Controller` lo sigue gateando por inferencia de namespace igual que cualquier otro — "membresía" cambia el gate #2 (RBAC → ninguno), nunca el gate #1 (entitlement).
- **Publicar (RBAC) y leer (membresía) son DOS superficies con gates distintos sobre el MISMO dominio, y NUNCA se colapsan en una** (`communication` anuncios, v1.19.0) — mismo espíritu que supervisión vs. autoservicio en `teacher_management`, pero con membresía en vez de self-service del lado de lectura. `Communication::AnnouncementsController` (gestión, `announcement.publish`) y `Communication::FeedController` (lectura, membresía) son controllers DISTINTOS aunque lean la misma tabla — un slice futuro que necesite "publicar Y leer" en el mismo dominio debe replicar este split, no fusionar ambos gates en un controller.
- **Retract es SIEMPRE soft (`status` + `retracted_at`), nunca `destroy`** (`Communication::Announcement#retract!`, v1.19.0) — mismo principio que `audit_events` (append-only) y el soft-delete de otros dominios: un anuncio retractado sobrevive como fila, solo desaparece de `Communication::AnnouncementFeed` (que filtra `status: "published"`). Verificado con un test dedicado que confirma la fila sigue existiendo tras retractar.
- **Un solo camino de lectura (`Communication::AnnouncementFeed`), compartido por staff Y ambos portales** (`communication` anuncios, v1.19.0) — mismo patrón que `Finance::AccountStatement`/`ReportCards::Computation`: una sola query, N superficies, nunca pueden discrepar. A diferencia de `finance`/`report_cards` (per-hijo/per-cuenta), este feed es institución-wide — ninguna superficie de lectura pasa por `GuardianScope`/`StudentSelfScope`, el scope es `Current.institution` a secas.
- **`communication` ya estaba addon-gated desde S2b/v1.3.0 (como `finance`) — pero, a diferencia de `finance`, NO tenía entrada en `Navigation::Registry` todavía** — un recon que asuma "si está gateado, también tiene nav" puede estar equivocado; cada pieza (`Entitlement::Registry`, `AddonCatalog::DOMAIN_KEYS`, `Navigation::Registry`, `SeedPermissions::CATALOG`) se verifica por separado, nunca se infiere una de la presencia de otra.
- **Cuatro caminos de acceso sobre el MISMO conjunto de tablas, nunca colapsados** (mensajería, v1.20.0, la versión más elaborada del principio ya establecido por anuncios v1.19.0): iniciar (RBAC, `conversation.compose`, controller `Communication::ConversationsController`) / bandeja+responder (participación, sin `authorize!`, `Communication::InboxController` + `Communication::MessagesController`, mismo query compartido `Communication::Inbox` que usa el portal del acudiente) / auditar (RBAC, `conversation.audit` — permiso **distinto** de compose a propósito — `Communication::ConversationAuditsController`). Cuatro controllers, no uno con ifs por acción.
- **Identidad de un participante/emisor de mensajería: `institution_user_id` (staff) XOR `guardian_user_id` (acudiente, FK directa a `users` — el MISMO handle que `guardian_students.guardian_user_id`, nunca `institution_user_id` aunque el acudiente también tenga esa fila)** — un `CHECK (num_nonnulls(institution_user_id, guardian_user_id) = 1)` real en la BD lo garantiza, no solo la validación de modelo (verificado con un test que inserta SQL crudo bypaseando ActiveRecord). Las columnas de identidad usan `on_delete: :cascade` (no `nullify`) — a diferencia de columnas de atribución pura como `conversations.created_by_institution_user_id` — porque una fila sin ninguna identidad violaría el CHECK; mismo criterio que `guardian_students.guardian_user_id` ya usa.
- **"Staff" para el selector de destinatarios de mensajería significa específicamente un `institution_user` respaldado por una fila `StaffManagement::StaffMember`, NUNCA "cualquier `institution_user` activo"** — un acudiente TAMBIÉN tiene una fila `institution_users` (así puede loguearse; `Core::People::Resolver` la crea siempre), así que "todo membership activo" incluiría acudientes en la lista de "personal" por error. La señal correcta es la fila `StaffMember`, nunca "tiene cero `role_assignments`" (una persona de staff recién invitada, sin rol asignado todavía, se vería como acudiente bajo esa señal).
- **El selector de destinatarios acotado para iniciar una conversación NO reusa `Schedules::ActiveTermEnrollmentScope`** (mensajería, v1.20.0) — ese resolver es de elegibilidad académica (matrícula por materia en el término activo), semánticamente ajeno a "de qué estudiantes es responsable este staff para efectos de contactar a sus acudientes". El layering de tres capas se preserva (scope RBAC del actor sobre grupos ∩ estudiantes del grupo ∩ acudientes vía `GuardianStudent`) pero la capa "hecho crudo" es `GroupManagement::Section#students`, no el resolver de `schedules`. Un futuro slice que necesite acotar por estudiantes debe evaluar cuál resolver es semánticamente correcto, no copiar el molde de `attendance`/`report_cards` por inercia.
- **El log de auditoría de una conversación (`conversation_audited`) se escribe si y solo si el accesor tiene `conversation.audit` Y NO es participante** — un participante que también audita leyendo SU PROPIA conversación (por cualquiera de los dos caminos: bandeja o ruta de auditoría) nunca genera el evento; la comprobación es siempre "¿existe una fila `conversation_participants` para este actor en esta conversación?", nunca "¿qué ruta usó para llegar aquí?". El rastro nunca se muestra a los participantes — solo existe en el visor RBAC-gated de `audit_events` (`IdentityAccess::AuditEventIndex::ACTIONS`, ahora también escrito desde fuera de `identity_access`, ver esa constante).
- **Cerrar una conversación es SIEMPRE soft** (`status`+`closed_at`+`closed_by_institution_user_id`) — los mensajes y participantes de una conversación cerrada nunca se borran, y una conversación cerrada simplemente rechaza nuevas respuestas (`Communication::MessageSender` chequea `conversation.active?`) hasta que un participante-staff la reabre. Un acudiente participante nunca tiene la acción de cerrar/reabrir expuesta — no por una verificación extra en el controller, sino porque su fila de participante usa `guardian_user_id`, nunca `institution_user_id`, así que su identidad simplemente no calza con la búsqueda de participante que usa `Communication::InboxController` (staff-only por construcción, no por chequeo).

---

## 13. Changelog

El changelog completo (`v1.0.0` → `v1.20.0`) vive en **`HISTORIA.md`**. Entrada de esta versión:

- **`v1.20.0` — `communication`: mensajería (ítem #5b del MVP, subsistema (B), núcleo).** Tres
  tablas net-new (`conversations`/`conversation_participants`/`messages`) — confirmado por recon
  que no existía nada real, solo el borrador del anexo. Gating de `communication` reusado tal cual
  (ya estaba desde v1.19.0); nav nueva para compose y auditoría (`Navigation::Registry`, dos
  entradas RBAC, la bandeja se queda fuera del registry, mismo criterio que el feed de anuncios).
  Identidad de participante/emisor: `institution_user_id` XOR `guardian_user_id` (CHECK real
  `num_nonnulls(...) = 1`, cascade en ambas identidades — mismo handle que
  `guardian_students.guardian_user_id`, nunca `institution_user_id` para un acudiente aunque
  también tenga esa fila). Cuatro caminos de acceso sobre las mismas tres tablas, cuatro
  controllers distintos: `ConversationsController` (compose, RBAC, destinatarios acotados —
  staff ∪ acudientes de estudiantes en el scope RBAC del actor, nunca un directorio) →
  `InboxController`/`Portals::GuardianInboxController` (bandeja+responder, participación, sin
  `authorize!`, `Communication::Inbox` compartido) → `ConversationAuditsController` (auditoría,
  RBAC, permiso `conversation.audit` distinto de compose, log condicional `conversation_audited`
  en `audit_events` solo si el accesor no es participante). **Ajuste de diseño reportado**: el
  selector de destinatarios NO reusa `Schedules::ActiveTermEnrollmentScope` (semánticamente ajeno a
  "de quién es responsable este staff para mensajería") — usa `GroupManagement::Section#students`
  como hecho de negocio crudo en su lugar. Cerrar es soft; sin threading; sin tags; acudiente
  responde pero nunca inicia. 455→472 tests totales (17 nuevos). Narrativa completa en `HISTORIA.md`.
- **`v1.19.0` — `communication`: anuncios (ítem #5 del MVP, subsistema (A) only).** Recon confirmó
  que `communication` ya estaba addon-gated (`config/entitlements/communication.rb`,
  `AddonCatalog::DOMAIN_KEYS`, `SeedCatalog::ADDONS` — metered "mensajes", provisional para la
  mensajería futura) pero SIN entrada en `Navigation::Registry` ni permisos `communication.*`/
  `announcement.*` — a diferencia de `finance`, el gating estaba pero el nav no; se creó
  `config/navigation/communication.rb` y el permiso `announcement.publish` desde cero. Tabla
  `announcements` dedicada (NO el modelo unificado `conversations` que el anexo viejo de §8
  proponía — decisión explícita del owner: mensajería, cuando se construya, es estructuralmente
  distinta y se diseña fresca en su propio slice). Autor vía `author_institution_user_id` (mismo
  patrón que `audit_events.actor_institution_user_id`, no `staff_member_id` como hizo
  `report_cards` — publicar es una acción administrativa, no una extensión docente). Dos
  superficies con gates DISTINTOS: gestión (`Communication::AnnouncementsController`,
  `authorize!("announcement.publish")` + Registry) y lectura (`Communication::FeedController`, gate
  nuevo de **membresía** — sin `authorize!`, sin permiso, fuera del Registry, gateado solo por
  `Current.entitled_addon_keys` — ver Guardrails). `Communication::AnnouncementFeed`: un solo
  camino de lectura compartido por staff + portal del acudiente + portal del estudiante (ninguno
  per-hijo/per-self-scope, a diferencia de `report_cards`/`finance` — un anuncio es institución-wide).
  Retract soft (`Announcement#retract!`), nunca `destroy`. `db/seeds.rb` NO se tocó (mismo alcance
  que `attendance`/`report_cards`/`finance` — el archivo no tiene ningún concepto de
  `institution_users`/anuncios/RBAC, es puramente demográfico). El anexo de `communication` (§8 de
  `PROJECT_STATE.md`) se reescribió para reflejar (A) real y registrar el spec completo de (B)
  mensajería que definió el owner, con sus 3 preguntas de diseño abiertas — sin construir nada de
  eso. 442→455 tests totales (13 nuevos). Narrativa completa arriba, en §8.

- **`v1.18.0` — `finance`: UI de tesorería (ítem #4 del MVP, primera superficie sobre modelos ya
  reales).** Recon reveló que `finance` ya estaba addon-gated (`config/entitlements/finance.rb`,
  `AddonCatalog::DOMAIN_KEYS`, `SeedCatalog::ADDONS`), ya tenía entrada en `Navigation::Registry`, y
  ya tenía permisos `finance.read`/`finance.write` sembrados a `institution_admin` y reusados por
  `Cafeteria::BalancesController` — todo desde v1.3.0/S2b. Cero de eso se reconstruyó; se reusó tal
  cual (no se inventaron `finance.view`/`finance.manage`). Segundo hallazgo material: el dinero es
  `decimal(12,2)`, no `*_cents bigint` (comiteado antes de que F6 existiera) — se mantuvo la
  representación (exacta, sin drift de float) en vez de migrar el esquema. `idempotency_key` (con
  índice único por institución) ya existía sin usar en `charges`/`payments` desde el primer commit —
  este slice lo activó como guarda real de doble-submit. `Finance::PaymentRecorder`/
  `Finance::ChargeCreator`: transaccionales, con `account.lock!` (pessimista, coexiste sin conflicto
  con el `lock_version` optimista ya presente). `Finance::AccountStatement`: un solo camino de
  lectura (mismo patrón que `ReportCards::Computation`, v1.17.0) consumido por supervisión (molde #4,
  scope institución-wide — tesorería es función central, no por grupo) y portal del acudiente (solo
  lectura, sin riel de pago, sin gating por entitlement — mismo gap ya aceptado de `report_cards`).
  `PaymentPlan`/`Installment` confirmados sin ninguna conexión al saldo — quedan sin UI, diferidos.
  428→442 tests totales (14 nuevos). Narrativa completa en `HISTORIA.md`.
- **`v1.17.0` — `report_cards`: boletines (ítem #3 del MVP, dominio net-new).** Checkpoint de diseño
  (aprobado): dominio propio, addon-gated, lee `schedules` por FK (nunca posee `Subject`/
  `Enrollment`/`Assessment`). `report_cards` (`student_id`+`academic_term_id`, único
  `(institution_id, student_id, academic_term_id)`, `lines_snapshot` jsonb + `overall_average`
  congelados al publicar, `published_by_staff_member_id` nullable). Recon: `Schedules::Assessment`
  ya traía `weight`/`max_score` — no existía lógica de promedio/GPA en `schedules`, así que
  `ReportCards::Computation` la introduce (normaliza cada nota a la escala 0.0–5.0 antes de
  ponderar; una materia sin notas cargadas no aporta línea, nunca un cero). El roster tomable es la
  MISMA intersección de tres capas que `attendance` (v1.16.0): `Schedules::ActiveTermEnrollmentScope`
  ∩ el grupo ∩ el scope RBAC del actor — pero con permisos split (`report_card.view`/
  `report_card.publish`) en vez de uno solo. Publicación real, síncrona, idempotente
  (`ReportCards::Publisher`): regenera vía `delete_all`+`create!`, nunca `update`/`destroy_all` sobre
  el AR object (`ReportCard#readonly? = persisted?` lo bloquea — mismo patrón que
  `ControlPlane::InvoiceLineItem`/`PeriodCut`). Invariante estrella verificado con test dedicado: un
  boletín publicado nunca re-lee una nota editada después. Dos superficies: supervisión (molde #4)
  y portal (por relación, solo publicados, sin `authorize!`, fuera de `Navigation::Registry`) — el
  portal de persona sigue sin chequear entitlement (mismo gap ya aceptado en `cafeteria`/
  `transportation`, no nuevo de este slice). Headcount y `ActiveTermEnrollmentScope` verificados
  intactos. Una migración, aplicada en dev y test. 21 tests nuevos (428 runs totales, 0 fallos).
  Narrativa completa en `HISTORIA.md`.
- **`v1.16.0` — `attendance`: asistencia diaria por homeroom (ítem #2 del MVP, dominio net-new).**
  Checkpoint de diseño (aprobado): dominio propio, addon-gated, diaria por homeroom — no `schedules`
  (grano equivocado, por materia) ni `group_management` (fundacional, y asistencia es addon-able).
  `attendance_records` (`student_id`+`group_id`+`date`, único `(institution_id, student_id, date)`,
  `recorded_by_staff_member_id` nullable). El roster tomable es la intersección de tres capas:
  `Schedules::ActiveTermEnrollmentScope` (hecho académico crudo, nunca re-derivado) ∩ el grupo
  (scope de negocio) ∩ el scope RBAC del docente (`Attendance::GroupScope`, molde #4 completo:
  per-row `can?`, `authorize!("attendance.record")`, nav). Escritura real en lote idempotente
  (re-tomar el mismo grupo+fecha actualiza, nunca duplica — la unicidad lo garantiza). Portal del
  cuidador explícitamente fuera (ítem #9). Headcount y `ActiveTermEnrollmentScope` verificados
  intactos. Una migración, aplicada en dev y test. Narrativa completa en `HISTORIA.md`.
- **`v1.15.0` — matrícula por término real (ítem #1 del camino crítico del MVP, cierra la mitad de
  modelo de Cav./B2).** Recon corrigió la premisa del prompt: no hay una tabla `core.enrollments`
  separada — existe UNA sola tabla `enrollments`, ya modelada como `Schedules::Enrollment` desde
  v1.14.0. Se agregó `academic_term_id` (FK nullable, aditiva) conectándola con `academic_terms`;
  `term` (string legacy) coexiste sin tocar, mismo patrón que `guardian_students`/
  `student_guardians`. Nuevo resolver canónico `Schedules::ActiveTermEnrollmentScope` ("estudiantes
  matriculados en el término activo"), sin buscador, tenant-scoped. `GradeEntriesController#create`
  ahora también resuelve y guarda el término activo (el único write-path real de `Enrollment` hoy).
  `db/seeds.rb` gana un `AcademicTerm` activo real por institución (antes cero — el join habría
  quedado inerte en datos de demo). **F3 respetado**: `Core::Headcount::Snapshotter` sigue contando
  `students.status == "active"`, verificado con un test de regresión dedicado. Sin cambios a B2
  (fechado de `role_assignments`, un borde distinto). Narrativa completa en `HISTORIA.md`.
- **`v1.14.1` — patch editorial: `LINEAMIENTOS_MVP.md`.** Se agregó como archivo hermano de este
  documento, fijando el alcance de un primer MVP concreto (colegio K-12: extracurriculares,
  comunicación, asignaciones académicas/responsabilidades, calendario del cuidador) sobre el estado
  real v1.14.0. No es un prompt de implementación — reordena/prioriza el backlog de §11 para ese
  perfil de cliente. Sin cambios de código, sin migraciones. Ver `HISTORIA.md` para el detalle de
  qué decisiones quedó resolviendo y cuáles siguen abiertas.
- **`v1.14.0` — #4 barrido: el molde aplicado a todos los dominios cableables.** Triage completo de
  los 8 dominios candidatos (A/B/C/S). Cableados (Clase A, copiando el molde de `teacher_management`
  literal): `group_management` (`Section`/`Student`, con escritura real de matrícula — el destino
  `students.section_id` ya existía); `schedules` mitad de calificaciones (`Subject`/`Enrollment`/
  `Assessment`, con registro de nota real); `counseling` (sensible, incluida a pedido explícito del
  usuario con caso de seguridad dedicado: aislamiento cross-tenant verificado con query real bajo
  RLS a nivel de MODELO, no solo HTTP). **Corrección de recon durante el barrido:** `student_support`
  parecía candidato sensible cableable pero resultó Clase C completo — cero tabla real para
  `disciplinary_logs`/`medical_history`/`accommodations` en todo `db/migrate/`, a pesar de tener
  query objects/rosters con nombres "reales". `cafeteria`/`transportation` confirmados Clase C
  (sin modelos reales de negocio). `finance` diferido (modelos reales pero cero vista/controller —
  alcance distinto a un swap de stub). Ningún dominio Clase C recibió tabla/columna inventada; cero
  migraciones en todo el slice. Narrativa completa, con el detalle de la corrección de
  `student_support` y el caso de seguridad de `counseling`, en `HISTORIA.md`.
- **`v1.13.0` — #4 slice 1: `teacher_management` como referencia canónica + directorios de staff
  reales.** Primer slice del backlog de vistas de negocio por dominio. Los cinco esqueletos de §6.5
  se probaron por primera vez contra datos reales (§6.6): `TeacherManagement::TeacherScope`/
  `DepartmentScope` y la nueva `StaffManagement::StaffScope` leen `Teacher`/`Department`/
  `StaffMember` reales con el mismo patrón per-row `can?` que ya tenían (nunca `default_scope`,
  nunca forzar `PermissionCheck#scope_for`). `Teacher#department_id`/`#status` delegan a
  `staff_member` (nil-safe — un docente sin vincular no es un error); `Department#department_id`
  aliasa `id` para el descriptor de scope. Se retiraron los tres rosters en memoria
  (`TeacherRoster`, `DepartmentRoster`, `StaffRoster`) que CHECKPOINT E (v1.12.0) había dejado
  model-ready pero sin consumidor real. `teacher.evaluate` sigue sin modelo de evaluación real
  (BV6) — el slice cableó el GATE per-row sobre un `Teacher` real, no un CRUD nuevo. El caso de
  María (§6.4) se extendió contra las vistas reales (índice/show/acción), no solo el `authorize!`
  unitario. Sin migraciones. Narrativa completa, con el hallazgo de un test de `transportation_test.rb`
  que dependía de la fixture hardcodeada del stub retirado, en `HISTORIA.md`.
- **`v1.12.0` — CHECKPOINT E cerrado (D1): staff generalizado, docente como especialización.**
  Recon reveló que la generalización pedida ya existía en el esquema desde el primer commit del
  repo (`637a998`, previo al track de onboarding): `StaffManagement::StaffMember` (empleo de TODO
  staff, `department_id` nullable) + `TeacherManagement::Teacher` (extensión docente vía
  `teachers.staff_member_id`, FK nullable/aditiva) + `Core::Access::StaffProfileScope` (v1.10.0, ya
  leía `StaffMember` sin distinguir docente/no-docente). **Ninguna migración, ningún rename** — el
  gap real era la falta de verificación end-to-end para un staff NO docente y un `PROJECT_STATE.md`
  desactualizado. Se agregó un test de aceptación (personal de cocina, departamento operacional, CERO
  fila `Teacher`) que prueba que el autoservicio resuelve idéntico al de un docente. Los directorios
  `StaffRoster`/`TeacherRoster` (aún stub) quedan explícitamente como backlog #4, no parte de este
  checkpoint. Narrativa completa, con el detalle del recon que encontró esto, en `HISTORIA.md`.
- **`v1.11.0` — Onboarding: visor de `audit_events` + bandeja de discrepancias.**
  `IdentityAccess::AuditEventIndex` — tenant-scoped, filtros actor/acción(conjunto conocido)/fecha,
  paginado (`PER_PAGE = 25`), nunca `default_scope`. Alimenta el visor
  (`/identity_access/audit_events`) y la bandeja de discrepancias
  (`/identity_access/audit_events/discrepancies`, la MISMA query con `action` fijo al marcador de
  `DiscrepancyReporter` — no una tabla nueva). Gateado por RBAC (`audit_events.read`, permiso nuevo en
  el catálogo), **no** por identidad — la inversión deliberada respecto a los portales/autoservicio
  de v1.9.0/v1.10.0. `shared/_audit_entry_row` (existía sin consumidor real) queda cableado.
  Hallazgo del recon: ninguno de los dos índices existentes de `audit_events` soportaba una lectura
  ordenada por `created_at` con `institution_id`-leading — única migración del slice
  (`add_index`, sin tabla nueva). Caso de aceptación de seguridad verificado end-to-end: filtros
  componen, aislamiento cross-tenant bajo RLS real, 403 sin el permiso, sin superficie de búsqueda
  de personas, append-only intacto. Narrativa completa en `HISTORIA.md`.
- **`v1.10.0` — Onboarding: autoservicio de staff ("mis datos").** `Core::Access::
  {StaffProfileScope,StaffRoleAssignmentsScope}` (mismo molde que `GuardianScope`/
  `StudentSelfScope`) resuelven perfil y roles vigentes de cualquier staff por identidad, sin
  `authorize!`. "Mis grupos"/"mi departamento" se derivan de las columnas de scope de las propias
  `role_assignments` — no existe ningún vínculo directo profesor↔grupo en el esquema. Hallazgo del
  recon: `schedules` no tiene ninguna tabla real (ni parcial); decisión con el usuario: el tile de
  horario queda como vista previa explícita sobre el stub existente, filtrada por identidad. Sin
  migraciones. Caso de aceptación de seguridad (vigente vs. expirado, propio vs. otra persona,
  cross-tenant, identity-gating con cero permisos, entitlement) verificado end-to-end. Narrativa
  completa en `HISTORIA.md`.
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
