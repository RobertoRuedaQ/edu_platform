class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    # GLOBAL — a session belongs to a global user. No RLS (allowlisted).
    create_table :sessions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true

      # Which tenant this session is CURRENTLY acting within. Deliberately named
      # current_institution_id, NOT institution_id: this table isn't tenant-owned,
      # so the name both keeps it off the RLS guard and states intent — it's
      # nullable UI/routing state (global requests have none yet).
      t.references :current_institution, type: :uuid, null: true,
                   foreign_key: { to_table: :institutions }

      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
