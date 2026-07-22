module Library
  # Returns a loan — locks copy (NEVER loan), same discipline as
  # LoanRecorder and for the same reason: every writer of loan.status must
  # hold copy.lock! first, so a fresh loan.reload after the lock is
  # guaranteed to see any other transaction's committed writes.
  #
  # Overdue fines are DELIBERATELY deferred — guidelines/library_prompt.md
  # itself frames them as conditional ("si tiene configurada esa regla"),
  # and no settings-per-institution mechanism exists anywhere in this
  # codebase to configure such a rule (A3). Inventing a fee amount/policy
  # with zero business input would contradict this project's own repeated
  # discipline (billing hardening items are gated the same way). Revisit
  # once a real policy is confirmed.
  class ReturnRecorder
    class InvalidState < StandardError; end

    def self.call(institution:, loan:, returned_at: Time.current)
      new(institution: institution, loan: loan, returned_at: returned_at).call
    end

    def initialize(institution:, loan:, returned_at:)
      @institution = institution
      @loan = loan
      @returned_at = returned_at
    end

    def call
      copy = loan.copy

      Library::ResourceCopy.transaction do
        copy.lock!
        loan.reload

        next loan if loan.status == "returned"
        raise InvalidState, "el préstamo no está activo" unless loan.status == "active"

        loan.update!(returned_at: returned_at, status: "returned")
        copy.update!(status: "available")
        loan
      end
    end

    private

    attr_reader :institution, :loan, :returned_at
  end
end
