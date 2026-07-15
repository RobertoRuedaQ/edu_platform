module ReportCards
  # A frozen snapshot of one student's grades for one academic term. Published
  # only — the "draft" state is a live computation with no row (see
  # ReportCards::Computation), so today every persisted row's status is
  # "published". Once persisted, immutable (readonly? = persisted?, same
  # pattern as ControlPlane::InvoiceLineItem): re-publishing the same
  # (student, academic_term) goes through ReportCards::Publisher, which
  # destroys and recreates the row rather than updating it in place — a
  # published report card must NEVER re-read live grades after the fact.
  class ReportCard < ApplicationRecord
    self.table_name = "report_cards"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :published_by_staff_member, class_name: "StaffManagement::StaffMember", optional: true

    validates :status, inclusion: { in: %w[draft published] }
    validates :published_at, presence: true

    def readonly?
      persisted?
    end
  end
end
