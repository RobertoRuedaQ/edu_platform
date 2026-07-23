module Admissions
  module Tracker
    # Allowlist-por-construcción para el tracker público (guidelines/
    # library_prompt.md, Increment 3), molde exacto AnalyticsBi::Lens::
    # AuraScope (aislamiento clínico, v1.37.0): retorna un Data de campos
    # explícitos, NUNCA el AR record con asociaciones navegables — así
    # `private_notes`/`evaluator_institution_user_id` (Admissions::
    # ApplicationStep) no tienen NINGÚN accessor aquí y no pueden filtrarse
    # por un descuido de vista futuro. El controller público SOLO debe
    # tocar el `Result` que este objeto retorna, nunca `Admissions::Application`
    # directo.
    class PublicView
      StepView = Data.define(:name, :position, :status)
      Result = Data.define(:applicant_name, :campaign_name, :grade_level_name, :status, :steps)

      def self.for(application)
        new(application).call
      end

      def initialize(application)
        @application = application
      end

      def call
        Result.new(
          applicant_name: application.applicant.full_name,
          campaign_name: application.campaign.name,
          grade_level_name: application.target_grade_level.name,
          status: application.status,
          steps: steps
        )
      end

      private

      attr_reader :application

      def steps
        application.application_steps.includes(:step_template)
          .order("admission_step_templates.position")
          .map { |s| StepView.new(name: s.step_template.name, position: s.step_template.position, status: s.status) }
      end
    end
  end
end
