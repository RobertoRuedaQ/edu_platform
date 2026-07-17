module Extracurriculars
  # Una actividad extracurricular (deporte/arte/refuerzo) de un término. El
  # instructor es OPCIONAL (una actividad existe antes de asignarlo) y su
  # relación con el actor es de PROPIEDAD de fila, no de jerarquía de rol —
  # el filtrado "mis actividades" vive en Extracurriculars::ActivityScope por
  # este FK, nunca en Authorization::Assignment#covers?/SCOPE_READERS (ver esa
  # clase). Ciclo de vida draft->published->archived idéntico a assignments:
  # solo published es visible/inscribible en el portal; archived cierra la
  # inscripción preservando el roster (append, nunca destruir).
  class Activity < ApplicationRecord
    self.table_name = "activities"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :instructor_staff_member, class_name: "StaffManagement::StaffMember", optional: true

    has_many :enrollments, class_name: "Extracurriculars::Enrollment",
             foreign_key: :activity_id, inverse_of: :activity, dependent: :destroy

    KINDS = %w[sport art tutoring].freeze
    STATUSES = %w[draft published archived].freeze

    # AR-level para mensajes amables; la garantía REAL es el CHECK de BD (misma
    # doble defensa que attendance/assignments).
    validates :name, presence: true
    validates :kind, inclusion: { in: KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :capacity, numericality: { only_integer: true, greater_than: 0 }

    scope :published, -> { where(status: "published") }

    def draft?     = status == "draft"
    def published? = status == "published"
    def archived?  = status == "archived"

    KIND_LABELS = { "sport" => "Deporte", "art" => "Arte", "tutoring" => "Refuerzo" }.freeze
    STATUS_LABELS = { "draft" => "Borrador", "published" => "Publicada", "archived" => "Archivada" }.freeze

    def kind_label   = KIND_LABELS.fetch(kind, kind)
    def status_label = STATUS_LABELS.fetch(status, status)

    def fee_label
      return "Gratis" if free?

      "$#{format('%.2f', fee_amount)} COP"
    end

    def free?
      fee_cents.nil? || fee_cents.zero?
    end

    def paid? = !free?

    # EL único puente cents (este dominio, F6) -> decimal (la moneda legacy
    # grandfathered de finance). BigDecimal exacto, NUNCA Float — el amount del
    # Charge jamás debe arrastrar drift de punto flotante. Ver el guardrail del
    # puente de dinero en OPEN_PROCESS.md §2.
    def fee_amount
      return nil if free?

      BigDecimal(fee_cents) / 100
    end

    # Inscripciones activas (el roster real). withdrawn queda como historial,
    # nunca se destruye.
    def active_enrollments
      enrollments.where(status: "active")
    end

    def publish!
      update!(status: "published")
    end

    def archive!
      update!(status: "archived")
    end
  end
end
