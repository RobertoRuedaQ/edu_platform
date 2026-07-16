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

    validates :title, :due_date, presence: true
    validates :status, inclusion: { in: %w[draft published archived] }

    # group_work is settable while draft; once the roster is fanned out and
    # groups may already exist, it's locked — silently discards any attempt
    # to change it, regardless of which action path tried (defense in depth,
    # not just a controller-side omission).
    before_validation :lock_group_work_after_publish, on: :update

    scope :published, -> { where(status: "published") }

    def draft? = status == "draft"
    def published? = status == "published"
    def archived? = status == "archived"
    def group_work? = group_work

    private

    def lock_group_work_after_publish
      self.group_work = group_work_was unless draft?
    end
  end
end
