class CreateDisciplinaryLogs < ActiveRecord::Migration[8.1]
  # guidelines/CLOSURE_PLAN.md §3.1/Fase B — the "seguimiento disciplinario"
  # process the end-to-end criterion (§1) requires. Molde `counseling` (a
  # sensitive, Class S carve-out): tenant-scoped, RLS FORCE, identity-accountable
  # author, append-only (no update/destroy route exists — a log entry, once
  # written, is permanent; corrections happen by adding a new entry, never
  # editing history). Replaces StudentSupport::DisciplinaryLogRoster, a STUB
  # with hardcoded fake rows and NO real persistence (Controller#create was a
  # literal no-op flashing a fake success message).
  #
  # ENUM DEVIATION (documented, same call as every net-new table this session):
  # `category` is `string` + CHECK, not `smallint`.
  #
  # DELIBERATELY MINIMAL, matching the ALREADY-WIRED routes/permission (no
  # scope expansion): only index+create exist (StudentSupport::
  # DisciplinaryLogsController, gate disciplinary_logs.manage, already in
  # IdentityAccess::SeedPermissions::CATALOG — no new permission needed). No
  # update/destroy/archive — a log is immutable once created, so no `status`
  # column either (unlike care_auras/character_evaluations, there is no
  # lifecycle to track). No guardian/student portal surface — same posture as
  # `counseling` itself, which never exposes raw case notes outside staff RBAC.
  def change
    create_table :disciplinary_logs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      # Identity of the staff member who reported it — RESTRICT, same
      # accountability posture as counseling_cases.opened_by/care_auras.authored_by_counselor.
      t.references :reported_by_institution_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      # attendance/conduct/academic_integrity/other — string + CHECK.
      t.string :category, null: false
      t.text   :description, null: false
      t.date   :occurred_at, null: false

      t.timestamps
    end

    add_check_constraint :disciplinary_logs,
      "category IN ('attendance','conduct','academic_integrity','other')",
      name: "disciplinary_logs_category_check"
    # LEADER institution_id (RLS guard) + the shape the roster query filters
    # on: "this student's log, most recent first".
    add_index :disciplinary_logs, %i[institution_id student_id occurred_at],
      name: "idx_disciplinary_logs_on_inst_student_occurred"
    enable_rls :disciplinary_logs
  end
end
