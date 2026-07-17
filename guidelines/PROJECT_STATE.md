# edu_platform — Estado del proyecto (magro)

> **Qué es este documento.** La **fuente única de verdad del ESTADO ASENTADO** del proyecto
> `edu_platform`: invariantes de arquitectura decididos, mapa de dominios, RBAC. Es el que se
> lee/pega cada iteración para entender qué ya existe antes de decidir el próximo slice.
>
> **Split editorial (v1.5.1):** este doc solía cargar también el changelog completo y las
> narrativas de "cómo se construyó" cada pieza — eso ahora vive en **`HISTORIA.md`** (archivo
> append-only, hermano de este archivo), y se carga solo cuando hace falta el *por qué* de algo.
>
> **Split editorial #2 (v1.21.0):** el backlog ordenado y los guardrails operativos (que crecen con
> CADA slice) ahora viven en **`OPEN_PROCESS.md`** (otro hermano) — este documento queda enfocado
> en lo asentado (§1–§10), sin la sección que más rápido crecía.
>
> **El repositorio sigue siendo la fuente de verdad del código.** Ante discrepancia entre lo escrito
> aquí y lo que hay en disco, gana el repositorio, y se corrige este documento en la siguiente versión.

---

## Metadatos de versión

| Campo | Valor |
|---|---|
| **Versión del documento** | `v1.37.0` |
| **Fecha** | 2026-07-17 |
| **Tests** | 646 runs / 0 fallos / 1 skip preexistente (suite completa, en serie — ver `OPEN_PROCESS.md`) |
| **Estado en una línea** | Identidad real + RBAC/entitlement reales + portales de persona + autoservicio de staff + auditoría + CHECKPOINT E + #4 barrido (`teacher_management`/`group_management`/`schedules`-calificaciones/`counseling`) + matrícula por término real (`Schedules::ActiveTermEnrollmentScope`, v1.15.0) + `attendance` (v1.16.0) + `report_cards` (v1.17.0) + `finance` (v1.18.0) + `communication` completo (v1.19.0/v1.20.0) + **`assignments` — TRACK COMPLETO (v1.21.0–v1.26.0, ítem #6 del MVP)**: publicar/ver/calificar directo · entrega de texto · entregas grupales · adjuntos de entrega · materiales del docente · **rúbricas (v1.26.0): biblioteca reutilizable (`RubricTemplate`/`RubricCriterion`/`RubricLevel`/`RubricCellDescriptor`, tablas normalizadas), asociada vía `evaluation_method` (toggle bloqueado tras publicar, molde `group_work`), estructura congelada como snapshot jsonb al publicar (molde `price_tiers_snapshot`/`lines_snapshot`); calificar por rúbrica calcula y escribe la nota vía `GradeRecorder`/`GroupGrader` SIN CAMBIOS — la rúbrica nunca almacena la nota; portal ve nivel+descriptor por criterio, sin RBAC** + **`calendar`** (v1.27.0, ítem #7 del MVP): calendario compartido, audiencia institución-wide/grado/grupo por dos columnas de scope mutuamente exclusivas (mismo idioma que `role_assignments.scope_*`), tres ramas de `authorize!` sobre un solo permiso `calendar.manage`, merge de los vencimientos de `assignments` SOLO en el portal (`Calendar::Timeline`, entradas sintéticas nunca filas) + **`extracurriculars`** (v1.27.0, ítem #8 del MVP): actividades addon-gated (deporte/arte/refuerzo), cupo agregado con lock + índice único parcial, ambas vías de inscripción (colegio y acudiente), actividad paga = un `Finance::Charge` vía el puente `fee_cents`→`BigDecimal`/100 + **Portal del cuidador ampliado — ítem #9 del MVP (v1.28.0)**: el único hueco real era `attendance` (dominio v1.16.0 sin ninguna superficie de portal) — cerrado con `Attendance::StudentView` (query object, un solo camino de lectura reusado por ambas superficies) + `Portals::GuardianAttendanceController`/`StudentAttendanceController` (mismo molde relación-gated que `calendar`/`report_cards`, sin `authorize!`, fuera de `Navigation::Registry`). De paso: los hubs del portal (`guardian_students#show`, `student_portal#show`) enlazaban Boletines/Tareas/Finanzas pero NO Calendario/Actividades (construidos en v1.27.0 sin cablear su link desde el hub) — cerrado también. Y un hallazgo aparte: **no existía ningún enlace de cierre de sesión en TODA la app** (ni shell de staff ni portal) — `shared/_logout_link` (un `link_to` + `data-turbo-method: delete`, nunca `button_to`/`<form>`, para no chocar con los specs de portal que exigen "cero forms" en superficies de solo lectura) ahora vive en ambos layouts + **Provisioning de instituciones + correo real — ítem #10 del MVP (v1.29.0), CIERRA EL CAMINO CRÍTICO COMPLETO DEL MVP**: `Provisioning::ProvisionInstitution` (un solo flujo, una transacción) crea la institución (`Provisioning::CreateInstitution`, ya existía, usado antes solo por `db/seeds.rb`) Y bootstrapea su primer `institution_admin` real (`IdentityAccess::Bootstrap::FirstAdmin`: siembra el rol con TODO el catálogo de permisos salvo `cross_tenant_reports.view`, resuelve/crea la persona vía `Core::People::Resolver`, invita por el MISMO camino que `PeopleController#create`) — cierra un chicken-and-egg real que no tenía ningún camino de producción (solo pasaba en tests y en un rake QA-only). `ControlPlane::InstitutionsController#new/#create` expone esto (molde de `PlansController`, audit log incluido); `Core::Institution` ganó las validaciones de unicidad/inclusión que antes solo vivían como constraint de BD. Correo real: SMTP genérico vía `Rails.application.credentials.dig(:smtp, ...)` con fallback a `ENV["SMTP_*"]` (funciona con cualquier proveedor, cero gemas nuevas) en producción; development pasó de descartar correos en silencio a escribirlos en `tmp/mails/` (`delivery_method: :file`, nativo de la gema `mail`, cero gemas nuevas) + **S3b — emisión real de uso por dominio (v1.30.0, post-MVP, M1 medio cerrado)**: `ControlPlane::Usage::Ingest.emit` (variante resiliente de `.call` — traga `Rejected`, nunca rompe la acción de negocio si el addon no está sembrado/medido) ahora se llama de verdad desde 6 dominios: `Communication::MessageSender` (mensajes), `Attendance::RecordsController` (registros, uno por estudiante del roster), `Extracurriculars::EnrollmentCreator` (inscripciones), `Assignments::SubmissionRecorder` (entregas), `ReportCards::Publisher` (boletines, keyed por (estudiante,término) para sobrevivir la regeneración del snapshot), `Finance::ChargeCreator`/`PaymentRecorder` (transacciones). `PeriodCut`/`RollupJob` sin cambios (ya sumaban correctamente). `transportation` se corrigió a `metered:false` en el seed (Clase C, no tenía ningún evento real que medir — el seed anterior era aspiracional) + **RBAC intra-plano (v1.31.0)**: `platform_admins.role` (`super_admin`/`billing_ops`/`viewer`, default `super_admin` backward-compatible) + `ControlPlane::Authorization` (mapeo estático rol→permisos, no el esquema tenant-side) gatea catálogo/provisioning/billing/gestión-de-admins; lecturas siguen abiertas a cualquier admin activo + **Schedule recurrente (v1.32.0)**: `Core::Headcount::SnapshotAllJob`/`ControlPlane::Billing::PeriodCutAllJob`/`IdentityAccess::Invitations::ExpireAllJob` (fan-out per-institución nuevos) + `config/recurring.yml` corren `SnapshotJob`/`RollupJob`/`PeriodCutJob`/`Expirer` solos ahora (rollup 1am, snapshot 2am, sweep de invitaciones 4am diarios; corte de facturación 3am del día 1 de cada mes) — los rakes manuales siguen vivos, ya no son el único camino + **Hardening de billing (v1.33.0)**: `EXCLUDE USING gist` (btree_gist) en `subscriptions`/`institution_entitlements` prohíbe solapamiento de rangos de fecha por institución (más allá de "una activa a la vez", que los índices únicos ya cubrían) — destapó que `Entitlement#revoke!` nunca cerraba `valid_until` (a diferencia de `Subscription#end!`), corregido con el mismo molde + **`analytics_bi` (v1.34.0)**: `InstitutionDashboard` real (tenant-scoped, sin BYPASSRLS) — reemplaza el stub de números fijos; `CrossTenantReportRoster` (cross-tenant, `edu_bi_reader`) sigue en stub a propósito, diferido a su propio slice + **`analytics_bi` Slice 1 (v1.35.0, `guidelines/BI_DOCUMENT.md`)**: `CrossTenantReportRoster` real — primera conexión `BYPASSRLS` de la app (`AnalyticsBi::BiReaderRecord`, pool de conexión separado, nunca reconfigura el primario), agregados SIEMPRE agrupados por `institution_id` explícito, cada acceso auditado (`cross_tenant_report_accessed`). Ver `HISTORIA.md` v1.35.0. + **`analytics_bi` Slice 2 — Lente 1 "Mapa de Empatía Espacial" (v1.36.0, `guidelines/BI_DOCUMENT.md`)**: geometría de aula net-new en `group_management` (decisión A2 — `GroupManagement::ClassroomLayout`/`SeatAssignment`, efectivo-fechadas, append-only, tres `EXCLUDE gist` de no-solapamiento/no-double-booking; reconfiguración vía `ClassroomReconfigurer`/`SeatAssigner` con `requires_new` savepoint, gateada por `groups.manage`) + capa de calor derivada in-memory de T1 (notas/asistencia, `AnalyticsBi::Lens::SpatialHeatmap`, HSL server-side por asiento) renderizada como SVG server-rendered (`AnalyticsBi::Svg::SeatGrid`) + dimming vía Stimulus sin round-trip; superficie de lectura en `analytics_bi` gateada por el nuevo `hps.classroom.view` (molde #4, tenant-scoped, NO cross-tenant). Aura overlay (§5.7) diferido a Slice 3. Ver `HISTORIA.md` v1.36.0. + **`analytics_bi` Slice 3 — Lente 5 "Auras de Cuidado" (v1.37.0, `guidelines/BI_DOCUMENT.md`)**: proyección `care_auras` net-new EN `analytics_bi` (tenant-scoped, RLS `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`, efectivo-fechada) — enum CERRADO `aura_kind` (`string`+CHECK, molde `extracurriculars.kind`) + `guidance_text` (cero PII clínica) + `authored_by_counselor_id` (FK a `institution_users`, identidad; **cero asociación a `counseling`**). Escrita SOLO por `AnalyticsBi::Aura::Projector` invocado DESDE `counseling` (`Counseling::CareAurasController`, gate `counseling.write` — el key EXISTENTE), append-only (molde `SeatAssigner`); índice único PARCIAL "una activa por (student, kind)". El docente la lee como un ícono «♥» ADITIVO sobre la Lente 1, gate `hps.aura.view` (permiso nuevo, 2ª mitad del split de dos lados), vía `AnalyticsBi::Lens::AuraScope` que devuelve un `Data` de 4 campos (allowlist por construcción). **Aislamiento clínico probado a nivel de MODELO** (SQL tap + estructura de asociaciones): ninguna query del docente toca `counseling_cases`/`session_notes`/`referrals`. Ver `HISTORIA.md` v1.37.0. |

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
| `group_management` | Grupos | `groups` (`kind` homeroom/…), membresía/rosters. `students.user_id` y `students.national_id` (cifrado) viven en el modelo de este dominio (`GroupManagement::Student`). **Desde v1.36.0 también posee la GEOMETRÍA física del aula** (decisión A2 de `BI_DOCUMENT.md`): `GroupManagement::ClassroomLayout`/`SeatAssignment` (efectivo-fechadas, append-only, `EXCLUDE gist`), escritas por `ClassroomReconfigurer`/`SeatAssigner` (gate `groups.manage`); `analytics_bi` solo las lee para la Lente 1. |
| `schedules` | Libreta de notas (real) **+** horarios/timetabling (Clase C, sin tabla) | **Real**: `Subject`/`Enrollment`/`Assessment` (calificaciones, v1.14.0); `Enrollment.academic_term_id` conecta con `academic_terms` (v1.15.0 — `Schedules::ActiveTermEnrollmentScope` es el resolver canónico de "matriculado en el término activo"). **Sin tabla real** (Clase C): rooms/patrones de reunión — `WITHOUT OVERLAPS` de PG18 es diseño, no implementación. |
| `student_support` | Bienestar | Convivencia, **historia médica (dueño)**, acomodaciones. Sensible. Tabla legacy `student_guardians` coexiste con `core.guardian_students` (no migrada; ver §3.2). |
| `cafeteria` | Alimentación | Checkout con **bloqueo por alérgeno** (lee `student_support`). Wallet/saldo, transacciones idempotentes. |
| `transportation` | Rutas | Rutas, paradas, check-in/out de abordaje. Notifica a acudientes (Turbo Streams/Solid Cable — diferido). |
| `analytics_bi` | Reporting + HPS (ver `guidelines/BI_DOCUMENT.md`) | `InstitutionDashboard` (v1.34.0, tenant-scoped) y `CrossTenantReportRoster` (v1.35.0, cross-tenant vía `edu_bi_reader`/`BYPASSRLS`, auditado) — **ambas mitades reales**. **Lente 1 "Mapa de Empatía Espacial" real (v1.36.0, Slice 2)**: lee la geometría de aula de `group_management` (nunca la posee) y deriva un heat in-memory de T1 (notas/asistencia), SVG server-rendered, gate `hps.classroom.view` (tenant-scoped). **Lente 5 "Auras de Cuidado" real (v1.37.0, Slice 3)**: posee `care_auras`, la PROYECCIÓN (enum cerrado + guía, cero PII clínica) que `counseling` publica vía `AnalyticsBi::Aura::Projector` y el docente lee como un ícono abstracto sobre la Lente 1 (`hps.aura.view`); `analytics_bi` nunca lee tablas de `counseling` (aislamiento clínico probado a nivel de modelo). `BI_DOCUMENT.md` redefine el alcance futuro del dominio (Sistema de Posicionamiento Humano, 5 lentes, T1/T2/T3) y manda sobre `LINEAMIENTOS_MVP.md` para este dominio. |

### Tier B — identidad/roles

| Dominio | Propósito |
|---|---|
| `identity_access` | IAM/RBAC **+ onboarding**. Posee el catálogo global `roles`/`permissions`/`role_permissions`, `role_assignments` (tenant, scope por columnas explícitas), `invitations`, `email_otps`, `audit_events`, los servicios `Otp::*` e `Invitations::*`, `Audit`, y el controller/vistas de `people`. **No posee** `users`/`institution_users` (son de `core`); referencia por FK. |

### Tier B-bis — confirmados

| Dominio | Propósito |
|---|---|
| `counseling` | Psicoorientación. **Carve-out de `student_support`.** Casos/expedientes, sesiones/notas, remisiones, planes de intervención. Puede *leer* (no poseer) la historia médica de `student_support`. **Frontera de confidencialidad más estricta** que convivencia. **Desde v1.37.0 es el ÚNICO autor de las "auras de cuidado"** (Lente 5 del HPS): publica la proyección abstracta `analytics_bi.care_auras` vía `AnalyticsBi::Aura::Projector` (gate `counseling.write`, superficie anidada bajo el caso) — el diagnóstico (T3) NUNCA sale de aquí; solo cruza el enum+guía sin PII clínica. |
| `finance` | Tesorería/cartera **dentro** del tenant (el colegio cobra pensiones a acudientes). Cargos, pagos, estados de cuenta, planes de pago. **≠ billing de plataforma.** Tenant-scoped. **UI real desde v1.18.0**: `StudentAccount`/`Charge`/`Payment` (existían desde el primer commit) ahora tienen superficie de supervisión (molde #4, `finance.read`/`finance.write` — permisos que YA existían y ya reusaba `Cafeteria::BalancesController`) y portal del acudiente (solo lectura, mismo camino de lectura — `Finance::AccountStatement`). Dinero en `decimal(12,2)`, NO `*_cents bigint` (ver Guardrails). `PaymentPlan`/`Installment` (planes de pago/cuotas) siguen **sin UI**, diferidos a su propio slice — no alimentan el saldo hoy. |
| `communication` | Hub de comunicación. Ver §8 (anexo). **Ambos subsistemas reales**: (A) anuncios (v1.19.0, `Communication::Announcement`, difusión org-wide, RBAC para publicar + lectura por membresía); (B) mensajería (v1.20.0, `Conversation`/`ConversationParticipant`/`Message`, multiparte, participante `institution_user` **o** `guardian_user` — CHECK exactamente-uno, cuatro caminos de acceso RBAC/participación/auditoría). Diferidos anotados en §8.2 (fan-out 1:1, threading, tags, acudiente-inicia). |
| `attendance` | **Asistencia diaria por homeroom (v1.16.0, item #2 del MVP)** — dominio NET-NEW, real desde el día uno (sin fase stub). `AttendanceRecord` (`student_id`+`group_id`+`date`, único `(institution_id, student_id, date)`). Consume `Schedules::ActiveTermEnrollmentScope` (nunca re-deriva el join a término); molde #4 completo (per-row `can?`, `authorize!`, nav). Addon-gated. Por-materia diferido. |
| `report_cards` | **Boletines (v1.17.0, item #3 del MVP)** — dominio NET-NEW, addon-gated, lee `schedules` por FK (nunca posee `Subject`/`Enrollment`/`Assessment`). `ReportCard` (`student_id`+`academic_term_id`, único `(institution_id, student_id, academic_term_id)`) — snapshot **congelado al publicar** (`lines_snapshot` jsonb + `overall_average`, nunca recomputado al leer un publicado). "Draft" es cómputo vivo sin fila (`ReportCards::Computation`, consumido tanto por el preview de supervisión como por `ReportCards::Publisher`). Dos superficies: supervisión (molde #4, `report_card.view`/`report_card.publish`) y portal (por relación, solo publicados, sin `authorize!`, fuera de `Navigation::Registry`). Consume `Schedules::ActiveTermEnrollmentScope` igual que `attendance`. Asistencia en el boletín y escala Decreto 1290 diferidos. |
| `assignments` | **Tareas académicas — TRACK COMPLETO, slices 1–4/4 (v1.21.0–v1.26.0, item #6 del MVP)** — dominio NET-NEW, addon-gated, cuelga del gradebook de `schedules` por FK (`Assignments::Assignment` → `subject_id`; `schedules::Assessment` gana `assignment_id` nullable, aditivo). **La nota vive SOLO en `schedules::Assessment`** — publicar hace fan-out (una fila `Assessment` por matrícula del roster, `score: nil`, SIEMPRE per-student, con o sin `group_work`/rúbrica); calificar `UPDATE`-ea esa misma fila (`Assignments::GradeRecorder`), nunca un almacén paralelo. Roster = `Schedules::ActiveTermEnrollmentScope` ∩ la materia ∩ scope RBAC del docente (vía `grade_level_id` de `Subject`, mismo mecanismo que ya usaba `grades.write`). Supervisión (molde #4, `assignment.manage`) + portal (por relación, solo `published`, con la nota leída del mismo origen que `report_cards`). **v1.22.0**: entrega de texto (`Assignments::Submission`, en-domain, NO anclada a `assessment_id` — pareo entrega↔nota vía `Assignments::GradingView`), ingresable por el estudiante o su acudiente (B1) — primer write de portal, gateado por relación. **v1.23.0**: `group_work` toggle por-tarea (bloqueado tras publicar); `Submission` generalizada a estudiante **XOR** `SubmissionGroup` (CHECK real, patrón de `conversation_participants` v1.20.0); grupos por-tarea (`GroupMembership`, estudiante en ≤1); nota grupal = bulk-set per-student (`GroupGrader`) + override individual, sin almacén grupal; entrega compartida editable por cualquier integrante sin `group_id` explícito. **v1.24.0**: adjuntos de entrega (docx/pdf/jpg/png, ≤10MB, ≤5) sobre una `Submission` ya existente — tabla puente tenant-scoped `Assignments::SubmissionAttachment` (RLS `ENABLE+FORCE`; las tablas crudas de Active Storage NUNCA llevan RLS, ver `OPEN_PROCESS.md`); content-type real vía Marcel en un service object (`AttachmentAdder`); tres controllers de servicio, nunca las rutas firmadas de Active Storage. **v1.25.0**: materiales del docente (`Assignments::Material`, mismo molde de tabla puente, dueño `Assignment`) — escritura gateada por RBAC (`assignment.manage`, 403 sin permiso), no por relación; lectura de portal SIN CAMBIOS (`StudentView`/`GuardianScope`), un borrador/archivada es inalcanzable gratis; `Assignments::AttachmentTypeCheck` (nuevo) comparte la validación de tipo/tamaño con `AttachmentAdder`. **v1.26.0 — CIERRA EL TRACK**: rúbricas — biblioteca reutilizable normalizada (`RubricTemplate`/`RubricCriterion`/`RubricLevel`/`RubricCellDescriptor`) asociada vía `evaluation_method` (`direct`/`rubric`, mismo freeze de `group_work`); estructura congelada como snapshot jsonb al publicar (molde `price_tiers_snapshot`/`lines_snapshot`); `Assignments::RubricScore` calcula, `RubricGrader`/`GroupRubricGrader` persisten la evaluación (`RubricEvaluation`, estudiante XOR grupo) y escriben la nota vía `GradeRecorder`/`GroupGrader` SIN CAMBIOS — la rúbrica NUNCA almacena la nota; portal ve nivel+descriptor por criterio (`StudentView.rubric_breakdown_for`), sin RBAC. Ver `HISTORIA.md` v1.21.0–v1.26.0. |
| `calendar` | **Calendario compartido con cuidadores (v1.27.0, item #7 del MVP)** — dominio NET-NEW, addon-gated, real desde el día uno (sin fase stub). `Calendar::Event` (`calendar_events`: `title`/`description`/`starts_at`/`ends_at`, CHECK `ends_at >= starts_at`). **Audiencia por dos columnas de scope mutuamente exclusivas** (`scope_grade_level_id` XOR `scope_group_id`, ambas null ⇒ institución-wide; CHECK de exclusividad + validación de modelo), mismo idioma que `role_assignments.scope_*`. **Deliberadamente SIN `kind`** (supersede a `LINEAMIENTOS_MVP.md §4.2`) — los "deadlines" se derivan en memoria, nunca como fila. `created_by_institution_user_id` nullable+nullify (atribución). Índice `(institution_id, starts_at)` (líder `institution_id` para el RLS guard + orden cronológico) + índices en las dos columnas de scope. **Tres ramas de `authorize!` sobre el único permiso `calendar.manage`**, según la audiencia elegida (grupo→`Section`, grado→`GradeLevel`, institución-wide→`Current.institution`), sobre el mismo `Authorization::Assignment#covers?`+`SCOPE_READERS`; `GroupManagement::GradeLevel#grade_level_id` (nuevo) es el primer consumidor real de `scope_grade_level_id` fuera de `PermissionCheck`. Dos superficies: gestión de staff (molde #4, `ManageableScope`, `calendar.manage`, solo `calendar_events` reales) y portal estudiante/acudiente (relación, `VisibleScope`+`Timeline`, sin `authorize!`, fuera de `Navigation::Registry`). `Calendar::Timeline.for(student:)` mezcla eventos reales con los `due_date` de las `assignments` publicadas visibles a ESE estudiante (entradas sintéticas `Calendar::Timeline::Entry`, nunca filas) — **solo en el portal** (asimetría con la gestión de staff, "un solo camino de lectura"). Ver `HISTORIA.md` v1.27.0. |
| `extracurriculars` | **Actividades extracurriculares (v1.27.0, item #8 del MVP)** — dominio NET-NEW, addon-gated, real desde el día uno. `Activity` (`kind` deporte/arte/refuerzo, `academic_term_id` FK NOT NULL, `fee_cents` bigint — dinero NUEVO en F6, nunca `decimal`) + `Enrollment` (`activity_enrollments`, soft active/withdrawn, `enrolled_via` staff/guardian). **Cupo** = invariante agregado (`activity.lock!` + `COUNT` en `EnrollmentCreator`, nunca un CHECK declarativo) respaldado por un índice único PARCIAL `(institution, activity, student) WHERE status='active'`. **RBAC ownership-vs-hierarchy**: `activity.manage` (institución-wide) vs. `activity.instruct` (propiedad de fila — `Extracurriculars::ActivityScope` filtra directo por `instructor_staff_member_id`, NO un `scope_type` nuevo en `role_assignments`). Ambas vías de inscripción (colegio y acudiente). Portal estudiante (solo lectura) + acudiente (lectura + inscribir/desinscribir per-child, sin RBAC). Actividad paga = un `Finance::Charge` (el puente `fee_cents`→`BigDecimal`/100 vive en `Activity#fee_amount`, un solo lugar). Ver `HISTORIA.md` v1.27.0. |

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
| **M1** | **Unidad de metering por dominio medido** | El control plane solo consume rollups; `addons.unit` sigue provisional. | 🟡 **Medio cerrado (v1.30.0, S3b).** Cierra per-dominio, no de una vez — 6 dominios ya emiten real (`communication`/mensajes, `attendance`/registros, `report_cards`/boletines, `assignments`/entregas, `extracurriculars`/inscripciones, `finance`/transacciones vía `ControlPlane::Usage::Ingest.emit`). Sigue abierto para el resto (`transportation`/`cafeteria`/`student_support`/`counseling`/`analytics_bi`/`schedules`-timetable) — todos Clase C o sin evento de negocio claro, ver `OPEN_PROCESS.md`. |
| P1 | `IdentityAccess::PermissionCheck` real | — | ✅ Cerrado (v1.6.0) — ver `HISTORIA.md`. |
| **P2** | **Rol libre `institution_users.role`** | Columna string sin lectores en el código (ver §5). Puede generar confusión con el RBAC real. | 🔴 Abierto. Decidir si se elimina, se documenta como legacy, o se conecta a algo. |
| **Cav.** | **Headcount de `base_seats` no filtra por matrícula/término** — **mitad de MODELO cerrada (v1.15.0), mitad de FACTURACIÓN sigue abierta a propósito** | `enrollments.academic_term_id` (FK real, nullable) ya conecta `Schedules::Enrollment`↔`academic_terms` — `Schedules::ActiveTermEnrollmentScope` resuelve "estudiantes matriculados en el término activo" de verdad. **Pero** `Core::Headcount::Snapshotter` sigue contando `students.status == "active"`, deliberadamente sin tocar (F3) — S4 sigue facturando sobre ese mismo número. | 🟡 **Medio cerrado.** El join ya existe y es consumible por slices académicos (asistencia, notas-por-término, actividades, asignaciones — ver `LINEAMIENTOS_MVP.md`). Facturar sobre "matriculado en el término activo" en vez de `status == "active"` es una **decisión separada y explícita**, no reabierta aquí — ver Guardrails (§12) y `HISTORIA.md` v1.15.0. |

---

## 11. Próximas iteraciones y guardrails operativos

> **Movido a `OPEN_PROCESS.md` en v1.21.0.** El backlog ordenado (antes §11) y los guardrails
> operativos (antes §12) crecen con cada slice y ya dominaban el tamaño de este documento, que debe
> quedar enfocado en **estado asentado** (arquitectura, mapa de dominios, RBAC). `OPEN_PROCESS.md`
> es el archivo que se actualiza en CADA slice de aquí en adelante — este documento ya no.

---

## 12. Changelog

El changelog completo (`v1.0.0` → `v1.26.0`) vive en **`HISTORIA.md`**. Entrada de esta versión:

- **`v1.26.0` — `assignments`: rúbricas, slice 4/4 (ítem #6 del MVP) — CIERRA EL TRACK.** Recon sin
  contradicciones: `assignment.manage` sigue siendo el único permiso de autoría/calificación;
  `GradeRecorder`/`GroupGrader` (v1.21.0/v1.23.0) se reusan tal cual, nunca reimplementados;
  `lock_group_work_after_publish` (v1.23.0) fue el molde exacto copiado para el nuevo
  `lock_evaluation_method_after_publish`. Biblioteca de rúbricas reutilizable, tablas normalizadas
  tenant-scoped (`RubricTemplate`/`RubricCriterion`/`RubricLevel`/`RubricCellDescriptor`,
  author-owned este slice); asociada a una tarea vía `evaluation_method` (`direct`/`rubric`), toggle
  bloqueado tras publicar igual que `group_work`. La estructura se congela como snapshot jsonb
  (`Assignment#rubric_snapshot`) al publicar — MISMO molde que `ControlPlane::Subscription#price_
  tiers_snapshot`/`ReportCards#lines_snapshot` — editar la plantilla-biblioteca después nunca toca
  una tarea ya publicada (verificado byte a byte). Calificar por rúbrica: `Assignments::RubricScore`
  calcula `(Σ pts×peso)/(Σ máx×peso)×5` (1 decimal, pesos relativos, nunca suman 100 obligatoriamente);
  `RubricGrader`/`GroupRubricGrader` persisten la evaluación (`RubricEvaluation`, estudiante **XOR**
  grupo, mismo CHECK que `Submission` v1.23.0) y escriben la nota vía `GradeRecorder`/`GroupGrader`
  SIN NINGÚN CAMBIO — la rúbrica NUNCA almacena la nota. Portal (`StudentView.rubric_breakdown_for`,
  nuevo) ve nivel+descriptor por criterio, sin RBAC, sin cambio de scope. La grilla de calificación
  es la única pieza con JS real del slice (`rubric_grid_controller.js`, Stimulus, cero round-trips
  por clic — display-only, el servidor sigue siendo la fuente de verdad); agregar/quitar
  criterios/niveles es server-round-trip simple (sin precedente de nested-attributes-con-JS en esta
  casa que respalde un builder cliente-side más complejo). 528→540 tests totales (12 nuevos, sin
  fixtures binarios nuevos). Un incidente operativo (no de producto): un `bin/rails runner` de
  depuración sin transacción de rollback dejó un usuario/institución huérfano COMMITTED en la BD de
  test, rompiendo dos tests preexistentes no relacionados — detectado por la suite completa, limpiado,
  guardrail nuevo agregado sobre scripts de depuración. Un hallazgo real (no operativo): la migración
  de `rubric_cell_descriptors` no tenía índice liderado por `institution_id` — lo detectó
  `TenantRlsGuardTest`, corregido antes de cerrar. Narrativa completa en `HISTORIA.md`.

- **`v1.25.0` — `assignments`: materiales del docente, slice 3b/4 (ítem #6 del MVP).** Recon sin
  contradicciones esta vez (a diferencia de v1.24.0): `assignment.manage` es el ÚNICO permiso que
  gatea autoría de una tarea — se reusó directamente, sin permiso nuevo; `StudentView.for(student)`
  filtra por `Assignment.published`, así que un borrador Y una tarea archivada desaparecen del
  scope del portal por igual, sin ningún chequeo aparte para materiales. Mismo molde de tabla puente
  tenant-scoped que v1.24.0(`Assignments::Material`, RLS `ENABLE+FORCE`), dueño `Assignment` en vez
  de `Submission`. La diferencia real: escritura gateada por RBAC (`authorize!("assignment.manage",
  @subject)`, **403** si falta, nunca el 404 de relación de un portal) — es el recurso del docente,
  no un write de portal. Lectura sin cambios: estudiante/acudiente siguen entrando por
  `StudentView`/`GuardianScope` de siempre. Se extrajo `Assignments::AttachmentTypeCheck` (nuevo,
  `services/`) — la validación de tipo real (Marcel)/tamaño que era IDÉNTICA entre
  `AttachmentAdder` (v1.24.0) y el nuevo `MaterialAdder` — y se refactorizó `AttachmentAdder` para
  reusarlo (verificado sin regresión contra su propia suite). Permitido mientras
  `draft`/`published`, bloqueado en `archived` — agregar un material DESPUÉS de publicar es normal
  (no es un snapshot congelado como `report_cards`). 519→528 tests totales (9 nuevos, sin fixtures
  binarios nuevos — reusa los de v1.24.0). Narrativa completa en `HISTORIA.md`.

- **`v1.24.0` — `assignments`: adjuntos de entrega, slice 3/4 (ítem #6 del MVP).** Recon (STOP):
  Active Storage YA estaba instalado desde el primer commit (tablas + `config/storage.yml`), no una
  instalación nueva como asumía el prompt; la FK real es a `submissions`, no `assignments_
  submissions`. Diseño: las tablas crudas de Active Storage (`active_storage_*`) no tienen
  `institution_id`/RLS — adjuntar directo ahí sería una exposición cross-tenant real (mismo
  razonamiento que ya documentaba `Core::RosterImportBatch`), así que `Assignments::
  SubmissionAttachment` es una tabla puente tenant-scoped (RLS `ENABLE+FORCE`) — un blob solo es
  alcanzable resolviendo primero su fila puente. Content-type real vía Marcel (magic bytes,
  `identify: true`), nunca extensión ni header declarado, validado en `Assignments::AttachmentAdder`
  (service object, sin gemas nuevas): tamaño ≤10MB verificado ANTES de adjuntar, tipo verificado
  DESPUÉS (Marcel solo corre sobre un blob ya adjunto) — un adjunto rechazado se purga de inmediato,
  nunca queda huérfano. Tres controllers de servicio (`Assignments::AttachmentsController` docente,
  `Portals::{Student,Guardian}AttachmentsController`), nunca las rutas firmadas default de Active
  Storage — misma convención de "un controller por camino de acceso" que communication/v1.20.0.
  Adjuntar/quitar comparte la disciplina de escritura por relación ya establecida (v1.22.0/v1.23.0):
  el gate de lectura ES el gate de escritura, y para grupos la `GroupMembership` del propio actor
  resuelve la `Submission` compartida, nunca un `group_id` del request. docx = descarga
  (`Content-Disposition: attachment`), pdf/jpg/png = inline. 510→519 tests totales (9 nuevos, con
  fixtures binarias reales — incluido un `.docx` OOXML válido mínimo construido con `rubyzip` para
  que Marcel lo detecte de verdad, no solo por extensión). Narrativa completa en `HISTORIA.md`.

- **`v1.23.0` — `assignments`: entregas grupales (ítem #6 del MVP).** Generaliza v1.22.0:
  `group_work` toggle por-tarea (criterio del docente, sin regla por grado), settable en `draft`,
  bloqueado tras publicar por un `before_validation` en el MODELO (defensa en profundidad, no solo
  la vista). `Assignments::Submission` generalizada a estudiante **XOR** `Assignments::
  SubmissionGroup` — mismo patrón `CHECK (num_nonnulls(...) = 1)` que `conversation_participants`
  ya estableció en v1.20.0; las validaciones `uniqueness` de Rails llevan `allow_nil: true`
  (sin eso, Rails trataría dos NULL como duplicado, a diferencia del índice único de Postgres).
  `Assignments::SubmissionGroup`/`GroupMembership` nuevos — grupos por-tarea (nunca reutilizables
  entre tareas), un estudiante en ≤1 grupo por asignación (único real). El fan-out per-student de
  `Assignments::Publisher` (v1.21.0) queda **sin cambios**: cada estudiante del roster sigue
  recibiendo su propia fila `Assessment` con o sin `group_work` — lo grupal es una conveniencia de
  calificación/entrega encima del mismo fan-out, nunca un segundo mecanismo. Nota grupal =
  `Assignments::GroupGrader` (bulk-set reusando `GradeRecorder` por integrante) + override
  individual por el mismo camino de siempre; re-aplicar la grupal re-setea a todos, sin baseline
  guardado. La entrega compartida la edita cualquier integrante SIN que el request acepte un
  `group_id` — `SubmissionRecorder` resuelve el grupo del actor vía su propia `GroupMembership`, lo
  que hace que dos integrantes distintos siempre converjan en la MISMA fila. Un estudiante sin
  grupo ve el empty state (nunca error) y no puede entregar (404 si lo intenta). Confirmado por
  recon: no existe `GroupManagement::Group` (el "grupo de clase" real es `Section`), así que
  `Assignments::SubmissionGroup` no colisiona con nada — nombre elegido igual, por claridad. 499→510
  tests totales (11 nuevos). Narrativa completa en `HISTORIA.md`.

- **`v1.22.0` — `assignments`: entrega de texto, slice 2/4 (ítem #6 del MVP).** Recon confirmó el
  modelo real que dejó v1.21.0 sin sorpresas materiales. Tabla nueva `submissions` con llave
  EN-DOMINIO `(assignment_id, student_id)` — deliberadamente NO anclada a `schedules::assessments`
  (el default del prompt, confirmado como la opción más limpia): el pareo entrega↔nota se resuelve
  en `Assignments::GradingView`, un servicio de lectura (mismo patrón que
  `Finance::AccountStatement`), nunca por FK cruzado — mantiene `assignments` sin acoplar un eje
  nuevo hacia `schedules`. **Primer write desde un portal**: gateado por la MISMA relación que ya
  gatea la lectura (`Assignments::StudentView.for(student)`), nunca RBAC — una tarea fuera de ese
  scope (ajena, `draft`, `archived`) 404 en la escritura exactamente como en la lectura.
  `submitted_by_user_id` registra atribución (el estudiante o su acudiente, por B1 — un menor sin
  login entrega a través de su acudiente); la entrega siempre pertenece al `student_id`, nunca a
  quien la tecleó. Tardía es un flag calculado (`Submission#late?`), nunca un bloqueo. 487→499 tests
  totales (12 nuevos, incluyendo dos que atraparon un bug de test real: reusar `as_teacher` después
  de un `sign_in_as` de portal no basta — hay que re-autenticar la sesión de vuelta). Narrativa
  completa en `HISTORIA.md`.

- **`v1.21.0` — `assignments`: tareas académicas, slice 1/4 (ítem #6 del MVP: publicar + ver +
  calificar directo).** Recon confirmó net-new en TODOS los niveles (sin tabla, sin gating, sin
  permisos — a diferencia de `finance`/`communication`). Hallazgo material que corrigió el modelo
  de datos: `schedules::Assessment belongs_to :enrollment` (no `:subject`) y el `score` vive
  DIRECTAMENTE en esa fila — no hay tabla de "grade-entries" separada. Un FK singular
  `assignments.assessment_id` no puede representar una tarea de todo un curso; el FK va al revés:
  `assessments.assignment_id` (nullable, aditivo, mismo patrón que `enrollments.academic_term_id`).
  Publicar (`Assignments::Publisher`) hace fan-out: una fila `Assessment` por matrícula del roster
  (`ActiveTermEnrollmentScope` ∩ la materia ∩ scope RBAC del docente vía `grade_level_id` de
  `Subject` — el mismo mecanismo que ya usaba `grades.write`, sin inventar una dimensión de scope
  nueva), cada una `score: nil`. Calificar (`Assignments::GradeRecorder`) `UPDATE`-ea esa misma
  fila — nunca crea una segunda. A diferencia de mensajería (v1.20.0), aquí `ActiveTermEnrollmentScope`
  SÍ es el resolver semánticamente correcto (elegibilidad académica real). Estado
  draft/published/archived — archivar es soft, nunca toca las notas ya fanned-out; solo un borrador
  (cero assessments por construcción) se puede eliminar de verdad. Portal (estudiante/acudiente):
  solo lectura, solo `published`, nota leída del MISMO origen que `report_cards`
  (`Assignments::StudentView`). Slices 2–4 (entrega de texto, adjuntos, rúbricas) registrados como
  roadmap en `HISTORIA.md`, sin construir. 472→487 tests totales (15 nuevos). **Este slice también
  disparó el split editorial #2**: §11 (backlog) y §12 (guardrails) de este documento se movieron a
  `OPEN_PROCESS.md` — se actualiza ahí de aquí en adelante, no aquí.

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
