class LinkTeachersToStaffMembers < ActiveRecord::Migration[8.1]
  # D1 additive link: a teacher is a staff_member with a teaching extension.
  # Nullable + ON DELETE SET NULL so existing (seeded) teacher rows are untouched
  # and no backfill is forced now. teaching_assignments are NOT re-pointed here.
  def change
    add_reference :teachers, :staff_member, type: :uuid, null: true, index: true,
                  foreign_key: { on_delete: :nullify }
  end
end
