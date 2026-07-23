module Admissions
  # Convierte una solicitud aceptada en un GroupManagement::Student real
  # (guidelines/library_prompt.md, Increment 2 — corrigiendo el overview
  # original, que apuntaba a la primitiva equivocada: Schedules::Enrollment
  # es matrícula de MATERIA, no "admitir un estudiante nuevo al colegio").
  #
  # Bloquea `application` (nunca applicant/campaign) — el recurso contendido
  # es "esta solicitud se convierte una sola vez"; `converted_student_id`
  # (seteado al final, dentro del mismo lock) es el ancla de idempotencia:
  # `lock!` recarga la fila, así que un reintento concurrente siempre ve el
  # valor ya escrito por el primero.
  #
  # Tres pasos, molde exacto de servicios ya existentes:
  # 1) GroupManagement::Student.create! — molde Core::RosterImport::
  #    Strategies::Students#create_student! (sin section: asignar sección es
  #    un flujo posterior ya existente, GroupManagement::SectionReassigner,
  #    fuera del alcance de admitir).
  # 2) Core::People::Resolver + Core::GuardianStudent — molde Core::
  #    RosterImport::Strategies::Guardians#commit_row!.
  # 3) Finance::Charge SOLO ahora (un aspirante no es cobrable via Finance
  #    antes de esto — StudentAccount/Charge exigen student_id NOT NULL) —
  #    molde Extracurriculars::EnrollmentCreator#charge_for_paid_activity,
  #    misma transacción. `fee_cents == 0` nunca genera un Charge.
  class AcceptanceConverter
    class NotReviewable < StandardError; end

    def self.call(institution:, application:, student_code:, decided_by:)
      new(institution: institution, application: application, student_code: student_code,
        decided_by: decided_by).call
    end

    def initialize(institution:, application:, student_code:, decided_by:)
      @institution = institution
      @application = application
      @student_code = student_code
      @decided_by = decided_by
    end

    def call
      Admissions::Application.transaction do
        application.lock!
        next application.converted_student if application.converted_student_id.present?

        raise NotReviewable, "la solicitud ya fue decidida" unless application.status.in?(%w[submitted under_review])

        student = create_student!
        link_guardian!(student)
        charge_application_fee!(student) if application.fee_cents.positive?

        application.update!(status: "accepted", decided_at: Time.current, decided_by: decided_by,
          converted_student: student)
        student
      end
    end

    private

    attr_reader :institution, :application, :student_code, :decided_by

    def applicant = application.applicant
    def campaign = application.campaign

    def create_student!
      GroupManagement::Student.create!(
        institution: institution, first_name: applicant.first_name, last_name: applicant.last_name,
        gender: applicant.gender, birthdate: applicant.birthdate, student_code: student_code,
        entry_year: campaign.target_entry_year, grade_level: application.target_grade_level
      )
    end

    def link_guardian!(student)
      resolved = Core::People::Resolver.call(email: applicant.guardian_email, name: applicant.guardian_name,
        institution: institution, role: "guardian")

      Core::GuardianStudent.find_or_create_by!(institution: institution, guardian_user_id: resolved.user.id,
        student_id: student.id) do |l|
        l.relationship = "acudiente"
        l.status = "active"
      end
    end

    def charge_application_fee!(student)
      account = Finance::StudentAccount.find_or_create_by!(
        institution_id: institution.id, student_id: student.id
      ) do |a|
        a.balance = 0
        a.currency = "COP"
      end

      Finance::ChargeCreator.call(
        institution: institution, account: account, amount: application.fee_amount,
        description: "Cuota de admisión: #{campaign.name}",
        idempotency_key: "admission_application:#{application.id}"
      )
    end
  end
end
