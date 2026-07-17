module Extracurriculars
  # Baja SUAVE de una inscripción: nunca destruye — flip status active->withdrawn
  # + withdrawn_at (misma disciplina append que el resto del repo). Idempotente:
  # si el estudiante ya no tiene inscripción activa en la actividad, no-op.
  #
  # NO revierte el Charge de una actividad paga ya cobrada: "descobrar" al
  # desinscribir es política de tesorería (nota de crédito / ajuste manual),
  # fuera del alcance de este slice — ver HISTORIA.md v1.27.0.
  class EnrollmentWithdrawer
    def self.call(institution:, activity:, student:)
      new(institution: institution, activity: activity, student: student).call
    end

    def initialize(institution:, activity:, student:)
      @institution = institution
      @activity = activity
      @student = student
    end

    def call
      enrollment = Extracurriculars::Enrollment.find_by(
        institution_id: institution.id, activity_id: activity.id,
        student_id: student.id, status: "active"
      )
      return nil if enrollment.nil?

      enrollment.update!(status: "withdrawn", withdrawn_at: Time.current)
      enrollment
    end

    private

    attr_reader :institution, :activity, :student
  end
end
