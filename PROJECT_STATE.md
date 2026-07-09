# edu_platform — Estado del proyecto (documento maestro)

> **Qué es este documento.** La **fuente única de verdad de contexto** del proyecto `edu_platform`.
> Consolida estructura, arquitectura y diseño, más los cambios ya implementados (asumiendo que todo
> lo iterado en los chats previos fue ejecutado) y el backlog de próximas iteraciones. Cuando haya
> que consultar o decidir algo sobre el proyecto, **este archivo es el estado actual** — se lee
> primero, se referencia, y se actualiza al cerrar cada iteración.
>
> **El repositorio sigue siendo la fuente de verdad del código.** Este documento describe intención,
> decisiones y contexto; ante discrepancia entre lo escrito aquí y lo que hay en disco, gana el
> repositorio, y se corrige este documento en la siguiente versión.

---

## Metadatos de versión

| Campo | Valor |
|---|---|
| **Versión del documento** | `v1.3.0` |
| **Fecha** | 2026-07-09 |
| **Estado del proyecto** | Identidad real ya funciona: login nativo + MFA por correo, registro por invitación, y gestión de personas (crear/invitar/suspender) corriendo contra datos reales. El plano de control tiene auth real de `platform_admins`, catálogo `addons`/`plans`/`plan_price_tiers` con CRUD (S1), y ahora también `subscriptions`/`institution_entitlements` con CRUD real y snapshot de tarifa inmutable (S2a). La **primera compuerta de acceso ya es real de punta a punta**: `Core::Institution#entitled?` + el gate `Entitlement::Controller` + la nav filtrada deciden, con datos reales, si una institución puede usar un dominio addon-gated — antes de que la segunda compuerta (RBAC) entre a jugar, la cual **sigue** sobre `Authorization::StubResolver` (S2b; P1 sin tocar). Tests verdes (202 runs, 0 fallos, 1 skip preexistente). Roster import y las vistas propias de estudiante/acudiente/docente siguen pendientes; metering/invoices del plano de control siguen en stub (S3–S4). |
| **Alcance de esta versión** | Cierra el track S2 del plano de control (§12.5.1) en dos slices: **S2a** — tablas globales `subscriptions`/`institution_entitlements` + CRUD de super-admin + el predicado `ControlPlane::Entitlements::Check`, y **S2b** — el wireado de esa primera compuerta en el lado del inquilino (`app/domains/*`, transversal): `Core::Institution#entitled?`, el memo `Current.entitled_addon_keys`, el concern único `Entitlement::Controller`, la nav filtrada, y la página "módulo no habilitado". También reconcilia que S2a se había mergeado sin actualizar este documento — ver Changelog. |

### Convención de versionado de ESTE documento

- **MAJOR** (`vX.0.0`): cambia una decisión de arquitectura asentada (tenancy, modelo de identidad, planos), o se reestructura el mapa de dominios.
- **MINOR** (`v1.X.0`): se cierra una iteración (se implementa un módulo/dominio), se resuelve un borde abierto, o se añade un dominio/plano.
- **PATCH** (`v1.0.X`): correcciones, aclaraciones, ajustes de redacción, reconciliación con el repo.

Cada cambio se registra en el **Changelog** (final del documento). Nunca se borra historia: las decisiones revertidas se marcan como *supersedidas*, no se eliminan.

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
institución puede?*, luego *¿el usuario dentro puede?*.

**Novedad de esta versión:** la primera compuerta que hoy es real de punta a punta no es esta —
es la de identidad: *¿esta persona es quien dice ser?* (login nativo + MFA) y *¿tiene una cuenta
activa en este tenant?* (`institution_users.status`). Antes de esta iteración, toda la app corría
sobre un actor simulado (`sign_in_as_member` / `StubAssignments`); ahora hay un camino real desde
"la institución crea una persona" hasta "esa persona inicia sesión con su propia contraseña".

---

## 2. Stack bloqueado (no sustituir)

| Capa | Elección | Notas |
|---|---|---|
| **Ruby** | 4.0.x con **YJIT** | ZJIT es experimental — **NO usar ni depender de él**. |
| **Rails** | 8.1.x | Autenticación **nativa** de Rails 8 (`has_secure_password`, `Session`, concern `Authentication`, `Current`). **Sin Devise.** **Ya implementada** — ver §9.5. |
| **PostgreSQL** | 18 GA | Nativo: `uuidv7()`, RLS + FORCE, `WITHOUT OVERLAPS`, `UNIQUE NULLS NOT DISTINCT`, JSONB, FTS nativo, pgvector. **Sin extensiones para UUID.** |
| **Async / cache / cable** | Solid Queue / Solid Cache / Solid Cable | **Sin Redis, sin broker, sin Sidekiq, sin Elasticsearch.** Correos ya van por Active Job sobre Solid Queue (`deliver_later` en `OtpMailer`/`InvitationMailer`); importación pesada (roster) todavía no existe. |
| **Front-end** | Propshaft + importmap (sin Node/build), turbo-rails + stimulus-rails, CSS vanilla con `tokens.css` y `@layer` | **Sin Tailwind, sin Sass, sin gema de componentes, sin icon-font.** |
| **Tests** | Minitest (default) | **Sin RSpec.** 122 tests / 0 fallos a la fecha de este documento. |
| **Autorización** | RBAC casero sobre PG | **Sin Pundit / CanCan / rolify.** `IdentityAccess::PermissionCheck` real **todavía no existe** — el gate sigue resolviendo contra `Authorization::StubResolver` salvo que haya `RoleAssignment` reales (ver §9.7 y §11). |
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
- El GUC se fija con `SET LOCAL` dentro de una transacción por request (`TenantScoped#within_tenant`, `around_action`), así que nunca sobrevive al final del request ni se filtra entre checkouts de conexión pool.
- Existe un **seam de resolución de tenant** (`Tenant::Resolver::SubdomainStrategy`, para futuro sharding horizontal). El sharding en sí **NO** se construye (YAGNI a escala solo-dev).

### 3.2 Identidad — global, multi-institución

- `institutions` y `users` son **GLOBALES** (sin RLS). Todo lo demás tenant-owned es **tenant-scoped**.
- **Una persona = un `users`** (login único por `email`, `citext`, único global); puede pertenecer a varias instituciones vía `institution_users`. **Confirmado y en producción de código** — ver §9.5/§11 (⚠-1 cerrado).
- Resolución de tenant **por subdominio** (`institutions.slug`), vía `Tenant::Resolver`.
- `student` y `guardian` son **entidades-persona, NO roles RBAC**. Su acceso se resuelve por **relación** (`students.user_id`, `guardian_students`), no por `role_assignments`. Un menor de K-12 puede existir sin `user_id`; un acudiente siempre tiene login. **Confirmado y en producción de código** — ver §9.6/§11 (⚠-2 cerrado). La tabla `guardian_students` real ya existe (dominio `core`), en paralelo a la legacy `student_support.student_guardians` (ambas coexisten a propósito; no se migró la legacy).

### 3.3 Roles de Postgres y realidad operativa de BD

> Esta sección nace de un incidente real: una migración corrida como `rails db:migrate` conectó
> con el rol runtime (sin `CREATE`) y falló. Es el error más fácil de repetir.

- **`edu_app_runtime`** — sirve la app. `NOSUPERUSER`, **sin `CREATE`** en `public`, **sin `BYPASSRLS`**.
- **`edu_migrator`** — corre migraciones. Tiene `CREATE`. Debe tenerlo en **todas** las bases (primaria **y** las tres Solid: cache/queue/cable) — el bootstrap inicial solo lo aplicó a las primarias, y eso muerde.
- **`edu_bi_reader`** (rol auditado) — **único** rol con `BYPASSRLS`; solo para lecturas cross-tenant de super-admin / BI (nombre real en `lib/tasks/roles.rake`; este documento antes lo llamaba `edu_analytics`). **El runtime nunca hace lecturas cross-tenant.**
- **Migraciones corren con `bin/migrate`** (que exige `EDU_MIGRATOR_PASSWORD` no vacío), **NO** con `rails db:migrate`.
- `schema_format = :sql`. Las bases Solid se pueblan por *schema load* desde `db/*_structure.sql` (no tienen carpeta de migraciones).
- **Gotcha nuevo de esta iteración — `EDU_MIGRATOR_PASSWORD` no vive en el repo ni en el entorno por defecto.** Si se pierde/no está exportado: es un dev local con auth `trust` para el superusuario del SO (`psql -U "$(whoami)" -d postgres`), así que se puede resetear con `ALTER ROLE edu_migrator PASSWORD '...'` y exportar ese valor solo para el comando de migración. **Nunca dejar esa contraseña en archivos del repo ni en el scratchpad tras usarla.**
- **Gotcha nuevo de esta iteración — migrar development NO migra test.** `bin/migrate` apunta a la base de `RAILS_ENV` activo (default `development`). Antes de correr el test suite después de una migración nueva hay que correr también `RAILS_ENV=test bin/migrate` (o el mecanismo de `maintain_test_schema` que corresponda) — si no, los tests fallan con `NoMethodError` sobre la columna nueva (no con un error de SQL, porque Rails ni siquiera generó el método de atributo).

### 3.4 Estructura de código — bounded contexts sin Packwerk

`app/domains/<dominio>/` es autoload root. Zeitwerk **colapsa** `app/domains/*/{models,queries,services,jobs,policies}` (ver `config/application.rb`), así que la capa intermedia NO aparece en el nombre de la constante:
- `app/domains/core/models/user.rb` → `Core::User` (no `Core::Models::User`).
- `app/domains/identity_access/services/otp/issuer.rb` → `IdentityAccess::Otp::Issuer`.
- `app/domains/core/services/people/resolver.rb` → `Core::People::Resolver`.

Librería de componentes compartidos en `app/views/shared/`; se **reutiliza antes de crear local** y se **promueve a `shared/` cuando un componente se usa en ≥2 dominios** (patrón ya aplicado con `_timeline`, `_audit_entry_row`).
El **plano de control vive FUERA de `app/domains/*`** — namespace propio `app/control_plane/`, montado en `/control_plane`, con su propio layout y guard de auth (todavía stub — ver §7 y §12).

---

## 4. Mapa de dominios

> Un **addon = un dominio (1:1)**. La institución habilita dominios comprando addons.

### Tier A — dominios base (existentes)

| Dominio | Propósito | Posee / notas |
|---|---|---|
| `core` | Espina académica **+ identidad de personas** | `students`, matrícula (`enrollments`), acudientes (`guardian_students`, nuevo), cursos, `academic_terms` (nuevo, con índice de "un solo término activo"), `grade_levels`, `disciplinary_logs`. También posee ahora `Core::User`, `Core::InstitutionUser`, `Core::Session`, `Core::People::Resolver` — la identidad vive aquí, no en `identity_access`. Casi todo le hace FK. |
| `teacher_management` | Docentes | Perfiles, `departments` (áreas), cualificaciones. |
| `group_management` | Grupos | `groups` (`kind` homeroom/…), membresía/rosters. `students.user_id` y `students.national_id` (cifrado) viven en el modelo de este dominio (`GroupManagement::Student`), aunque la migración que los agregó corrió junto con el módulo de auth. |
| `schedules` | Horarios/timetabling | Rooms, patrones de reunión. Usa PG18 `WITHOUT OVERLAPS` (doble-booking de aula/profesor). Depende de `academic_terms`. |
| `student_support` | Bienestar | Convivencia, **historia médica (dueño)**, acomodaciones. Sensible. Sigue teniendo su propia tabla legacy `student_guardians`, que coexiste con la nueva `core.guardian_students` (no se migró; ver §3.2). |
| `cafeteria` | Alimentación | Checkout con **bloqueo por alérgeno** (lee `student_support` — por eso `student_support` va antes). Wallet/saldo, transacciones idempotentes. |
| `transportation` | Rutas | Rutas, paradas, check-in/out de abordaje. Notifica a acudientes (Turbo Streams/Solid Cable — diferido). |
| `analytics_bi` | Reporting | Vistas materializadas, read models. Lectura cross-tenant **solo** por rol auditado con `BYPASSRLS` (`edu_bi_reader`); nunca runtime. Sigue en fase stub. |

### Tier B — identidad/roles

| Dominio | Propósito |
|---|---|
| `identity_access` | IAM/RBAC **+ onboarding**. Posee el catálogo global `roles`/`permissions`/`role_permissions`, `role_assignments` (tenant, scope por columnas explícitas), y ahora también `invitations`, `email_otps`, `audit_events`, los servicios `Otp::*` e `Invitations::*`, `Audit`, y el controller/vistas de `people` (gestión de personas). **No posee** `users`/`institution_users` — esos son de `core` (ver arriba); referencia por FK. También referencia por FK a `core.grade_levels`, `teacher_management.departments`, `group_management.groups`. |

### Tier B-bis — confirmados

| Dominio | Propósito |
|---|---|
| `counseling` | Psicoorientación. **Carve-out de `student_support`.** Casos/expedientes, sesiones/notas, remisiones, planes de intervención. Puede *leer* (no poseer) la historia médica de `student_support`. **Frontera de confidencialidad más estricta** que convivencia. |
| `finance` | Tesorería/cartera **dentro** del tenant (el colegio cobra pensiones a acudientes). Cargos, pagos, estados de cuenta, planes de pago. **≠ billing de plataforma.** Tenant-scoped. |
| `communication` | Hub de comunicación (absorbe y amplía el antiguo `notifications`). Dos facetas: comunicación humana (buzón, mensajería con padres, canales Slack-like) y notificaciones del sistema (avisos de otros dominios). Detalle en §8. Sigue en fase stub — no wireado a `invitations`/`email_otps` (esos van por `ApplicationMailer`, no por `communication`). |

### Tier C — candidatos (crear SOLO bajo confirmación explícita)

`staff_management` **o** `human_resources` (personal no docente; decisión de generalizar `teacher_management` vs. dominio nuevo — **CHECKPOINT E pendiente**; nota: ya existe un `staff_management` mínimo que solo cierra un nav huérfano, no resuelve el checkpoint) · `admissions` (pipeline aspirante→matriculado) · `library`.

### Orden de dependencias (creación / migraciones)

1. `core`, `teacher_management`, `group_management` (proveen destinos de scope).
2. `identity_access` (referencia los anteriores por FK).
3. `schedules`, `student_support`, `cafeteria`, `transportation`, `analytics_bi`.
4. `counseling` y `finance` (FK a `core`; `counseling` puede leer `student_support`).
5. `communication` (FK a `core` e `identity_access`; consume notificaciones del resto).
6. Tier C, según se confirmen.

> **Nota de esta iteración:** el módulo de onboarding se repartió entre `core` (identidad + roster
> import, cuando exista) e `identity_access` (invitaciones + MFA + auditoría) tal como este mapa ya
> anticipaba — no hubo que reabrir el mapa de dominios.

---

## 5. RBAC — rol + scope

El rol dice **qué**; la asignación dice **sobre qué**. Toda autorización responde a:
*"¿tiene un rol que incluya este permiso **con un alcance que cubra este recurso**?"*.

### Catálogo — GLOBAL, sin RLS

- **`roles`**: `key` (slug greppable: `teacher`, `area_lead`, `academic_coordinator`, `coexistence_coordinator`, `counselor`, `dean`, `principal`, `institution_admin`, …), `name`, `assignable_scope_types text[]` (p. ej. `area_lead → {department}`, `teacher → {group,institution}`), `is_system`.
- **`permissions`**: `key` (`teacher.view`, `teacher.evaluate`, `student.view`, `disciplinary_log.create`, …), `resource`, `action`. **Nuevo en esta iteración:** `people.manage` (crear personas, invitar, suspender/reactivar cuentas) — deliberadamente **distinto** de `roles.manage` (RBAC), porque un registrador puede necesitar onboardear personas sin poder otorgar `institution_admin`. Catálogo completo en `IdentityAccess::SeedPermissions::CATALOG`.
- **`role_permissions`**: PK compuesta `(role_id, permission_id)`, `ON DELETE CASCADE`.

### Asignaciones — TENANT-SCOPED, con RLS

- **`role_assignments`**: el corazón del scope. Columnas de alcance **explícitas** (no polimórfico): `scope_department_id` / `scope_grade_level_id` / `scope_group_id` (las no usadas en NULL), `valid_from` / `valid_until` (fechado efectivo). **DECIDIDO** — no re-preguntar.
  - Ejemplo: un jefe de área es una fila con `role = area_lead` + `scope_department_id` apuntando a su departamento; el resto de columnas de scope en NULL. La misma persona puede tener otra fila con alcance institución si además es admin.

### Roles de plataforma (globales, cross-tenant)

- **super-admin** auditado y **`bi_auditor`** (solo lectura BI) — sobre el rol Postgres `BYPASSRLS`, nunca runtime.

### Catálogo de roles de staff (sobre `institution_users`)

Académicos/docentes (`teacher`, `area_lead`), coordinación (`academic_coordinator`, `coexistence_coordinator`), dirección (`principal`, `dean`), registro (`academic_secretary`, `registrar`), bienestar (`counselor`, `psychologist`, `social_worker`), clínico (`medical_staff` — dueño de historia médica), servicios (`cafeteria_staff`, `transport_coordinator`, `driver`, `route_monitor`), administración (`institution_admin`), BI (`bi_auditor`). Casi todos requieren **scope**, no rol suelto.

> `student` y `guardian` **no** están en este catálogo: son entidades-persona, acceden por portal.
> `institution_users.role` (columna string libre, default `"member"`) **no es** este catálogo RBAC —
> es un campo heredado, sin lectores en el código todavía; no confundirlo con `role_assignments`.

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
CLIC 0  Dashboard (landing por rol)   → tiles SOLO de dominios que el rol permite
CLIC 1  Índice de dominio             → ya pre-filtrado por scope
CLIC 2  Registro (show)               → una entidad
CLIC 3  Detalle / acción              → pestaña del show o formulario
```

Piezas transversales (Fase 0, ya construidas): barra de navegación por rol (si no hay
permiso del dominio, **desaparece** — no "deshabilitado"), selector de institución (fija
`app.current_institution_id`), selector de "actuando como" (opcional), dashboard por rol (2–5 atajos),
buscador global acotado por scope (válvula de escape a los 3 clics), portales de persona
(student/guardian como superficies separadas, hoy sobre datos reales de relación pero sin
`Core::Access::GuardianScope` — ver §9.7), y vista **403 amable**.

**Nuevo en esta iteración — capa PRE-login:** todo lo anterior asume un actor ya autenticado. Antes
de eso existe ahora un layout separado (`layouts/auth`, sin nav de dominio ni selector de
institución) para `sessions/`, `email_otps/`, `invitations/` — deliberadamente minimalista, porque
en ese punto `Current.user` todavía no existe.

### 6.3 Puerta de autorización

> **Nuevo en v1.3.0 — las dos compuertas en serie ya existen, pero con madurez distinta.** La
> **compuerta #1** (`¿la institución puede usar este dominio?`) es real de punta a punta desde S2b:
> `Entitlement::Controller` (concern único, incluido en `ApplicationController`) corre un
> `before_action` que consulta `Current.entitled_addon_keys` (memo por request sobre
> `Core::Institution#entitled?` → `ControlPlane::Entitlements::Check`, S2a) y corta con la página
> "módulo no habilitado" **antes** de que la acción llegue a `authorize!`. La **compuerta #2** (RBAC,
> descrita abajo) sigue sin cambios — sobre `StubResolver` salvo `RoleAssignment` reales. Ver §7.1 y
> §12.5.1 para el detalle del wireado.

- **`IdentityAccess::PermissionCheck`** (query object): resuelve *"¿puede U ejecutar A sobre R?"* con scope. Se carga **una vez por request** y se resuelve en memoria. **Todavía no existe** — ver §11.
- **`can?(permission, resource = nil)`** (helper de vista): mostrar/ocultar acciones — **solo cosmética**.
- **`authorize!(permission, resource)`** (concern de controlador): **puerta dura al inicio de cada acción** — la que protege de verdad. Implementado en `Authorization::Controller`; hoy resuelve contra `Authorization::StubResolver` a menos que existan `RoleAssignment` reales para el actor.
- Los índices filtran por **Query object de scope**, nunca `default_scope`.
- **Gotcha de esta iteración:** cuando `Current.institution_user` es `nil` (actor sin membresía activa — p. ej. recién suspendido), `Authorization::AssignmentSource.for` **cae al persona stub** `StubAssignments.all` en lugar de devolver cero permisos. Esto es intencional en esta fase views-only (mantiene vivos los tests de vistas viejos), pero significa que la suspensión de una membresía **no es una garantía de "cero permisos" mientras `IdentityAccess::PermissionCheck` no reemplace el stub** — solo es garantía de "no puede iniciar sesión nueva" y "pierde la membresía en la siguiente request". Documentar esto era pendiente; queda cerrado aquí.

### 6.4 Matriz rol × dominio (resumen)

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

### 6.5 Caso de aceptación de referencia (valida rol+scope end-to-end)

`teacher_management` corre primero. María = `(teacher, group:10-A)`, `(teacher, group:11-B)`,
`(area_lead, department:Matemáticas)`. `authorize! teacher.evaluate` = **sí** sobre un docente de
Matemáticas, **no** sobre uno de Sociales; y no ve al resto de la institución. Si pasa, la puerta
rol+scope quedó bien y el resto es repetir el molde.

### 6.6 Patrones canónicos (la "convención de la casa")

Cinco esqueletos que hacen converger a todos los dominios: (1) Query object de índice con scope,
(2) controlador con `authorize!` al inicio, (3) gating con `can?` en vista, (4) pestañas gateadas por
permiso, (5) auto-registro de navegación en archivo propio del dominio (no editar un partial central).

---

## 7. Plano de control · addons, entitlements y billing de plataforma

> **No es un dominio.** Vive en `app/control_plane/` (fuera de `app/domains/*`), cross-tenant, por
> encima de RLS. **Billing de plataforma ≠ dominio `finance`**: aquí la plataforma cobra al colegio;
> en `finance` el colegio cobra a los acudientes. **Corrección de esta versión:** el auth de
> `platform_admins` (S0), el catálogo `addons`/`plans` (S1) y ahora `subscriptions`/
> `institution_entitlements` con CRUD real (S2a, esta versión) — la nota anterior ("sigue en fase de
> componentes/vistas stub") quedó desactualizada frente al repo para todo el track S0–S2. Metering e
> `invoices` (S3–S4) siguen en fase stub (ver §12.5). Servido por el rol runtime normal
> (`edu_app_runtime`), **sin `BYPASSRLS`** — estas tablas son globales y no necesitan cruzar tenants
> para leerse.

### 7.1 El gate de entitlements (dos compuertas en serie)

1. **Entitlement** (control plane): *¿la institución PUEDE usar este dominio?* → contrato/plan.
2. **RBAC con scope** (`identity_access`): *¿el usuario DENTRO puede?* → rol + alcance.

**Real de punta a punta desde S2b (esta versión) — con datos reales, no solo diseño.** El punto único
de verificación es `Core::Institution#entitled?(addon_key)` (delega en
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
drift; así el runtime del inquilino nunca se acopla a una constante del plano de control. El código
de cada dominio no se ramifica — se enciende/apaga por institución desde un solo lugar, y ningún
archivo de `cafeteria`/`transportation`/`schedules`/`student_support`/`counseling`/`finance`/
`communication`/`analytics_bi` fue tocado para lograrlo. **Gate #2 (RBAC) sigue sobre
`Authorization::StubResolver`** — P1 no se tocó.

### 7.2 Modelo de datos conceptual (global, sin RLS)

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
  (`ControlPlane::Addon#retire!`, F10-bis, cerrado en S2a). **S2b (esta versión)** conectó este
  predicado al lado del inquilino — ver §7.1.
- **`student_headcount_snapshots`** 🔴 pendiente (S3) — headcount **empujado por el tenant al cierre** (no lectura viva del `students` del inquilino → boundary limpio + número defendible en factura).
- **`usage_events` / `usage_daily_rollups`** 🔴 pendiente (S3) — metering. Un job diario acumula rollups; el corte de periodo suma rollups, no escanea eventos crudos.
- **`invoices` / `invoice_line_items`** 🔴 pendiente (S4) — cada línea con `kind` ∈ (`base_seats`, `addon_fee`, `usage_overage`) + FK a su origen.
- **`platform_admins`** ✅ **migrado, con auth nativa + MFA por correo (S0, ya real desde antes de este documento)** — super-admins de plataforma aparte de `Core::User`, no un flag. El MFA propio (`ControlPlane::Otp::*`) se construyó independiente de `IdentityAccess::Otp::*` en vez de reutilizarlo — no hubo que adaptar la firma genérica, se duplicó el ~concern~ delgado.

### 7.3 Modelo de cobro: híbrido

Tres piezas ortogonales: **base por alumnos** + **fee por addon** + **overage por uso**. El **corte
de periodo** es un job periódico en Solid Queue que produce una **factura borrador** para revisión
(nunca auto-emitir).

---

## 8. Dominio `communication` (detalle)

Dos facetas que no se aplanan: **comunicación humana** (persona↔persona) y **notificaciones del
sistema** (sistema→persona). Borrador de tablas (tenant-scoped, RLS):

- `conversations` — hilo unificado con `kind` ∈ (`direct`, `channel`, `parent_thread`, `announcement`) y `category` ∈ (`parent_communication`, `internal`, `announcement`); para canales: `visibility`, `name`, `topic`.
- `conversation_participants` — participante = `institution_user` **o** `guardian` (dos FK nulos + CHECK exactamente-uno, mismo patrón que el scope de roles); rol en la conversación, `last_read_at`.
- `messages` — emisor (staff o guardian), cuerpo, `parent_message_id` nullable (hilos).
- `tags` / `taggings` — catálogo de etiquetas por institución + puente.
- `mentions` — @menciones.
- Faceta notificaciones: `notifications`, `notification_preferences`, plantillas.

**Colisión de "canal":** hay *canales de discusión* (Slack-like) y *canales de entrega* de
notificaciones (in-app/email/push) — nombrados distinto (`_channel_*` vs `_delivery_channel_badge`).
**Tiempo real (Turbo Streams/Solid Cable) diferido** — en fase actual solo UI con stub.

**Sin cambios en esta iteración.** Aclaración importante: los correos de OTP e invitación NO pasan
por este dominio — van directo por `ApplicationMailer`/Active Job. Si `communication` en el futuro
quiere centralizar TODO envío saliente (incluido auth), es una decisión de arquitectura nueva, no
asumida hoy.

---

## 9. Módulo de autenticación / onboarding

> Principio rector: **una cuenta debe corresponder de forma verificable a un ser humano real**
> (mitigación de ciberacoso, cuentas de desecho, datos de menores). **Esta sección se reescribe
> por completo en v1.1.0**: describe lo que YA está construido y probado, no solo la intención.

### 9.1 Decisiones del modelo conceptual (sin cambios, ya implementadas)

- **Nadie se autorregistra.** La institución crea los registros (`Core::People::Resolver`, hoy solo
  desde la UI de "crear individual" — el batch CSV/roster **no existe todavía**, ver §9.8). La
  persona solo **completa** su cuenta vía **invitación** al correo registrado
  (`IdentityAccess::Invitations::Completer`).
- **El documento es un identificador conocible, no un secreto.** `national_id` vive cifrado
  (`encrypts ..., deterministic: true`) tanto en `Core::User` (global) como en
  `GroupManagement::Student` (tenant-scoped) — ver ⚠-2 cerrado en §11. Resuelve *alcance*, nunca
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

### 9.7 Pendiente real (no implementado, no solo "vista futura")

Esto es el corte exacto de lo que falta para que este módulo esté completo según el prompt
original — ver también §12.1:

1. **`Core::RosterImport::Parser` / `Validator` / `Committer`.** Las tablas
   (`roster_import_batches`, `roster_import_rows`) y los modelos base existen; **no existe ningún
   servicio** que lea un CSV. Sin esto no hay importación batch — "crear individual" vía
   `PeopleController` es hoy el único camino de alta.
2. **`Core::Access::GuardianScope`.** No existe. Los portales de estudiante/acudiente (vistas ya
   construidas en una fase anterior) no tienen todavía un query object real que resuelva "mis
   estudiantes del término activo" contra `guardian_students` — hay que verificar si siguen sobre
   datos stub o fixtures ad-hoc.
3. **Vistas de "mis datos" con datos reales** para estudiante/acudiente/docente-coordinador-director
   (el prompt original las pedía sobre el término activo). Lo construido hasta ahora es superficie
   de **administración** (`identity_access/people`) y **auth compartida** (`sessions`,
   `email_otps`, `invitations`) — no las vistas de autoservicio de la persona ya autenticada.
4. **Visor de `audit_events`** (bandeja filtrable por actor/acción/fecha) e **bandeja de
   discrepancias reportadas**. Los datos ya se escriben (`Audit.log`, `DiscrepancyReporter`); no
   existe ninguna vista que los liste. Es la pieza más barata de construir de las que faltan — el
   partial `shared/_audit_entry_row` ya existe de una fase anterior.
5. **`IdentityAccess::Resender/Expirer/BounceHandler` como servicios separados** — decisión
   consciente de NO construir `Resender`: `Issuer` ya invalida-y-recrea, así que "reenviar" en la UI
   llama `Issuer` de nuevo. `Expirer` y `BounceHandler` sí se construyeron (ver tabla en §9.3), pero
   ninguno está conectado a un disparador real (cron/job para el primero, webhook de proveedor de
   correo para el segundo).
6. **`IdentityAccess::PermissionCheck` real** — sigue sin existir (esto es un pendiente compartido
   con TODO el resto de la app, no exclusivo de este módulo; ver §11).
7. **Job de Solid Queue que reestablece el GUC de tenant.** El prompt original lo exige para
   cualquier job async que toque datos tenant-scoped. Hoy no hay ningún job async que lo necesite
   (los mailers son `deliver_later` pero no ejecutan queries tenant-scoped dentro del job — leen
   primitivos ya resueltos por el llamador). Si `Expirer` se vuelve un job recurrente, **ahí sí**
   habrá que resolver esto.

### 9.8 Consideraciones legales (Colombia) — sin cambios, siguen vigentes

Datos de menores y Habeas Data (Ley 1581 + decreto de datos de NNA): documento y datos de menores
como sensibles desde el diseño; minimizar dónde vive el documento en claro (ya mitigado con cifrado
determinístico); registrar el tratamiento. El eslabón crítico se movió a la **captura del correo en
matrícula** → su validación es deber institucional explícito (todavía no hay UI de matrícula que lo
capture — hoy "crear individual" en `identity_access/people` asume el correo ya es correcto).
Rate limiting/bloqueo en login, OTP y completado — **implementado** (`rate_limit to: 10, within:
3.minutes` en los tres controllers de auth). Nunca exponer directorios de estudiantes ni
autocompletar por documento/nombre — `Core::Access::GuardianScope` (pendiente) debe nacer sin
buscador, tal como pide el prompt original.

---

## 10. Cambios ya implementados (asumiendo ejecución de todos los chats)

> Estado acumulado si cada prompt generado fue ejecutado en Claude Code. Marcado por iteración.

| # | Iteración | Entregable | Estado asumido |
|---|---|---|---|
| 1 | **Fundación de arquitectura** | Stack bloqueado, tenancy row-level + RLS, identidad global, UUIDv7 nativo, roles PG, `app/domains/*` scaffold, config generators UUID, YJIT | ✅ Ejecutado |
| 2 | **Diagnóstico de permisos BD** | `bin/migrate` con `edu_migrator`, `CREATE` en las 3 bases Solid, `schema_format = :sql` entendido | ✅ Corregido |
| 3 | **Roles y dominios** | Catálogo `roles`/`permissions`/`role_permissions`, `role_assignments` con scope explícito, ERD de `identity_access` | ✅ Ejecutado (track esquema) |
| 4 | **Organización de dominios** | `dominios_edu_platform.md`, prompt de scaffold, `notifications` → `communication` | ✅ Ejecutado (scaffold + componentes) |
| 5 | **identity/finance/counseling** | Prompt combinado con modelos (migraciones + AR con guardrails) | ✅ Ejecutado (esquema + componentes) |
| 6 | **Vistas + roles** | Mapa maestro, Fase 0 (shell por rol + `can?`/`authorize!` + dashboard + portales + 403), prompts por dominio | ✅ Fase 0 + dominios ejecutados (todavía sobre `StubResolver`, ver §11) |
| 7 | **Plano de control + billing** | Estructura `app/control_plane/`, auth de `platform_admins` + MFA (S0), catálogo `addons`/`plans`/`plan_price_tiers` con CRUD real (S1), `subscriptions`/`institution_entitlements` con CRUD real (S2a), gate de entitlement wireado en el inquilino (S2b) | 🟡 **Parcialmente ejecutado.** Real: S0, S1, S2 completo (S2a+S2b). Pendiente: metering (S3), `invoices` (S4) — siguen en componentes/vistas stub. |
| 8 | **Autenticación / onboarding** | Registro por invitación, login+MFA, roster import, vinculación, auditoría (externos e internos) | 🟡 **Parcialmente ejecutado.** Real: esquema, login+MFA, invitaciones, auditoría, gestión de personas, suspender/reactivar. Pendiente: roster import (CSV), `GuardianScope`, vistas de autoservicio de la persona, visores de auditoría/discrepancias. Ver §9.7 para el corte exacto. |
| 9 | **Plano de control · S1 (catálogo)** | Migraciones `addons`/`plans`/`plan_price_tiers`, modelos con validaciones-espejo de los CHECK, CRUD auditado, seed idempotente, tests | ✅ Ejecutado — ver §7.2 y Changelog v1.2.0 |
| 10 | **Plano de control · S2a (subscriptions + entitlements)** | Migraciones `subscriptions`/`institution_entitlements` (globales, sin RLS), modelos con snapshot inmutable y validaciones-espejo, CRUD auditado, predicado `ControlPlane::Entitlements::Check`, bloqueo de `retire!` con entitlements activos (F10-bis), tests | ✅ Ejecutado — ver §7.2 y Changelog v1.3.0 |
| 11 | **Plano de control · S2b (gate en el inquilino)** | `Core::Institution#entitled?`, `Current.entitled_addon_keys`, concern único `Entitlement::Controller` (antes de `authorize!`), nav filtrada, página "módulo no habilitado", `Entitlement::Registry` + test de consistencia vs. `DOMAIN_KEYS` | ✅ Ejecutado — primer slice que toca `app/domains/*` de forma transversal (una sola pieza + nav central). Ver §7.1 y Changelog v1.3.0 |

---

## 11. Decisiones abiertas / bordes a resolver

| # | Borde | Contexto | Estado |
|---|---|---|---|
| ⚠-1 | **Identidad global vs. un-correo-un-tenant** | El módulo de auth asume ceder a la identidad global ya construida. | ✅ **CERRADO.** Confirmado y validado en código — ver §9.5. No re-abrir sin una razón de negocio explícita (implicaría reescribir `Core::User`/`Core::InstitutionUser`, fundacional). |
| ⚠-2 | **Dónde vive el campo de documento** | El esquema usa `student_code` como ID legible; no había campo de documento nacional. | ✅ **CERRADO.** `national_id` cifrado en `Core::User` (global) y `GroupManagement::Student` (tenant-scoped) — ver §9.6. |
| E | **CHECKPOINT E: `teacher_management` → `staff_management`** | Personal no docente (cocina, transporte, etc.) sin dominio claro. D1 (generalizar) vs D2 (dominio HR nuevo). Ya existe un `staff_management` mínimo (solo cierra un nav huérfano de Fase 0) que **no** resuelve este checkpoint. | 🔴 Abierto. Recomendado D1. Cerrar antes de crear Tier C de personal. |
| B1 | **Estudiantes sin login** | `students.user_id` nullable — un menor puede existir sin cuenta. | ✅ Confirmado como diseño, y ahora reforzado por la migración `add_user_id_to_students` (FK `on_delete: :nullify`). Falta documentar consistencia en portales cuando exista `GuardianScope`. |
| B2 | **Fechado efectivo de asignaciones vs. `academic_terms`** | ¿`role_assignments.valid_from/until` se acopla a ciclos lectivos o es independiente? | 🔴 Abierto. `academic_terms` ya existe con estado `active` único por institución — se puede resolver ahora que la tabla existe. |
| M1 | **Unidad de metering por dominio medido** | El control plane solo consume rollups. | 🔴 Abierto. Se fija cuando cada dominio medido defina su evento facturable. |
| **P1 (nuevo)** | **`Authorization::PermissionCheck` real** | Todo el gate de autorización (todos los dominios, no solo onboarding) sigue resolviendo contra `StubResolver`/`StubAssignments` cuando no hay `RoleAssignment` reales. Con login real ya wireado, este es ahora el cuello de botella más visible: cualquier persona autenticada sin `RoleAssignment` sembrado recibe la **persona stub genérica** (`group_director`/`area_head`), no cero permisos. | 🔴 Abierto — ver §6.3 y §12.3. Antes de dar de alta usuarios reales en un ambiente que no sea de pruebas, esto **debe** cerrarse o al menos sembrarse `RoleAssignment` reales para cada persona creada vía `PeopleController`. |
| **P2 (nuevo)** | **Rol libre `institution_users.role`** | Columna string sin lectores en el código (ver §5). Puede generar confusión con el RBAC real. | 🔴 Abierto. Decidir si se elimina, se documenta como legacy, o se conecta a algo. |

---

## 12. Próximas iteraciones (backlog ordenado)

> Orden sugerido por dependencia y riesgo. Cada iteración cierra con actualización de este documento (bump de versión).

1. ~~Confirmar ⚠-1 y ⚠-2 y ejecutar el módulo de autenticación/onboarding~~ → **hecho parcialmente,
   v1.1.0 (este documento).** Lo que queda de esta misma iteración, en orden recomendado:
   1. **`Core::RosterImport::Parser/Validator/Committer`** (depende de `Core::People::Resolver`,
      ya existe) — desbloquea altas batch, no solo individuales.
   2. **`Core::Access::GuardianScope`** + verificar/conectar los portales de estudiante/acudiente
      ya existentes.
   3. Vistas de autoservicio reales (estudiante/acudiente/docente-coordinador-director) sobre el
      término activo.
   4. Visor de `audit_events` + bandeja de discrepancias (barato — los datos ya existen).
   5. Job recurrente para `Invitations::Expirer` y webhook real para `Invitations::BounceHandler`
      (opcional / según necesidad real de producción, no bloqueante).
2. **Cerrar CHECKPOINT E** (`staff_management` vs `human_resources`) y, si aplica, scaffold del dominio de personal no docente. *(nota: v1.2.0 terminó siendo el Slice S1 del plano de control, no este ítem — sigue pendiente y sin versión asignada).*
3. **Cablear la puerta de auth real (gate #2, RBAC)**: reemplazar `Authorization::StubResolver` por
   `IdentityAccess::PermissionCheck` en todas las vistas de dominio. **Elevada en prioridad** esta
   versión — con login real y con el **gate #1 (entitlement) ya real** desde S2b, el stub-fallback de
   §6.3/P1 es ahora la **única** compuerta que sigue sin dientes: cualquier persona autenticada sin
   `RoleAssignment` sembrado recibe la persona stub genérica, no cero permisos. Al cerrar esto,
   **verificar que el orden entitlement→`authorize!` sigue intacto** (forward-note de S2b).
4. **Vistas de negocio por dominio** que aún estén en stub → conectarlas a modelos reales, dominio por dominio (empezando por `core` y `teacher_management` con el caso de aceptación).
5. **Migraciones del plano de control** — ✅ auth de `platform_admins` con MFA (S0), catálogo
   `addons`/`plans`/`plan_price_tiers` con CRUD (S1), y **S2 completo (S2a+S2b, v1.3.0)**:
   `subscriptions`/`institution_entitlements` con CRUD real + snapshot inmutable + predicado
   `ControlPlane::Entitlements::Check`, y el gate wireado en el inquilino (`Entitlement::Controller` +
   nav filtrada). Pendiente:
   1. **S3 — metering**: `student_headcount_snapshots`, `usage_events`/`usage_daily_rollups`, jobs.
      `addons.unit` sigue **provisional** hasta cerrar **M1** (unidad de metering por dominio) — S1
      solo declaró valores de ejemplo (`check-ins`, `mensajes`) para satisfacer el CHECK, no la
      unidad definitiva.
   2. **S4 — `invoices`/`invoice_line_items`**: corte de periodo, aplicar los tiers de
      `plan_price_tiers` y los overrides de `institution_entitlements` (S2a los almacena, no los
      aplica) a un headcount real.
   3. **Hardening documentado, no construido en S1/S2a**: exclusion constraint `int4range`/`daterange`
      con GiST por `plan_id` (tiers) o por `(institution_id, addon_id)` (entitlements) para prohibir
      solapamiento a nivel de BD (hoy solo se valida en la app), al estilo `WITHOUT OVERLAPS` de
      `schedules`.
   4. **RBAC intra-plano** (roles/scopes de `platform_admin`) — sigue sin construirse; cualquier
      `platform_admin` autenticado administra el catálogo/subscriptions/entitlements completos.
   5. **Provisioning de instituciones** (crear/editar una institución desde el control plane) — S2a
      solo las lista read-only.
6. **Metering real** por dominio medido: definir el evento facturable de cada uno, `usage_events` → `usage_daily_rollups` (job idempotente en Solid Queue), y el job de corte de periodo (factura borrador).
7. **Tiempo real** (Turbo Streams sobre Solid Cable, sin Redis): `transportation` (abordaje) y `communication` (canales). Hoy diferido.
8. **`communication` a fondo**: migraciones de `conversations`/`messages`/`tags`, mensajería con padres, canales.
9. **`analytics_bi`**: vistas materializadas + reporte cross-tenant auditado (rol `BYPASSRLS`, `edu_bi_reader`).
10. **Endurecer auditoría** (append-only — ya implementado a nivel de BD) y terminar la bandeja de discrepancias del roster (ver ítem 1.4 arriba).

---

## 13. Guardrails operativos (recordatorio permanente)

- Migraciones: **`bin/migrate`**, nunca `rails db:migrate`. `edu_migrator` con `CREATE` en las 4 bases.
- **Migrar development NO migra test** — correr también `RAILS_ENV=test bin/migrate` tras cada migración nueva, o el test suite falla con `NoMethodError` (no con un error de SQL) sobre la columna/tabla nueva.
- `EDU_MIGRATOR_PASSWORD` es solo de entorno, nunca vive en el repo. Si se pierde en dev local, resetear con `psql` (auth `trust` del superusuario del SO) vía `ALTER ROLE edu_migrator PASSWORD '...'` — nunca dejar la contraseña en archivos temporales tras usarla.
- **Sin `default_scope`** para tenancy ni scope de rol — siempre Query objects.
- **RLS con `FORCE`**; runtime sin `BYPASSRLS`; cross-tenant solo por el rol auditado (`edu_bi_reader`).
- **`authorize!` en el controlador** (puerta dura); `can?` en la vista solo cosmético.
- **Cuidado con el fallback a `StubAssignments`** (ver §6.3/P1): un actor autenticado sin `RoleAssignment` real recibe la persona stub genérica, no cero permisos. No asumir que "sin rol asignado = sin acceso" hasta que `PermissionCheck` reemplace el stub.
- **`has_secure_password` con `validations: false` en `Core::User`** — un `password_digest` nulo es un estado válido (persona invitada, no completada). No "arreglar" agregando de vuelta la validación de presencia por defecto sin releer §9.4.
- **Suspender (`institution_users.status`) bloquea login y quita grants en la siguiente request**, pero NO destruye sesiones ya abiertas de otras instituciones del mismo usuario, y su efecto sobre permisos depende del fallback a stub (ver P1) hasta que `PermissionCheck` exista.
- **Sin gemas nuevas** salvo bottleneck documentado e irresoluble con lo nativo. `bcrypt` no cuenta como nueva — es la gema que el propio scaffold de Rails deja comentada para `has_secure_password`.
- Propshaft sin `@import`/Sass; importmap sin build; **tokens-only** (no tocar `tokens.css` salvo token faltante justificado); accesibilidad AA.
- Cross-domain siempre por **FK + stub** hasta que exista el modelo real; no inventar tablas de otros dominios.
- El **plano de control fuera de `app/domains/*`** — no scopearlo por `institution_id` por costumbre.
- **Zeitwerk colapsa `app/domains/*/{models,queries,services,jobs,policies}`** — un archivo en `app/domains/<d>/services/<ns>/foo.rb` define `<D>::<Ns>::Foo`, NO `<D>::Services::<Ns>::Foo`. Verificar con `bin/rails zeitwerk:check` antes de dar por buena una constante nueva.
- **Gate #1 (entitlement) siempre antes de gate #2 (RBAC)** — `Entitlement::Controller` (una sola pieza, incluida una vez en `ApplicationController`) corre antes de que la acción llegue a `authorize!`; un módulo no habilitado nunca revela detalles de RBAC. Ver §7.1.
- **Los dominios fundacionales nunca se gatean por entitlement** — su ausencia de `Entitlement::Registry` (`config/entitlements/*.rb`) ES la señal de "no gateado"; no existe (ni debe crearse) una lista aparte de "fundacionales".
- **`Entitlement::Registry` no referencia `ControlPlane::AddonCatalog::DOMAIN_KEYS` en runtime** — solo `test/models/entitlement/registry_consistency_test.rb` cruza ambas listas. No "simplificar" el runtime del inquilino para que lea la constante del control plane directamente; ese acoplamiento es exactamente lo que este seam evita.
- **`sign_in_as_member` (test helper) otorga entitlement de todos los dominios gateados por defecto** desde S2b — la institución efímera de test se comporta como un tenant completamente aprovisionado. Un test que necesite el escenario "no entitled" debe **revocar** el dominio específico, no asumir que parte sin ninguno.

---

## 14. Changelog

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
