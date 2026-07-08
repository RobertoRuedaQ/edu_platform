class CreateControlPlaneAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL, append-only audit trail for the control plane — its OWN table,
    # never the tenant's audit_events. platform_admin_id is nullable: system/
    # bootstrap events and failed-login attempts with no resolved admin still
    # need a row. No updated_at: rows are never modified.
    create_table :control_plane_audit_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :platform_admin, type: :uuid, null: true, index: false,
        foreign_key: { on_delete: :nullify }

      t.string   :action, null: false
      t.string   :target_type
      t.uuid     :target_id
      t.jsonb    :metadata, null: false, default: {}
      t.string   :ip_address
      t.datetime :created_at, null: false, default: -> { "now()" }
    end

    add_index :control_plane_audit_events, %i[platform_admin_id action],
      name: "index_cp_audit_events_on_platform_admin_and_action"
    add_index :control_plane_audit_events, %i[target_type target_id],
      name: "index_cp_audit_events_on_target"

    # Append-only at the DB role level — same mechanism as the tenant's
    # audit_events (db/migrate/20260708000008_create_audit_events.rb).
    reversible do |dir|
      dir.up   { execute "REVOKE UPDATE, DELETE ON control_plane_audit_events FROM edu_app_runtime" }
      dir.down { execute "GRANT UPDATE, DELETE ON control_plane_audit_events TO edu_app_runtime" }
    end
  end
end
