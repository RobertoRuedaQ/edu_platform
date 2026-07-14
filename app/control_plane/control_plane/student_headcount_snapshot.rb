module ControlPlane
  # GLOBAL — a headcount number PUSHED by the tenant (never a live read of the
  # tenant's own students table from the control plane). institution_id is a
  # plain FK to global `institutions`, never RLS scope.
  #
  # academic_term_label is a frozen text snapshot, deliberately NOT a FK to
  # the tenant-scoped, RLS-protected academic_terms table — see
  # Core::Headcount::Snapshotter for who writes this and how.
  class StudentHeadcountSnapshot < ApplicationRecord
    self.table_name = "student_headcount_snapshots"

    belongs_to :institution, class_name: "Core::Institution"

    validates :as_of_date, presence: true
    validates :headcount, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validates :source, presence: true
    validates :as_of_date, uniqueness: { scope: :institution_id, message: "ya tiene un snapshot para esta institución" }

    scope :for_institution, ->(institution) { where(institution_id: institution.id) }
    scope :most_recent_first, -> { order(as_of_date: :desc) }

    def self.latest_for(institution)
      for_institution(institution).most_recent_first.first
    end
  end
end
