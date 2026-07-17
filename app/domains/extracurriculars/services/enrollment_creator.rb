module Extracurriculars
  # Inscribe un estudiante en una actividad — transaccional y con lock, misma
  # disciplina que Finance::ChargeCreator/PaymentRecorder (account.lock!).
  #
  # El CUPO es un invariante AGREGADO ("nº de activos < capacity"), no
  # expresable barato como constraint declarativo sin un trigger (y este repo
  # no usa triggers), así que se serializa con activity.lock! y se cuenta
  # dentro del lock. El índice único PARCIAL (status='active') es el respaldo
  # de BD contra la doble inscripción activa concurrente — el índice no corre
  # carreras como sí lo haría `validates uniqueness`.
  #
  # Idempotente: una segunda inscripción activa del mismo (actividad,
  # estudiante) devuelve la existente en vez de fallar. Actividad paga => un
  # Finance::Charge (nunca un cobro propio de este dominio), creado en la MISMA
  # transacción (si el cargo falla, la inscripción no queda), reusando la
  # idempotencia por idempotency_key de ChargeCreator (hidden field generado
  # una vez en el render, misma convención que el resto de finance).
  class EnrollmentCreator
    # La actividad ya alcanzó su cupo — el controller la traduce a un mensaje
    # amable, nunca a un 500.
    class CapacityExceeded < StandardError; end

    def self.call(institution:, activity:, student:, enrolled_via:, enrolled_by_user: nil, idempotency_key: nil)
      new(institution: institution, activity: activity, student: student, enrolled_via: enrolled_via,
        enrolled_by_user: enrolled_by_user, idempotency_key: idempotency_key).call
    end

    def initialize(institution:, activity:, student:, enrolled_via:, enrolled_by_user:, idempotency_key:)
      @institution = institution
      @activity = activity
      @student = student
      @enrolled_via = enrolled_via
      @enrolled_by_user = enrolled_by_user
      @idempotency_key = idempotency_key
    end

    def call
      Extracurriculars::Activity.transaction do
        activity.lock!

        existing = active_enrollment
        next existing if existing

        raise CapacityExceeded if at_capacity?

        enrollment = Extracurriculars::Enrollment.create!(
          institution: institution, activity: activity, student: student, status: "active",
          enrolled_at: Time.current, enrolled_via: enrolled_via, enrolled_by_user: enrolled_by_user
        )
        charge_for_paid_activity
        enrollment
      end
    end

    private

    attr_reader :institution, :activity, :student, :enrolled_via, :enrolled_by_user, :idempotency_key

    def active_enrollment
      Extracurriculars::Enrollment.find_by(
        institution_id: institution.id, activity_id: activity.id,
        student_id: student.id, status: "active"
      )
    end

    def at_capacity?
      Extracurriculars::Enrollment
        .where(institution_id: institution.id, activity_id: activity.id, status: "active")
        .count >= activity.capacity
    end

    # Actividad paga => Charge contra la cuenta del estudiante. La cuenta NO se
    # crea de forma perezosa en ningún lado del repo (los controllers de finance
    # hacen find_by + 404), así que aquí se find-or-create — seguro porque
    # student_accounts tiene índice único (institution_id, student_id). Moneda
    # COP por defecto: es la moneda canónica de la app (no hay columna de moneda
    # en institutions). El puente cents->decimal es explícito y de una vez
    # (Activity#fee_amount, BigDecimal, sin Float).
    def charge_for_paid_activity
      return if activity.free?

      account = Finance::StudentAccount.find_or_create_by!(
        institution_id: institution.id, student_id: student.id
      ) do |a|
        a.balance = 0
        a.currency = "COP"
      end

      Finance::ChargeCreator.call(
        institution: institution, account: account, amount: activity.fee_amount,
        description: "Actividad extracurricular: #{activity.name}", idempotency_key: idempotency_key
      )
    end
  end
end
