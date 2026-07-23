module Admissions
  # A configurable step in a campaign's pipeline (guidelines/library_prompt.md,
  # Increment 3) — e.g. "Revisión de documentos", "Entrevista", "Examen de
  # admisión". Config only, never mutated per-application; the per-application
  # instance state lives in Admissions::ApplicationStep.
  class StepTemplate < ApplicationRecord
    self.table_name = "admission_step_templates"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :campaign, class_name: "Admissions::Campaign", inverse_of: :step_templates
    has_many :application_steps, class_name: "Admissions::ApplicationStep", inverse_of: :step_template,
      dependent: :restrict_with_exception

    validates :name, :position, presence: true
  end
end
