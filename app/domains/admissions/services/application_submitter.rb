module Admissions
  # Radica una solicitud (guidelines/library_prompt.md, Increment 2) — molde
  # Finance::ChargeCreator para la idempotencia (check por idempotency_key
  # antes de crear), Schedules::EnrollmentsController#create para el
  # find_or_create_by! (respaldado por el índice único institution+applicant+
  # campaign, previously_new_record? distingue "creado" de "ya existía").
  class ApplicationSubmitter
    def self.call(institution:, applicant:, campaign:, target_grade_level:, idempotency_key: nil)
      new(institution: institution, applicant: applicant, campaign: campaign,
        target_grade_level: target_grade_level, idempotency_key: idempotency_key).call
    end

    def initialize(institution:, applicant:, campaign:, target_grade_level:, idempotency_key:)
      @institution = institution
      @applicant = applicant
      @campaign = campaign
      @target_grade_level = target_grade_level
      @idempotency_key = idempotency_key
    end

    def call
      existing = existing_by_idempotency_key
      return existing if existing

      application = Admissions::Application.find_or_create_by!(
        institution: institution, applicant: applicant, campaign: campaign
      ) do |a|
        a.target_grade_level = target_grade_level
        a.status = "submitted"
        a.fee_cents = campaign.application_fee_cents
        a.submitted_at = Time.current
        a.idempotency_key = idempotency_key
      end
      emit_usage(application) if application.previously_new_record?
      application
    end

    private

    attr_reader :institution, :applicant, :campaign, :target_grade_level, :idempotency_key

    def existing_by_idempotency_key
      return nil if idempotency_key.blank?

      Admissions::Application.find_by(institution_id: institution.id, idempotency_key: idempotency_key)
    end

    # M1: one "solicitudes" unit per NEW real Application — only reached past
    # the idempotency guard/previously_new_record? check, so a resubmit never
    # re-emits. Wired for real from day one, molde library (v1.54.0).
    def emit_usage(application)
      ControlPlane::Usage::Ingest.emit(institution: institution, addon_key: "admissions",
        unit: "solicitudes", occurred_at: application.submitted_at,
        idempotency_key: "admission_application:#{application.id}")
    end
  end
end
