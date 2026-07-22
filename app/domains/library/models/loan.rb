module Library
  # A checkout transaction (guidelines/library_prompt.md). Written ONLY by
  # Library::LoanRecorder/ReturnRecorder, always under copy.lock! (see the
  # migration comment for why the lock lives on `copy`, never on this row).
  #
  # `borrower_institution_user` XOR `borrower_student` (DB CHECK
  # num_nonnulls = 1) — molde Communication::ConversationParticipant: the
  # spec only named an institution_user borrower, but its own UX section
  # requires students to see their own loans in a self-service portal, and
  # students are GroupManagement::Student rows, never institution_users.
  # Never a true polymorphic association (same discipline as
  # ConversationParticipant).
  class Loan < ApplicationRecord
    self.table_name = "library_loans"

    STATUSES = %w[active returned overdue lost].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :copy, class_name: "Library::ResourceCopy", inverse_of: :loans
    belongs_to :borrower_institution_user, class_name: "Core::InstitutionUser", optional: true
    belongs_to :borrower_student, class_name: "GroupManagement::Student", optional: true
    belongs_to :issued_by, class_name: "Core::InstitutionUser",
      foreign_key: :issued_by_institution_user_id

    validates :status, inclusion: { in: STATUSES }
    validates :borrowed_at, :due_at, presence: true
    validate :exactly_one_borrower

    scope :active, -> { where(status: "active") }

    def staff_borrower? = borrower_institution_user_id.present?
    def student_borrower? = borrower_student_id.present?

    def borrower = staff_borrower? ? borrower_institution_user : borrower_student

    def borrower_name
      staff_borrower? ? borrower_institution_user.user.name : "#{borrower_student.first_name} #{borrower_student.last_name}"
    end

    # Computed, never persisted — no sweep job sets a real "overdue" status
    # yet (deferred, see Library::ReturnRecorder's comment).
    def overdue? = status == "active" && due_at < Time.current

    private

    def exactly_one_borrower
      return if [ borrower_institution_user_id, borrower_student_id ].compact.size == 1

      errors.add(:base, "debe tener exactamente un prestatario (institution_user o student)")
    end
  end
end
