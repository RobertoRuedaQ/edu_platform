class CreateMedicalHistoriesAndAccommodations < ActiveRecord::Migration[8.1]
  # guidelines/CLOSURE_PLAN.md Fase D (second increment, after cafeteria's
  # allergen checkout in v1.47.0). Retires the last two STUB roster services
  # in `student_support`: MedicalHistoryRoster and AccommodationRoster — both
  # hardcoded, fake rows, with `AccommodationsController#update` a literal
  # no-op ("STUB: no persistence yet").
  #
  # THREE net-new tenant-scoped tables:
  #
  # 1) medical_histories — ONE per student (unique index), the "owner" tier
  #    (medical_history.view, medical_staff). conditions/medications are
  #    jsonb string arrays (unstructured free text lists, same posture as
  #    care_auras/character evaluations use jsonb for a frozen structure —
  #    here it's just a flexible list, no snapshot semantics needed).
  #
  # 2) student_allergies — MANY per student, independent of medical_histories
  #    (a school can record an allergy before a full medical history exists).
  #    This is the "narrow" tier (medical_history.view_summary, counselor) —
  #    allergies/contraindications ONLY, never conditions/medications.
  #    severity is stored in ENGLISH from the start (mild/moderate/severe/
  #    anaphylaxis) since this is a fresh table designed to match
  #    shared/_allergen_flag's own vocabulary directly — unlike
  #    Cafeteria::DietaryRestriction (v1.47.0), which had to translate FROM
  #    legacy Spanish seed data because that table already existed.
  #
  # 3) accommodations — one row per accommodation/adaptation. `status`
  #    (active/expired) + `authorized_by_institution_user_id` (identity,
  #    RESTRICT — same accountability posture as disciplinary_logs/
  #    care_auras/character_evaluations authors).
  #
  # ENUM DEVIATION (documented, same call as every net-new table this
  # session): every closed set here is `string` + add_check_constraint, not
  # `smallint`.
  def change
    # --- medical_histories --------------------------------------------------
    create_table :medical_histories, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.string :blood_type
      t.jsonb  :conditions, null: false, default: []
      t.jsonb  :medications, null: false, default: []

      t.timestamps
    end
    # ONE medical history per student (leader institution_id satisfies the
    # RLS guard AND is the 1:1 identity constraint).
    add_index :medical_histories, %i[institution_id student_id],
      unique: true, name: "idx_medical_histories_unique_student"
    enable_rls :medical_histories

    # --- student_allergies ---------------------------------------------------
    create_table :student_allergies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.string :allergen_name, null: false
      t.string :severity, null: false
      t.text   :reaction

      t.timestamps
    end
    add_index :student_allergies, %i[institution_id student_id],
      name: "idx_student_allergies_on_inst_student"
    add_check_constraint :student_allergies,
      "severity IN ('mild','moderate','severe','anaphylaxis')",
      name: "student_allergies_severity_check"
    enable_rls :student_allergies

    # --- accommodations -------------------------------------------------------
    create_table :accommodations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :authorized_by_institution_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      # extra_time/adapted_material/preferential_seating/other — string+CHECK.
      t.string :kind, null: false
      t.text   :description, null: false
      # active/expired — string+CHECK.
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :accommodations, %i[institution_id student_id],
      name: "idx_accommodations_on_inst_student"
    add_check_constraint :accommodations,
      "kind IN ('extra_time','adapted_material','preferential_seating','other')",
      name: "accommodations_kind_check"
    add_check_constraint :accommodations,
      "status IN ('active','expired')",
      name: "accommodations_status_check"
    enable_rls :accommodations
  end
end
