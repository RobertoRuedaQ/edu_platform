class CreateControlPlaneSessions < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL — mirrors Core::Session's shape, but for platform_admins. No RLS,
    # no institution_id: the control plane has no tenant.
    create_table :control_plane_sessions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :platform_admin, type: :uuid, null: false,
        foreign_key: { on_delete: :cascade }

      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
