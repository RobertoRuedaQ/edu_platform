class CreateStudentHeadcountSnapshots < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL — same posture as subscriptions/institution_entitlements (no
    # RLS, no policy, no FORCE). institution_id is a FK to the GLOBAL
    # institutions table, never a tenancy column.
    #
    # BOUNDARY (S3a): this is a number PUSHED by the tenant (via
    # Core::Headcount::Snapshotter, running under the tenant's own GUC), never
    # a live cross-tenant read from the control plane. academic_term_label is
    # a FROZEN text label, deliberately NOT a FK to the tenant-scoped,
    # RLS-protected academic_terms table — the control plane never reaches
    # into a tenant's schema directly.
    create_table :student_headcount_snapshots, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: true,
        foreign_key: { to_table: :institutions, on_delete: :restrict }

      t.date :as_of_date, null: false
      t.integer :headcount, null: false
      t.text :academic_term_label
      t.jsonb :breakdown, null: false, default: {}
      t.text :source, null: false, default: "tenant_push"

      t.timestamps
    end

    add_index :student_headcount_snapshots, %i[institution_id as_of_date], unique: true,
      name: "index_headcount_snapshots_on_institution_and_date"

    add_check_constraint :student_headcount_snapshots, "headcount >= 0",
      name: "student_headcount_snapshots_headcount_check"
  end
end
