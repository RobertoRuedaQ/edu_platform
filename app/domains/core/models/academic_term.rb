module Core
  # Shared academic-calendar term for a tenant, e.g. "2026-1". At most one
  # active term per institution (enforced by a partial unique index in the DB,
  # index_academic_terms_one_active_per_institution). Managed by
  # Core::AcademicTermsController (guidelines/CLOSURE_PLAN.md §4.2) — the
  # first staff-facing surface for this model; created via db/seeds.rb/console
  # before that.
  class AcademicTerm < ApplicationRecord
    self.table_name = "academic_terms"

    STATUSES = %w[upcoming active closed].freeze

    belongs_to :institution, class_name: "Core::Institution"

    validates :code, :name, :starts_on, :ends_on, presence: true
    validates :code, uniqueness: { scope: :institution_id }
    validates :status, inclusion: { in: STATUSES }
    validate :ends_on_after_starts_on

    scope :active, -> { where(status: "active") }

    private

    def ends_on_after_starts_on
      return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

      errors.add(:ends_on, "debe ser posterior o igual a la fecha de inicio")
    end
  end
end
