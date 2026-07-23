class AddStepsAndTrackerToAdmissions < ActiveRecord::Migration[8.1]
  # guidelines/library_prompt.md — Increment 3 of Fase D greenfield (Increment
  # 2, base pipeline, closed v1.55.0). Configurable per-campaign steps +
  # public applicant tracker by token (molde `invitations.token_digest`: only
  # the digest is ever persisted, the raw token never touches the DB).
  #
  # `admission_application_steps` are REAL mutable rows, never a jsonb
  # snapshot (unlike rubrics/character-framework instance data) — a step's
  # status/private_notes/evaluator changes over the life of the application,
  # which a frozen snapshot can't represent.
  def change
    create_table :admission_step_templates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :campaign, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :admission_campaigns, on_delete: :cascade }
      t.string :name, null: false
      t.integer :position, null: false
      t.text :description
      t.timestamps
    end
    add_index :admission_step_templates, %i[institution_id campaign_id position], unique: true,
      name: "idx_admission_step_templates_campaign_position_unique"
    enable_rls :admission_step_templates

    create_table :admission_application_steps, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :application, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :admission_applications, on_delete: :cascade }
      t.references :step_template, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :admission_step_templates, on_delete: :restrict }
      t.string :status, null: false, default: "pending"
      t.text :private_notes
      t.references :evaluator_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.datetime :completed_at
      t.timestamps
    end
    add_index :admission_application_steps, %i[institution_id application_id step_template_id], unique: true,
      name: "idx_admission_application_steps_app_template_unique"
    add_check_constraint :admission_application_steps,
      "status IN ('pending','in_progress','completed','skipped')",
      name: "admission_application_steps_status_check"
    enable_rls :admission_application_steps

    add_column :admission_applications, :tracker_token_digest, :string
    add_index :admission_applications, :tracker_token_digest, unique: true,
      where: "tracker_token_digest IS NOT NULL", name: "idx_admission_applications_tracker_token_digest"
  end
end
