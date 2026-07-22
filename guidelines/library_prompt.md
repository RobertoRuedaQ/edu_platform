Fase D greenfield: admissions + library (guidelines/library_prompt.md)

 Context

 guidelines/OPEN_PROCESS.md #1 gated admissions/library behind "crear SOLO bajo
 confirmación
 explícita" — no existing stub, no spec to infer business rules from, unlike every
 other Fase D
 increment this session (cafeteria/transportation/schedules all converted an existing
 stub). The user
 provided guidelines/library_prompt.md, a full functional spec for both domains, and
 asked to start
 executing it — that is the explicit confirmation the gate was waiting for.

 Given the size (two full greenfield domains: catalog+checkout with real concurrency
 control, plus a
 dynamic-workflow admissions pipeline with a public tracker), this follows the same
 "una pieza a la
 vez" driver-based method already proven for Fase D (cafeteria alérgenos → resto,
 transportation,
 schedules — each its own commit + doc close). This plan covers Increment 1 (library)
 in full
 executable detail. Increments 2–3 (admissions) are sequenced at overview level and
 will get their
 own design pass when reached, not built blind now.

 Corrections to the spec (verified against the real repo, not assumptions)

 1. Core::Person does not exist anywhere in this codebase — confirmed by exhaustive
 grep (only
 appears inside the spec itself). The real global identity model is Core::User
 (guidelines/PROJECT_STATE.md §3.2: "Una persona = un users"). Every reference in the
 spec to
 Core::Person is designed against Core::User/Core::InstitutionUser instead.
 2. The public applicant portal (/admisiones/solicitud/:token, Increment 3) cannot be
 tenant-agnostic. Every controller in this app — including the three that already allow
 unauthenticated access (InvitationsController, SessionsController,
 EmailOtpsController) —
 still depends on TenantScoped resolving the institution by subdomain first; there is
 no
 token-encodes-institution mechanism anywhere, and Invitations::Issuer's own docstring
 is
 explicit about deliberately avoiding one. The applicant link stays subdomain-scoped
 (https://{slug}.dominio/admisiones/solicitud/:token), same as invitations — token
 generation
 reuses Invitations::Issuer's exact pattern (SecureRandom.urlsafe_base64(32), only the
 Digest::SHA256 digest ever persisted). Deferred to Increment 3 design.
 3. Library's "borrower" is under-specified in the spec — it names only
 borrower_institution_user_id, but the spec's own UX section requires students to see
 their
 own borrowed books in a self-service portal, and students are GroupManagement::Student
 rows,
 never Core::InstitutionUser. Fixed with the exact XOR molde this codebase already uses
 for the
 same shape (Communication::ConversationParticipant: two nullable FKs + a
 num_nonnulls(...) = 1
 CHECK, model-level mirror validation) — never a true polymorphic association.

 Increment 1: library — full design

 Schema (new migration, timestamp > 20260722070000)

 Three tables, all id: :uuid, default: -> { "uuidv7()" }, all RLS ENABLE+FORCE:

 library_resources (catalog/title): institution_id (FK cascade), title (not null),
 author,
 publisher, isbn, dewey_category. Partial unique index (institution_id, isbn) WHERE
 isbn IS NOT NULL — not every resource has one.

 library_resource_copies (physical unit): institution_id (FK cascade), resource_id (FK
 restrict — copies are never destroyed, only status-transitioned, so this never
 actually fires),
 barcode (not null, unique per institution), status (available|loaned|maintenance|lost,
 CHECK).
 No destroy action built this increment.

 library_loans (transaction): institution_id (FK cascade), copy_id (FK restrict — loans
 are
 an audit trail, molde cafeteria_purchases), borrower_institution_user_id (nullable, FK
 restrict)
 XOR borrower_student_id (nullable, FK restrict) with CHECK
 num_nonnulls(borrower_institution_user_id, borrower_student_id) = 1 (molde
 conversation_participants), issued_by_institution_user_id (NOT NULL, FK restrict — any
 staff can
 work the desk, molde boarding_events.recorded_by/cafeteria_purchases.recorded_by),
 borrowed_at/
 due_at/returned_at (datetime), status (active|returned|overdue|lost, CHECK —
 overdue/lost
 values reserved for forward-compat, nothing sets them this increment, no sweep job
 built), and an
 idempotency_key (string) + unique index (institution_id, idempotency_key) — same
 double-submit
 protection every other transactional service in this codebase has
 (ChargeCreator/PurchaseRecorder).
 Partial unique index (institution_id, copy_id) WHERE status = 'active' is the DB-level
 backstop
 against double-lending (molde activity_enrollments' partial unique index).

 Services — app/domains/library/services/

 Library::LoanRecorder.call(institution:, copy:, borrower:, issued_by:, due_at:,
 idempotency_key:)
 — borrower: accepts either a GroupManagement::Student or a Core::InstitutionUser; the
 service
 picks the right FK column by class. Inside Library::ResourceCopy.transaction do;
 copy.lock!; ...; end:
 1. Idempotency check first, inside the lock (by idempotency_key) — return existing
 loan if found,
 same order as Finance::ChargeCreator.
 2. raise NotAvailable unless copy.status == "available".
 3. Borrow-limit check — MAX_ACTIVE_LOANS_STUDENT = 3, MAX_ACTIVE_LOANS_STAFF = 5
 (PLACEHOLDER, no settings-per-institution mechanism exists — same posture as
 HEAT_RISK_THRESHOLD/RowPurger::RETENTION; spec explicitly says "por rol de usuario" so
 this is
 split, not flat).
 4. Create the Loan, flip copy.status = "loaned", emit M1 usage (unit: "préstamos",
 idempotency_key: "library_loan:#{loan.id}", past the idempotency guard so a resubmit
 never
 double-counts).

 Library::ReturnRecorder.call(institution:, loan:, returned_at: Time.current) — locks
 copy,
 not loan (the race that matters is cross-loan interleaving on the same copy, not two
 concurrent
 returns of the same loan row — locking copy is what every writer of loan.status must
 hold, so a
 fresh loan.reload after the lock is guaranteed non-stale). Idempotent short-circuit if
 already
 returned. Sets returned_at/status: "returned", flips copy.status = "available".
 Overdue fines deliberately deferred — the spec itself says fines are conditional
 ("si tiene configurada esa regla") and no settings mechanism exists to configure them;
 inventing a
 fee policy with zero business input would contradict this project's own repeated
 discipline
 (billing hardening items are gated the same way). Loan#overdue? = status == "active"
 && due_at < Time.current is a computed predicate for UI badges, never persisted.

 Query objects

 Library::LoanScope (molde Cafeteria::AccountScope) — institution-wide,
 .where(institution_id:)
 - eager-load copy: :resource and both borrower associations, .select {
 context.can?("library.loans.manage", loan) }.
 Library::ResourcesController#index/Library::ResourceCopiesController need
 no query object (molde MenuController: institution-wide, nothing to filter per row —
 authorize! alone is the gate).

 Controllers & routes

 namespace :library do
   resources :resources, only: %i[index new create edit update] do
     resources :copies, only: %i[index new create update], controller:
 "resource_copies"
   end
   resources :checkouts, only: %i[new create]   # library.checkout — one-step desk
 lending
   resources :returns,   only: :create          # library.checkout
   resources :loans,     only: :index           # library.loans.manage —
 history/reports
 end
 Portals (molde guardian_finance/student_attendance — relation-gated, no authorize!):
 resource :student, ... do
   resource :library, only: :show, controller: "student_library"
 end
 resource :guardian, ... do
   resources :students, ... do
     resource :library, only: :show, controller: "guardian_library"
   end
 end
 Portals::StudentLibraryController#show: @student =
 Core::Access::StudentSelfScope.for(Current.user),
 @loans = that student's loans, @catalog = available resources (institution-wide read,
 spec asks
 for catalog browsing too, not just "my loans").
 Portals::GuardianLibraryController#show mirrors
 GuardianFinanceController (per-child,
 Core::Access::GuardianScope.for(Current.user).find(params[:student_id])).

 Permissions (new keys — confirmed no existing key is reusable)

 library.catalog.manage, library.loans.manage, library.checkout — added to
 IdentityAccess::SeedPermissions::CATALOG.

 Addon/nav/metering wiring

 - ControlPlane::AddonCatalog::DOMAIN_KEYS += "library".
 - config/entitlements/library.rb: Entitlement::Registry.register("library").
 - config/navigation/library.rb: register domain library, label "Biblioteca", path
 /library/checkout, permission library.checkout (position collisions are tolerated — no
 uniqueness constraint exists in Navigation::Registry, confirmed).
 - ControlPlane::SeedCatalog::ADDONS += library, metered: true, unit: "préstamos" —
 wired for
 real from day one (no deferred-metering backlog item needed, unlike
 cafeteria/transportation which
 were retrofitted).

 Tests

 - Model tests (test/models/library/): CHECK-bypass tests (status enums, borrower XOR)
 mirroring
 test/models/schedules/room_test.rb/purchase_test.rb; LoanRecorder/ReturnRecorder
 service
 tests — lock behavior, idempotency (resubmit never double-lends), borrow-limit
 enforcement per
 role, partial-unique-index backstop (bypass validation, assert
 ActiveRecord::StatementInvalid).
 - Integration tests (test/integration/library_test.rb): RBAC fail-closed per
 permission, portal
 reads (student sees own loans + catalog, guardian sees only own child's), M1 usage
 emission +
 idempotent resubmit.
     - Integration tests (test/integration/library_test.rb): RBAC fail-closed per
     permission, portal
     reads (student sees own loans + catalog, guardian sees only own child's), M1 usage
     emission +
     idempotent resubmit.
     idempotent resubmit.

     Increment 2 (overview — designed in detail when reached)

     admissions base:
     admission_campaigns/applicants/admission_applications/admission_documents
     (file uploads — molde Assignments::SubmissionAttachment's bridge-table pattern,
     has_one_attached :file, RLS on the bridge only, never on Active Storage's own
     tables, serve via send_data never
     rails_blob_path). Admissions::ApplicationSubmitter (fee charge via
     Finance::ChargeCreator, molde
     extracurriculars). Admissions::AcceptanceConverter (atomic:
     Core::People::Resolver.call +
     Core::GuardianStudent link + Schedules::Enrollment.find_or_create_by!, replicating
     Schedules::EnrollmentsController#create's exact idempotent shape). RBAC scope:
     reuse
     scope_grade_level_id directly — already a real, live column/scope type (confirmed
     consumer:
     calendar), zero migration to the RBAC engine needed; just add an
     AdmissionApplication#grade_level_id
     reader aliasing target_grade_level_id (molde Transportation::Route#route_id).

     Increment 3 (overview — designed in detail when reached)

     admission_step_templates → application_steps: confirmed genuinely novel shape for
     this codebase
     (rubrics/character-framework snapshot into jsonb; this needs real mutable per-row
     instance state, so
     real rows are correct, not a snapshot). Public applicant tracker
     (/admisiones/solicitud/:token,
     layout "auth", subdomain-scoped per correction #2 above) with strict test that
     private_notes/
     evaluator identity are never rendered on the public endpoint (explicit acceptance
     criterion in the
     spec). CSS vanilla stepper, no external library.

     Verification (Increment 1)

     1. bin/migrate + RAILS_ENV=test bin/migrate.
     2. bin/rails test test/models/library/ test/integration/library_test.rb.
     3. PARALLEL_WORKERS=1 bin/rails test — full suite, 0 failures, same preexisting
     skip.
     4. Manual sanity via bin/rails runner: create a copy, call LoanRecorder twice with
     the same
     idempotency_key (assert one loan), call it a third time with a new key while still
     loaned
     (assert NotAvailable), call ReturnRecorder, confirm copy flips back to available.
     5. Close out HISTORIA.md (new version entry), PROJECT_STATE.md (domain map row +
     Tier
     promotion out of Tier C, metadata bump), OPEN_PROCESS.md (strike the greenfield
     item down to
     "library closed, admissions increments 2–3 pending" — molde every prior Fase D
     closure this
     session), CLOSURE_PLAN.md if still relevant to reference. Commit.