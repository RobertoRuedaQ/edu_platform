module Admissions
  # One applicant's attempt at one campaign (guidelines/library_prompt.md,
  # Increment 2). Written by Admissions::ApplicationSubmitter (submit) and
  # Admissions::AcceptanceConverter (accept) ONLY — status transitions
  # under_review/rejected/withdrawn are plain updates from the controller
  # (molde Cafeteria::MenuController: no query object, authorize! is the
  # only gate).
  #
  # `fee_cents` is a SNAPSHOT of campaign.application_fee_cents at submit
  # time — the real Finance::Charge is created by AcceptanceConverter only
  # once a real GroupManagement::Student/StudentAccount exist (an applicant
  # is not chargeable via Finance before that). `converted_student_id`
  # doubles as the idempotency anchor for acceptance: once set, a retried
  # AcceptanceConverter call is a no-op read, never a second Student/Charge.
  class Application < ApplicationRecord
    self.table_name = "admission_applications"

    STATUSES = %w[submitted under_review accepted rejected withdrawn].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :campaign, class_name: "Admissions::Campaign", inverse_of: :applications
    belongs_to :applicant, class_name: "Admissions::Applicant", inverse_of: :applications
    belongs_to :target_grade_level, class_name: "GroupManagement::GradeLevel"
    belongs_to :decided_by, class_name: "Core::InstitutionUser",
      foreign_key: :decided_by_institution_user_id, optional: true
    belongs_to :converted_student, class_name: "GroupManagement::Student", optional: true
    has_many :documents, class_name: "Admissions::Document", inverse_of: :application,
      dependent: :destroy
    has_many :application_steps, class_name: "Admissions::ApplicationStep", inverse_of: :application,
      dependent: :destroy

    validates :status, inclusion: { in: STATUSES }
    validates :submitted_at, presence: true

    scope :open_for_review, -> { where(status: %w[submitted under_review]) }

    # Scope RBAC alias — molde Transportation::Route#route_id. Habilita el
    # scope :grade_level ya real en el motor (role_assignments.
    # scope_grade_level_id / PermissionCheck#scope_type_for /
    # Authorization::Assignment::SCOPE_READERS[:grade_level]) sin ninguna
    # migración al motor de RBAC.
    def grade_level_id
      target_grade_level_id
    end

    # EL único puente cents (F6) -> decimal, molde Extracurriculars::Activity#fee_amount.
    def fee_amount
      return nil if fee_cents.zero?

      BigDecimal(fee_cents) / 100
    end
  end
end
