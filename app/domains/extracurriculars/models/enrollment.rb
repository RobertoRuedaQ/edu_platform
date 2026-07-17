module Extracurriculars
  # La inscripción de un estudiante en una actividad (tabla activity_enrollments).
  # SUAVE: nunca se destruye — status active/withdrawn + timestamps, misma
  # disciplina append que Communication::Announcement#retract!/attendance/
  # submissions. enrolled_via responde "inscribió el acudiente vs el colegio";
  # enrolled_by_user es el humano que actuó (Core::User, sirve para staff Y
  # acudiente) — ATRIBUCIÓN, nunca una frontera de escritura (mismo criterio
  # que Submission#submitted_by_user_id). El respaldo de BD contra la doble
  # inscripción activa es el índice único parcial (status='active'); el cupo se
  # hace cumplir con lock en Extracurriculars::EnrollmentCreator.
  class Enrollment < ApplicationRecord
    self.table_name = "activity_enrollments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :activity, class_name: "Extracurriculars::Activity"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :enrolled_by_user, class_name: "Core::User", optional: true

    STATUSES = %w[active withdrawn].freeze
    VIAS = %w[staff guardian].freeze

    validates :status, inclusion: { in: STATUSES }
    validates :enrolled_via, inclusion: { in: VIAS }
    validates :enrolled_at, presence: true

    scope :active, -> { where(status: "active") }

    def active?    = status == "active"
    def withdrawn? = status == "withdrawn"
  end
end
