class AddAcademicTermToEnrollments < ActiveRecord::Migration[8.1]
  # Closes the model half of Cav./B2: "the student enrolled in the active
  # term" becomes a real, joinable fact. Additive only (F2/F3) — the legacy
  # `term` string column is untouched and keeps coexisting, same pattern as
  # guardian_students/student_guardians. Nullable: existing rows (and any
  # enrollment created without a resolvable active term) are a normal state,
  # never backfilled by force.
  def change
    add_reference :enrollments, :academic_term, type: :uuid, null: true, index: false,
      foreign_key: { on_delete: :nullify }

    add_index :enrollments, %i[institution_id academic_term_id],
      name: "index_enrollments_on_institution_and_academic_term"
  end
end
