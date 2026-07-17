# edu_platform

Multi-tenant SaaS for K-12 schools, built on **Rails 8.1** and **PostgreSQL 18**.
Each institution is an isolated tenant (row-level, shared-schema) that enables
functionality by purchasing **addons** — where one addon maps **1:1** to one
bounded-context domain. Identity is **global and multi-institution**: one person
has a single login and can belong to several institutions.

## Status

| Field | Value |
|---|---|
| **Document version** | `v1.26.0` |
| **Date** | 2026-07-16 |
| **Tests** | 540 runs / 0 failures / 1 pre-existing skip (full suite, serial — see `guidelines/OPEN_PROCESS.md`) |
| **One-line status** | Real identity + real RBAC/entitlement + person portals + staff self-service + auditing + CHECKPOINT E + #4 sweep (`teacher_management`/`group_management`/`schedules`-grading/`counseling`) + real per-term enrollment (`Schedules::ActiveTermEnrollmentScope`, v1.15.0) + `attendance` (v1.16.0) + `report_cards` (v1.17.0) + `finance` (v1.18.0) + full `communication` (v1.19.0/v1.20.0) + **`assignments` — FULL TRACK (v1.21.0–v1.26.0, MVP item #6)**: direct publish/view/grade · text submission · group submissions · submission attachments · teacher materials · **rubrics (v1.26.0): reusable library (`RubricTemplate`/`RubricCriterion`/`RubricLevel`/`RubricCellDescriptor`, normalized tables), associated via `evaluation_method` (toggle locked after publish, `group_work` mold), structure frozen as a jsonb snapshot at publish (`price_tiers_snapshot`/`lines_snapshot` mold); rubric grading computes and writes the grade via `GradeRecorder`/`GroupGrader` WITH NO CHANGES — the rubric never stores the grade; the portal shows level + descriptor per criterion, no RBAC**. `guidelines/LINEAMIENTOS_MVP.md`/`guidelines/OPEN_PROCESS.md` order what comes next: `calendar` (net-new) or `extracurriculars`. |

---

## Locked stack (do not substitute)

| Layer | Choice | Notes |
|---|---|---|
| **Ruby** | 4.0.x with **YJIT** | ZJIT is experimental — **do NOT use or depend on it**. |
| **Rails** | 8.1.x | Rails 8 **native** authentication (`has_secure_password`, `Session`, `Authentication` concern, `Current`). **No Devise.** **Already implemented.** |
| **PostgreSQL** | 18 GA | Native: `uuidv7()`, RLS + FORCE, `WITHOUT OVERLAPS`, `UNIQUE NULLS NOT DISTINCT`, JSONB, native FTS, pgvector. **No extensions for UUID.** |
| **Async / cache / cable** | Solid Queue / Solid Cache / Solid Cable | **No Redis, no broker, no Sidekiq, no Elasticsearch.** Emails already go through Active Job on Solid Queue (`deliver_later` in `OtpMailer`/`InvitationMailer`); heavy import (roster) does not exist yet. |
| **Front-end** | Propshaft + importmap (no Node/build), turbo-rails + stimulus-rails, vanilla CSS with `tokens.css` and `@layer` | **No Tailwind, no Sass, no component gem, no icon-font.** |
| **Tests** | Minitest (default) | **No RSpec.** |
| **Authorization** | Hand-rolled RBAC over PG | **No Pundit / CanCan / rolify.** `IdentityAccess::PermissionCheck` is the real resolver (P1, closed) — real-only, fail-closed: with no applicable `RoleAssignment`, zero permissions. |
| **Cross-domain eventing** | In-process (`ActiveSupport::Notifications` / lightweight in-app bus + service objects at the edges) | **Never** a distributed broker. |

> **Universal PK:** UUID via the PG18 column default `default: -> { "uuidv7()" }`. Business-readable
> IDs (`student_code`, etc.) are separate columns, tenant-scoped, with a composite unique.
> Soft-delete via `deleted_at` where already used. `institution_users` instead uses `status`
> (`active`/`suspended`, DB CHECK) rather than soft-delete — a suspended membership still
> exists and remains auditable, it does not disappear.

---

## Settled architecture (base truth — build on top, do NOT reopen)

### Tenancy — row-level (shared-schema)

- Every tenant-owned table carries `institution_id`.
- **RLS is the DB backstop** (`ENABLE` + `FORCE ROW LEVEL SECURITY`, so it bites even the table owner).
- **Primary scoping** is explicit in Rails via **Query objects / `Tenant::Resolver` + `Tenant::Guc`** (real names in the repo — not `CurrentTenant`), **NEVER `default_scope`**.
- RLS predicate: `institution_id = current_setting('app.current_institution_id')::uuid`, with a twin `WITH CHECK` on INSERT/UPDATE.
- The GUC is set with `SET LOCAL` inside a per-request transaction (`TenantScoped#within_tenant`, `around_action`) or per job (`ApplicationJob#around_perform`, with an explicit `Tenant::Guc.reset!` — see Guardrails).
- A **tenant-resolution seam** exists (`Tenant::Resolver::SubdomainStrategy`, for future horizontal sharding). Sharding itself is **NOT** built (YAGNI at dev-only scale).

### Identity — global, multi-institution

- `institutions` and `users` are **GLOBAL** (no RLS). Everything else tenant-owned is **tenant-scoped**.
- **One person = one `users` row** (single login by `email`, `citext`, globally unique); can belong to multiple institutions via `institution_users`. Confirmed and in code production (⚠-1, closed — see `guidelines/HISTORIA.md`).
- Tenant resolution **by subdomain** (`institutions.slug`), via `Tenant::Resolver`.
- `student` and `guardian` are **person-entities, NOT RBAC roles**. Their access is resolved by **relationship** (`students.user_id`, `guardian_students`), not by `role_assignments`. A K-12 minor can exist without `user_id`; a guardian always has a login (⚠-2, closed — see `guidelines/HISTORIA.md`). The real `guardian_students` table already exists (domain `core`), alongside the legacy `student_support.student_guardians` (both coexist on purpose; the legacy one was not migrated). **Confirmed in v1.8.0:** a guardian's `institution_users` membership is not optional/cosmetic — `SessionsController#authenticate_credentials` requires `user.memberships.active.exists?(institution_id:)` to authenticate, so without it a guardian could not log in even after completing their invitation. `Core::People::Resolver` creates it; **always zero `role_assignments`** (a guardian is not staff).

### Postgres roles and DB operational reality

- **`edu_app_runtime`** — serves the app. `NOSUPERUSER`, **no `CREATE`** on `public`, **no `BYPASSRLS`**.
- **`edu_migrator`** — runs migrations. Has `CREATE`. Must have it on **all** databases (primary **and** the three Solid: cache/queue/cable).
- **`edu_bi_reader`** (audited role) — the **only** role with `BYPASSRLS`; only for super-admin / BI cross-tenant reads (real name in `lib/tasks/roles.rake`). **The runtime never does cross-tenant reads.**
- **Migrations run with `bin/migrate`** (which requires a non-empty `EDU_MIGRATOR_PASSWORD`), **NOT** `rails db:migrate` (careful: it connects with the runtime role, without `CREATE`, and fails).
- `schema_format = :sql`. The Solid databases are populated by *schema load* from `db/*_structure.sql` (they have no migrations folder).
- See Guardrails (§13) for durable operational gotchas (`EDU_MIGRATOR_PASSWORD`, migrating dev vs. test, migration timestamps).

### Code structure — bounded contexts without Packwerk

`app/domains/<domain>/` is an autoload root. Zeitwerk **collapses** `app/domains/*/{models,queries,services,jobs,policies}` (see `config/application.rb`), so the intermediate layer does NOT appear in the constant name:

- `app/domains/core/models/user.rb` → `Core::User` (not `Core::Models::User`).
- `app/domains/identity_access/services/otp/issuer.rb` → `IdentityAccess::Otp::Issuer`.
- `app/domains/core/services/people/resolver.rb` → `Core::People::Resolver`.

Shared component library in `app/views/shared/`; **reused before creating a local one**, and **promoted to `shared/` once a component is used in ≥2 domains**.
The **control plane lives OUTSIDE `app/domains/*`** — its own namespace `app/control_plane/`, mounted at `/control_plane`, with its own layout and real auth (`platform_admins` + MFA, S0).

---

## Domain map

> An **addon = one domain (1:1)**. An institution enables domains by purchasing addons.

### Tier A — base domains (existing)

| Domain | Purpose | Owns / notes |
|---|---|---|
| `core` | Academic spine **+ person identity** | Guardians (`guardian_students`), `academic_terms` (with a "single active term" index — **recon correction**: `students`/enrollment/`disciplinary_logs` do NOT live here, see `group_management`/`schedules`/`student_support`). Owns `Core::User`, `Core::InstitutionUser`, `Core::Session`, `Core::People::Resolver`, and `Core::Headcount::{Snapshotter,SnapshotJob}` (S3a) — identity and the headcount pipe live here, not in `identity_access` nor the control plane. Almost everything FKs to it, including `Schedules::Enrollment.academic_term_id` since v1.15.0 (closes half of the Cav./B2 model). |
| `staff_management` | **Generalized staff (D1, CHECKPOINT E closed)** | `StaffManagement::StaffMember` — employment/engagement of ALL staff (`staff_category` incl. `teaching`), `Department` (`kind` academic/operational, referenced by `role_assignments.scope_department_id`), `EmploymentPeriod` (optional HR depth). `department_id` **nullable** — a non-academic doesn't need an academic department. Foundational (no `Entitlement::Registry`). |
| `teacher_management` | Teachers — **staff specialization (D1)** | `Teacher` is the teaching extension of a `StaffManagement::StaffMember` (`teachers.staff_member_id`, **nullable** FK, additive — a teacher may or may not have the link populated). Owns the exclusively-teaching parts: `teacher_code`, `faculty` (university), `teaching_assignments` (subject). Departments/base profile live in `staff_management`, not here. |
| `group_management` | Groups | `groups` (`kind` homeroom/…), membership/rosters. `students.user_id` and `students.national_id` (encrypted) live in this domain's model (`GroupManagement::Student`). |
| `schedules` | Gradebook (real) **+** schedules/timetabling (Class C, no table) | **Real**: `Subject`/`Enrollment`/`Assessment` (grades, v1.14.0); `Enrollment.academic_term_id` connects to `academic_terms` (v1.15.0 — `Schedules::ActiveTermEnrollmentScope` is the canonical resolver for "enrolled in the active term"). **No real table** (Class C): rooms/meeting patterns — PG18's `WITHOUT OVERLAPS` is design, not implementation. |
| `student_support` | Wellbeing | Conduct/discipline, **medical history (owner)**, accommodations. Sensitive. Legacy `student_guardians` table coexists with `core.guardian_students` (not migrated; see Identity). |
| `cafeteria` | Meals | Checkout with **allergen blocking** (reads `student_support`). Wallet/balance, idempotent transactions. |
| `transportation` | Routes | Routes, stops, boarding check-in/out. Notifies guardians (Turbo Streams/Solid Cable — deferred). |
| `analytics_bi` | Reporting | Materialized views, read models. Cross-tenant reads **only** by the audited role with `BYPASSRLS` (`edu_bi_reader`); never runtime. Still in stub phase. |

### Tier B — identity/roles

| Domain | Purpose |
|---|---|
| `identity_access` | IAM/RBAC **+ onboarding**. Owns the global catalog `roles`/`permissions`/`role_permissions`, `role_assignments` (tenant, scoped by explicit columns), `invitations`, `email_otps`, `audit_events`, the `Otp::*` and `Invitations::*` services, `Audit`, and the `people` controller/views. **Does NOT own** `users`/`institution_users` (they belong to `core`); references them by FK. |

### Tier B-bis — confirmed

| Domain | Purpose |
|---|---|
| `counseling` | Psycho-counseling. **Carve-out of `student_support`.** Cases/files, sessions/notes, referrals, intervention plans. Can *read* (not own) `student_support`'s medical history. **Stricter confidentiality boundary** than conduct. |
| `finance` | Treasury/receivables **within** the tenant (the school charges tuition to guardians). Charges, payments, statements, payment plans. **≠ platform billing.** Tenant-scoped. **Real UI since v1.18.0**: `StudentAccount`/`Charge`/`Payment` (existed since the first commit) now have a supervision surface (mold #4, `finance.read`/`finance.write` — permissions that ALREADY existed and were already reused by `Cafeteria::BalancesController`) and the guardian portal (read-only, same read path — `Finance::AccountStatement`). Money in `decimal(12,2)`, NOT `*_cents bigint` (see Guardrails). `PaymentPlan`/`Installment` (payment plans/installments) still have **no UI**, deferred to their own slice — they don't feed the balance today. |
| `communication` | Communication hub. See §8 (annex). **Both subsystems real**: (A) announcements (v1.19.0, `Communication::Announcement`, org-wide broadcast, RBAC to publish + read by membership); (B) messaging (v1.20.0, `Conversation`/`ConversationParticipant`/`Message`, multi-party, participant `institution_user` **or** `guardian_user` — CHECK exactly-one, four RBAC/participation/audit access paths). Deferrals noted in §8.2 (1:1 fan-out, threading, tags, guardian-initiated). |
| `attendance` | **Daily homeroom attendance (v1.16.0, MVP item #2)** — NET-NEW domain, real from day one (no stub phase). `AttendanceRecord` (`student_id`+`group_id`+`date`, unique `(institution_id, student_id, date)`). Consumes `Schedules::ActiveTermEnrollmentScope` (never re-derives the term join); full mold #4 (per-row `can?`, `authorize!`, nav). Addon-gated. Per-subject deferred. |
| `report_cards` | **Report cards (v1.17.0, MVP item #3)** — NET-NEW domain, addon-gated, reads `schedules` by FK (never owns `Subject`/`Enrollment`/`Assessment`). `ReportCard` (`student_id`+`academic_term_id`, unique `(institution_id, student_id, academic_term_id)`) — snapshot **frozen at publish** (`lines_snapshot` jsonb + `overall_average`, never recomputed when reading a published one). "Draft" is live computation with no row (`ReportCards::Computation`, consumed both by the supervision preview and by `ReportCards::Publisher`). Two surfaces: supervision (mold #4, `report_card.view`/`report_card.publish`) and portal (by relationship, published only, no `authorize!`, outside `Navigation::Registry`). Consumes `Schedules::ActiveTermEnrollmentScope` like `attendance`. Attendance on the report card and the Decreto 1290 scale deferred. |
| `assignments` | **Academic assignments — FULL TRACK, slices 1–4/4 (v1.21.0–v1.26.0, MVP item #6)** — NET-NEW domain, addon-gated, hangs off the `schedules` gradebook by FK (`Assignments::Assignment` → `subject_id`; `schedules::Assessment` gains a nullable, additive `assignment_id`). **The grade lives ONLY in `schedules::Assessment`** — publishing fans out (one `Assessment` row per roster enrollment, `score: nil`, ALWAYS per-student, with or without `group_work`/rubric); grading `UPDATE`s that same row (`Assignments::GradeRecorder`), never a parallel store. Roster = `Schedules::ActiveTermEnrollmentScope` ∩ the subject ∩ the teacher's RBAC scope (via `Subject`'s `grade_level_id`, the same mechanism `grades.write` already used). Supervision (mold #4, `assignment.manage`) + portal (by relationship, `published` only, with the grade read from the same source as `report_cards`). **v1.22.0**: text submission (`Assignments::Submission`, in-domain, NOT anchored to `assessment_id` — submission↔grade pairing via `Assignments::GradingView`), enterable by the student or their guardian (B1) — first portal write, gated by relationship. **v1.23.0**: per-assignment `group_work` toggle (locked after publish); `Submission` generalized to student **XOR** `SubmissionGroup` (real CHECK, `conversation_participants` v1.20.0 pattern); per-assignment groups (`GroupMembership`, a student in ≤1); group grade = per-student bulk-set (`GroupGrader`) + individual override, no group store; shared submission editable by any member with no explicit `group_id`. **v1.24.0**: submission attachments (docx/pdf/jpg/png, ≤10MB, ≤5) over an existing `Submission` — tenant-scoped bridge table `Assignments::SubmissionAttachment` (RLS `ENABLE+FORCE`; the raw Active Storage tables NEVER carry RLS, see `guidelines/OPEN_PROCESS.md`); real content-type via Marcel in a service object (`AttachmentAdder`); three service controllers, never Active Storage's signed routes. **v1.25.0**: teacher materials (`Assignments::Material`, same bridge-table mold, `Assignment` owner) — write gated by RBAC (`assignment.manage`, 403 without permission), not by relationship; portal read WITH NO CHANGES (`StudentView`/`GuardianScope`), a draft/archived one is unreachable for free; `Assignments::AttachmentTypeCheck` (new) shares type/size validation with `AttachmentAdder`. **v1.26.0 — CLOSES THE TRACK**: rubrics — normalized reusable library (`RubricTemplate`/`RubricCriterion`/`RubricLevel`/`RubricCellDescriptor`) associated via `evaluation_method` (`direct`/`rubric`, same `group_work` freeze); structure frozen as a jsonb snapshot at publish (`price_tiers_snapshot`/`lines_snapshot` mold); `Assignments::RubricScore` computes, `RubricGrader`/`GroupRubricGrader` persist the evaluation (`RubricEvaluation`, student XOR group) and write the grade via `GradeRecorder`/`GroupGrader` WITH NO CHANGES — the rubric NEVER stores the grade; the portal shows level + descriptor per criterion (`StudentView.rubric_breakdown_for`), no RBAC. See `guidelines/HISTORIA.md` v1.21.0–v1.26.0. |

### Tier C — candidates

`admissions` (applicant→enrolled pipeline) · `library`. (`staff_management` is NO LONGER a candidate —
CHECKPOINT E closed v1.12.0, see §10/`guidelines/HISTORIA.md`: it exists and resolves generalized staff from
the repo's first commit.)

### Dependency order (creation / migrations)

1. `core`, `staff_management`, `teacher_management` (teaching extension of `staff_management`), `group_management` (provide scope targets).
2. `identity_access` (references the above by FK).
3. `schedules`, `student_support`, `cafeteria`, `transportation`, `analytics_bi`.
4. `counseling` and `finance` (FK to `core`; `counseling` can read `student_support`).
5. `communication` (FK to `core` and `identity_access`; consumes notifications from the rest).
6. Tier C, as confirmed.

---

## QA credentials — role-based visual sweep

Generated by `bin/rails qa:seed_role_logins` (re-runnable, idempotent).
Institution: **Colegio San José** (`colegio-san-jose`), with the ~1,500
students/grades/teachers already seeded by `db/seeds.rb` — these credentials
attach to real data, not to an isolated fixture.

**Local URL (institution):** http://colegio-san-jose.lvh.me:3000
(`lvh.me` resolves via public DNS to 127.0.0.1, so there's no need to touch `/etc/hosts`).

**Local URL (super-admin):** http://localhost:3000/control_plane

### Login flow (two steps, mandatory for ALL roles)

1. Sign in with the email + password from the table.
2. The app will request a 6-digit OTP code by email. Email delivery is **not**
   configured in development (it's silently discarded), so in another terminal run:

   ```
   bin/rails "qa:otp[<email>]"
   ```

   and paste the printed code before it expires (10 minutes).

| Role | Email | Password | Notes |
|---|---|---|---|
| Institution administrator | `institution_admin@colegio-san-jose.test` | `EduPlatformQA2026!` | Real RBAC assignment (roles.manage, staff.read, staff.write, finance.read, finance.write). |
| Teacher | `teacher@colegio-san-jose.test` | `EduPlatformQA2026!` | Real RBAC assignment (grades.read, grades.write, schedule.view, students.read). |
| Group director | `group_director@colegio-san-jose.test` | `EduPlatformQA2026!` | Real RBAC assignment (students.read, grades.read, grades.write, counseling.read, groups.view, groups.manage). |
| Area head | `area_head@colegio-san-jose.test` | `EduPlatformQA2026!` | Real RBAC assignment (teachers.view, teacher.evaluate, departments.view, staff.read, students.read). |
| Counselor | `counselor@colegio-san-jose.test` | `EduPlatformQA2026!` | Real RBAC assignment (counseling.read, medical_history.view_summary, accommodations.view, disciplinary_logs.manage, support_dashboard.view). |
| Student | `student@colegio-san-jose.test` | `EduPlatformQA2026!` | Nicolás Romero López (CSJ-2026-0004), 2 legacy tutor(s) + real grades/enrollments. |
| Guardian | `guardian@colegio-san-jose.test` | `EduPlatformQA2026!` | Linked (Core::GuardianStudent) to Nicolás Romero López. |
| Platform admin (super-admin) | `platform_admin@edu_platform.test` | `EduPlatformQA2026!` | Separate plane — sign in via /control_plane, not via the institution subdomain. |

### Notes

- RBAC is real: every staff role has an `IdentityAccess::Role` row +
  `RoleAssignment` + associated permissions (these are not filler UI data).
  `institution_users.role` (legacy column) is left at its default
  `"member"` — it does not participate in the real authorization.
- The student and the guardian were attached to an ALREADY-seeded student
  (with enrollments, mid-semester grades, and real legacy tutors), so the
  visual sweep sees end-to-end data from a complete school.
- `platform_admin` lives on a separate plane (`ControlPlane::PlatformAdmin`,
  table `platform_admins`) — it uses its own login and OTP at `/control_plane`,
  not the institution subdomain.