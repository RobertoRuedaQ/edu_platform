class CreateAdmissions < ActiveRecord::Migration[8.1]
  # guidelines/library_prompt.md — Increment 2 of Fase D greenfield (Increment
  # 1, `library`, closed v1.54.0). Base admissions pipeline: campaign ->
  # applicant -> application -> (accepted) real GroupManagement::Student.
  #
  # Two corrections to the original overview, verified against the real repo
  # before building (el repo manda sobre el plan):
  #
  # 1) The overview named `Schedules::Enrollment.find_or_create_by!` for the
  #    acceptance step — wrong primitive. `Schedules::Enrollment` is SUBJECT
  #    (course) enrollment for grading, `belongs_to :subject` required, and
  #    has nothing to do with admitting a new student into the school. The
  #    real primitive already exists: `Core::RosterImport::Strategies::
  #    Students#create_student!` (GroupManagement::Student.create! directly).
  #    Admissions::AcceptanceConverter reuses that exact shape.
  # 2) An applicant is NOT chargeable via Finance until accepted —
  #    Finance::StudentAccount/Charge require an existing `student_id` (NOT
  #    NULL, on_delete: :restrict), no "prospective payer" precedent anywhere
  #    in this codebase. Confirmed with the owner: the application fee is
  #    only a snapshot (`fee_cents`) on the application row; the REAL
  #    Finance::Charge is created by AcceptanceConverter once Student +
  #    StudentAccount exist. A backlog item (OPEN_PROCESS.md) tracks that
  #    `finance` still needs its own design pass to actually PROCESS/approve
  #    these payments — not built here.
  #
  # An applicant never touches Core::User/Core::InstitutionUser (plain-text
  # guardian contact fields only) until Admissions::AcceptanceConverter runs
  # Core::People::Resolver — no membership/login is created for a family that
  # might never be accepted.
  def change
    create_table :admission_campaigns, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.integer :target_entry_year, null: false
      t.date :opens_on, null: false
      t.date :closes_on, null: false
      t.string :status, null: false, default: "draft"
      t.bigint :application_fee_cents, null: false, default: 0
      t.timestamps
    end
    add_index :admission_campaigns, %i[institution_id status]
    add_check_constraint :admission_campaigns, "status IN ('draft','open','closed')",
      name: "admission_campaigns_status_check"
    enable_rls :admission_campaigns

    create_table :admission_applicants, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :gender, null: false
      t.date :birthdate, null: false
      t.string :guardian_name, null: false
      t.string :guardian_email, null: false
      t.string :guardian_phone
      t.timestamps
    end
    add_index :admission_applicants, %i[institution_id last_name]
    add_check_constraint :admission_applicants, "gender IN ('male','female')",
      name: "admission_applicants_gender_check"
    enable_rls :admission_applicants

    create_table :admission_applications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :campaign, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :admission_campaigns, on_delete: :restrict }
      t.references :applicant, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :admission_applicants, on_delete: :restrict }
      t.references :target_grade_level, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :grade_levels, on_delete: :restrict }
      t.string :status, null: false, default: "submitted"
      t.bigint :fee_cents, null: false, default: 0
      t.datetime :submitted_at, null: false
      t.datetime :decided_at
      t.references :decided_by_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      t.references :converted_student, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :students, on_delete: :restrict }
      t.string :idempotency_key
      t.timestamps
    end
    add_index :admission_applications, %i[institution_id applicant_id campaign_id], unique: true,
      name: "idx_admission_applications_applicant_campaign_unique"
    add_index :admission_applications, %i[institution_id idempotency_key], unique: true,
      name: "idx_admission_applications_idempotency"
    add_index :admission_applications, %i[institution_id status]
    add_index :admission_applications, %i[institution_id target_grade_level_id]
    add_index :admission_applications, :converted_student_id, unique: true, where: "converted_student_id IS NOT NULL",
      name: "idx_admission_applications_converted_student_unique"
    add_check_constraint :admission_applications,
      "status IN ('submitted','under_review','accepted','rejected','withdrawn')",
      name: "admission_applications_status_check"
    enable_rls :admission_applications

    # Bridge table molde exacto Assignments::SubmissionAttachment — RLS
    # ENABLE+FORCE SOLO aquí, nunca en las tablas propias de Active Storage.
    create_table :admission_documents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :application, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :admission_applications, on_delete: :cascade }
      t.references :uploaded_by_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }
      t.string :document_type, null: false
      t.timestamps
    end
    add_index :admission_documents, %i[institution_id application_id],
      name: "idx_admission_documents_on_institution_application"
    enable_rls :admission_documents
  end
end
