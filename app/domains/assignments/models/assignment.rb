module Assignments
  # A TEMPLATE, not a grade store. Publishing (Assignments::Publisher) fans
  # out one Schedules::Assessment per enrolled student REGARDLESS of
  # group_work — a group grade (Assignments::GroupGrader, v1.23.0) is a
  # bulk-set over those SAME per-student rows, never a second grade store.
  # Archiving is SOFT (status), same as retracting an announcement — an
  # assignment's fanned-out grades survive regardless of its own status.
  # Only a draft (zero fanned-out assessments by construction) may ever be
  # hard-deleted.
  class Assignment < ApplicationRecord
    self.table_name = "assignments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :subject, class_name: "Schedules::Subject"
    belongs_to :created_by_institution_user, class_name: "Core::InstitutionUser", optional: true
    has_many :assessments, class_name: "Schedules::Assessment",
      foreign_key: :assignment_id, inverse_of: :assignment, dependent: :nullify
    has_many :submission_groups, class_name: "Assignments::SubmissionGroup",
      foreign_key: :assignment_id, inverse_of: :assignment, dependent: :destroy
    has_many :materials, class_name: "Assignments::Material",
      foreign_key: :assignment_id, inverse_of: :assignment, dependent: :destroy
    belongs_to :rubric_template, class_name: "Assignments::RubricTemplate", optional: true
    has_many :rubric_evaluations, class_name: "Assignments::RubricEvaluation",
      foreign_key: :assignment_id, inverse_of: :assignment, dependent: :destroy

    validates :title, :due_date, presence: true
    validates :status, inclusion: { in: %w[draft published archived] }
    validates :evaluation_method, inclusion: { in: %w[direct rubric] }

    # group_work is settable while draft; once the roster is fanned out and
    # groups may already exist, it's locked — silently discards any attempt
    # to change it, regardless of which action path tried (defense in depth,
    # not just a controller-side omission).
    before_validation :lock_group_work_after_publish, on: :update
    # Same freeze discipline (v1.26.0): evaluation_method/rubric_template_id
    # are only ever meaningful while draft — once published, rubric_snapshot
    # (frozen by Assignments::Publisher) is the only thing anyone reads.
    before_validation :lock_evaluation_method_after_publish, on: :update

    scope :published, -> { where(status: "published") }

    def draft? = status == "draft"
    def published? = status == "published"
    def archived? = status == "archived"
    def group_work? = group_work
    def direct? = evaluation_method == "direct"
    def rubric? = evaluation_method == "rubric"

    private

    def lock_group_work_after_publish
      self.group_work = group_work_was unless draft?
    end

    def lock_evaluation_method_after_publish
      return if draft?

      self.evaluation_method = evaluation_method_was
      self.rubric_template_id = rubric_template_id_was
    end
  end
end
