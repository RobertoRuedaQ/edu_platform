module Core
  # One roster upload (students or guardians) tied to an academic term. The
  # uploaded file rides on ActiveStorage; parsed lines live in RosterImportRow.
  class RosterImportBatch < ApplicationRecord
    self.table_name = "roster_import_batches"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :created_by, class_name: "Core::InstitutionUser", optional: true

    has_one_attached :file

    has_many :roster_import_rows, class_name: "Core::RosterImportRow",
             dependent: :destroy
  end
end
