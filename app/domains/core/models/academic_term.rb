module Core
  # Shared academic-calendar term for a tenant, e.g. "2026-1". At most one
  # active term per institution (enforced by a partial unique index in the DB).
  class AcademicTerm < ApplicationRecord
    self.table_name = "academic_terms"

    belongs_to :institution, class_name: "Core::Institution"

    scope :active, -> { where(status: "active") }
  end
end
