module Assignments
  # A TEMPLATE, not a grade store. Publishing (Assignments::Publisher) fans
  # out one Schedules::Assessment per enrolled student — the grade lives
  # there, never on this row. Archiving is SOFT (status), same as retracting
  # an announcement — an assignment's fanned-out grades survive regardless
  # of its own status. Only a draft (zero fanned-out assessments by
  # construction) may ever be hard-deleted.
  class Assignment < ApplicationRecord
    self.table_name = "assignments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :subject, class_name: "Schedules::Subject"
    belongs_to :created_by_institution_user, class_name: "Core::InstitutionUser", optional: true
    has_many :assessments, class_name: "Schedules::Assessment",
      foreign_key: :assignment_id, inverse_of: :assignment, dependent: :nullify

    validates :title, :due_date, presence: true
    validates :status, inclusion: { in: %w[draft published archived] }

    scope :published, -> { where(status: "published") }

    def draft? = status == "draft"
    def published? = status == "published"
    def archived? = status == "archived"
  end
end
