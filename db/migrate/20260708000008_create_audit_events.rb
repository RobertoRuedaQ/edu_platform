class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # Nullable: system/job-driven events have no human actor. Keep the event
      # if the actor's membership is later removed.
      t.references :actor_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }

      t.string :action, null: false           # greppable dotted, e.g. "invitation.sent"
      t.string :target_type
      t.uuid   :target_id
      t.jsonb  :metadata, null: false, default: {}
      t.string :ip

      # Append-only: created_at ONLY, no updated_at. DB default so every insert
      # is stamped even when the writer does not set it.
      t.datetime :created_at, null: false, default: -> { "now()" }
    end

    add_index :audit_events, %i[institution_id action],
      name: "index_audit_events_on_institution_and_action"
    add_index :audit_events, %i[institution_id target_type target_id],
      name: "index_audit_events_on_institution_and_target"

    enable_rls :audit_events

    # DB backstop for append-only. The ALTER DEFAULT PRIVILEGES in db:roles auto-
    # grants all four DML verbs on new migrator-owned tables to edu_app_runtime;
    # here we revoke the two that must never touch history. Runtime keeps
    # INSERT/SELECT only. Re-grant on the way down so the drop is clean.
    reversible do |dir|
      dir.up   { execute "REVOKE UPDATE, DELETE ON audit_events FROM edu_app_runtime" }
      dir.down { execute "GRANT UPDATE, DELETE ON audit_events TO edu_app_runtime" }
    end
  end
end
