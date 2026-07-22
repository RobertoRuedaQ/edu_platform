class CreateLibrary < ActiveRecord::Migration[8.1]
  # guidelines/library_prompt.md — first increment of Fase D greenfield
  # (OPEN_PROCESS.md #1, `admissions`/`library`), confirmed explicitly by the
  # owner. `library` is fully self-contained (no cross-domain seam except an
  # optional fine bridge to `finance`, deferred — see ReturnRecorder).
  #
  # Two decisions correcting the spec against real repo conventions
  # (guidelines/library_prompt.md's own author assumed things not true of
  # this codebase — the repo manda sobre el plan):
  #
  # 1) The spec names only `borrower_institution_user_id`, but its own UX
  #    section requires STUDENTS to see their own loans in a self-service
  #    portal — students are GroupManagement::Student rows, never
  #    Core::InstitutionUser. `borrower_institution_user_id` XOR
  #    `borrower_student_id` (CHECK num_nonnulls = 1) is the exact molde
  #    `conversation_participants` already uses for "the actor is one of two
  #    distinct person-types" — never a true polymorphic association.
  # 2) `idempotency_key` on `library_loans` — the spec never mentions it, but
  #    every other transactional write in this app (ChargeCreator/
  #    PurchaseRecorder) has one; without it a double-submitted "Prestar"
  #    click would surface a scary NotAvailable error on an ordinary
  #    double-click instead of returning the existing loan.
  #
  # Locking discipline: `copy.lock!` (never `loan.lock!`) is the ONE seam
  # both LoanRecorder AND ReturnRecorder take before touching `loan.status`
  # OR `copy.status` — the race that matters is cross-loan interleaving on
  # the SAME copy (a delayed return landing after the copy was re-loaned),
  # not two concurrent operations on one loan row. The partial unique index
  # below (`WHERE status = 'active'`) is the DB-level backstop, same
  # discipline as `activity_enrollments`.
  def change
    create_table :library_resources, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.string :author
      t.string :publisher
      t.string :isbn
      t.string :dewey_category
      t.timestamps
    end
    add_index :library_resources, %i[institution_id isbn], unique: true, where: "isbn IS NOT NULL",
      name: "idx_library_resources_isbn_unique"
    enable_rls :library_resources

    create_table :library_resource_copies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :resource, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :library_resources, on_delete: :restrict }
      t.string :barcode, null: false
      t.string :status, null: false, default: "available"
      t.timestamps
    end
    add_index :library_resource_copies, %i[institution_id barcode], unique: true,
      name: "idx_library_copies_barcode_unique"
    add_index :library_resource_copies, %i[institution_id resource_id]
    add_index :library_resource_copies, %i[institution_id status]
    add_check_constraint :library_resource_copies, "status IN ('available','loaned','maintenance','lost')",
      name: "library_resource_copies_status_check"
    enable_rls :library_resource_copies

    create_table :library_loans, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :copy, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :library_resource_copies, on_delete: :restrict }
      t.references :borrower_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.references :borrower_student, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :students, on_delete: :restrict }
      t.references :issued_by_institution_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.datetime :borrowed_at, null: false
      t.datetime :due_at, null: false
      t.datetime :returned_at
      t.string :status, null: false, default: "active"
      t.string :idempotency_key
      t.timestamps
    end
    add_index :library_loans, %i[institution_id copy_id], unique: true, where: "status = 'active'",
      name: "idx_library_loans_active_unique"
    add_index :library_loans, %i[institution_id copy_id], name: "idx_library_loans_on_institution_copy"
    add_index :library_loans, %i[institution_id borrower_student_id]
    add_index :library_loans, %i[institution_id borrower_institution_user_id]
    add_index :library_loans, %i[institution_id idempotency_key], unique: true,
      name: "idx_library_loans_idempotency"
    add_check_constraint :library_loans, "status IN ('active','returned','overdue','lost')",
      name: "library_loans_status_check"
    add_check_constraint :library_loans,
      "num_nonnulls(borrower_institution_user_id, borrower_student_id) = 1",
      name: "library_loans_borrower_identity_check"
    enable_rls :library_loans
  end
end
