module Admissions
  # A REAL mutable per-row instance of a StepTemplate for one application
  # (guidelines/library_prompt.md, Increment 3) — deliberately NOT a jsonb
  # snapshot (molde rubrics/character-framework instance data), because a
  # step's status/private_notes/evaluator changes over the life of the
  # application; a frozen snapshot can't represent that.
  #
  # `private_notes`/`evaluator` are STAFF-ONLY — Admissions::Tracker::
  # PublicView never touches this model directly (allowlist Data object,
  # molde AnalyticsBi::Lens::AuraScope), so these two fields can never leak
  # onto the public tracker through a future view mistake.
  class ApplicationStep < ApplicationRecord
    self.table_name = "admission_application_steps"

    STATUSES = %w[pending in_progress completed skipped].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :application, class_name: "Admissions::Application", inverse_of: :application_steps
    belongs_to :step_template, class_name: "Admissions::StepTemplate", inverse_of: :application_steps
    belongs_to :evaluator, class_name: "Core::InstitutionUser",
      foreign_key: :evaluator_institution_user_id, optional: true

    validates :status, inclusion: { in: STATUSES }

    before_save :stamp_completed_at

    private

    def stamp_completed_at
      return unless status_changed?

      self.completed_at = status == "completed" ? Time.current : nil
    end
  end
end
