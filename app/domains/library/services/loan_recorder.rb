module Library
  # Lends a physical copy — molde Finance::ChargeCreator/Extracurriculars::
  # EnrollmentCreator (lock, idempotent, transactional), adapted for the ONE
  # shape neither of those has: guarding the LOCKED row's OWN status column
  # (copy.status), not a count/sum over child rows.
  #
  # copy.lock! (never loan.lock!) is the seam BOTH this service and
  # ReturnRecorder take before touching copy.status OR loan.status — see
  # the migration's comment for why (cross-loan interleaving on the same
  # copy is the real race, not two concurrent ops on one loan row). The
  # partial unique index on (institution_id, copy_id) WHERE status='active'
  # is the DB-level backstop, same discipline as activity_enrollments.
  class LoanRecorder
    class NotAvailable < StandardError; end
    class BorrowLimitExceeded < StandardError; end

    # PLACEHOLDER: no settings-per-institution mechanism exists (A3, deferred
    # elsewhere in this codebase) — conservative guessed defaults, molde
    # HEAT_RISK_THRESHOLD/RowPurger::RETENTION. Split by borrower type
    # because guidelines/library_prompt.md explicitly says "por rol de
    # usuario", not a flat limit.
    MAX_ACTIVE_LOANS_STUDENT = 3
    MAX_ACTIVE_LOANS_STAFF = 5
    DEFAULT_LOAN_PERIOD_DAYS = 14

    def self.call(institution:, copy:, borrower:, issued_by:, due_at: nil, idempotency_key: nil)
      new(institution: institution, copy: copy, borrower: borrower, issued_by: issued_by,
        due_at: due_at || DEFAULT_LOAN_PERIOD_DAYS.days.from_now, idempotency_key: idempotency_key).call
    end

    def initialize(institution:, copy:, borrower:, issued_by:, due_at:, idempotency_key:)
      @institution = institution
      @copy = copy
      @borrower = borrower
      @issued_by = issued_by
      @due_at = due_at
      @idempotency_key = idempotency_key
    end

    def call
      Library::ResourceCopy.transaction do
        copy.lock!

        existing = existing_loan
        next existing if existing

        raise NotAvailable, "el ejemplar no está disponible" unless copy.status == "available"
        raise BorrowLimitExceeded, "el prestatario ya alcanzó su máximo de préstamos activos" if at_borrow_limit?

        loan = Library::Loan.create!(
          institution: institution, copy: copy, issued_by: issued_by,
          borrowed_at: Time.current, due_at: due_at, status: "active",
          idempotency_key: idempotency_key, **borrower_attrs
        )
        copy.update!(status: "loaned")
        emit_usage(loan)
        loan
      end
    end

    private

    attr_reader :institution, :copy, :borrower, :issued_by, :due_at, :idempotency_key

    def existing_loan
      return nil if idempotency_key.blank?

      Library::Loan.find_by(institution_id: institution.id, idempotency_key: idempotency_key)
    end

    def borrower_attrs
      case borrower
      when GroupManagement::Student then { borrower_student: borrower }
      when Core::InstitutionUser then { borrower_institution_user: borrower }
      else raise ArgumentError, "borrower debe ser GroupManagement::Student o Core::InstitutionUser"
      end
    end

    def student_borrower? = borrower.is_a?(GroupManagement::Student)

    def at_borrow_limit?
      limit = student_borrower? ? MAX_ACTIVE_LOANS_STUDENT : MAX_ACTIVE_LOANS_STAFF
      active_loans_for_borrower.count >= limit
    end

    def active_loans_for_borrower
      scope = Library::Loan.where(institution_id: institution.id, status: "active")
      student_borrower? ? scope.where(borrower_student_id: borrower.id) : scope.where(borrower_institution_user_id: borrower.id)
    end

    # M1 (guidelines/library_prompt.md): one "préstamos" unit per NEW real
    # Loan — only reached past the idempotency guard above, so a resubmit
    # never re-emits.
    def emit_usage(loan)
      ControlPlane::Usage::Ingest.emit(institution: institution, addon_key: "library",
        unit: "préstamos", occurred_at: loan.borrowed_at, idempotency_key: "library_loan:#{loan.id}")
    end
  end
end
