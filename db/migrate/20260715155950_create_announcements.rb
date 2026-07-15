class CreateAnnouncements < ActiveRecord::Migration[8.1]
  # communication (v1.19.0, item #5 of the MVP critical path) — subsystem (A)
  # only: announcements (one-way broadcast). A dedicated table, deliberately
  # NOT the unified `conversations` model (messaging is subsystem (B), its
  # own future slice with its own fresh design — see HISTORIA.md v1.19.0's
  # messaging spec annex). No recipient/read-state/targeting/attachment
  # columns: an announcement is org-wide within the tenant, read by
  # membership, not per-person (see the app-level guardrail).
  def change
    create_table :announcements, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # Nullable + nullify, same convention as audit_events.actor_institution_
      # user_id: keep the announcement if the author's membership is later
      # removed. institution_user (not staff_member) because publishing is an
      # administrative action available to anyone with the permission, not
      # specifically a teaching-staff extension (unlike ReportCard's
      # published_by_staff_member_id).
      t.references :author_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }
      t.string :title, null: false
      t.text   :body, null: false
      t.string :status, null: false, default: "published"
      t.datetime :published_at, null: false
      t.datetime :retracted_at

      t.timestamps
    end

    add_index :announcements, %i[institution_id published_at], name: "index_announcements_on_institution_and_published_at"

    add_check_constraint :announcements, "status IN ('published','retracted')", name: "announcements_status_check"

    enable_rls :announcements
  end
end
