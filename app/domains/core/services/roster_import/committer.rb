module Core
  module RosterImport
    # Phase 3 (J4): applies a validated batch. Kind-AGNOSTIC orchestration
    # (G7): the actual upsert (what record, how) comes entirely from
    # Strategy.for(batch.kind, ...)#commit_row! — this file never branches on
    # kind, never touches GroupManagement::Student or Core::User/
    # Core::GuardianStudent directly.
    #
    # Idempotent, additive/never-destructive for every kind (J2/J9/G4):
    # commit_row! resolves against real records AT COMMIT TIME, not from the
    # row's (possibly stale) validated status, so a second run behaves
    # consistently even for a row the validator originally called "valid".
    # Only "valid"/"duplicate" rows are applied; "error"/"collision" rows are
    # skipped and left as-is — the batch still commits, just with those
    # omitted. Committer itself never invites — that stays a strategy-level
    # decision (J3-bis, closed for guardians: Strategies::Guardians invites
    # a REAL new user, attributed to @batch.created_by, molde
    # Bootstrap::FirstAdmin). Students never invites, no login to activate.
    class Committer
      COMMITTABLE_STATUSES = %w[valid duplicate].freeze

      def self.call(batch:)
        new(batch).call
      end

      def initialize(batch)
        @batch = batch
        @strategy = Strategy.for(batch.kind, institution: batch.institution, created_by: batch.created_by)
      end

      def call
        rows = @batch.roster_import_rows.where(status: COMMITTABLE_STATUSES).order(:line_number)
        rows.each { |row| commit_row(row) }

        @batch.update!(status: "committed", committed_at: Time.current)
      end

      private

      def commit_row(row)
        plain = Cipher.decrypt_row(row.raw, @strategy.sensitive_fields)
        record = @strategy.commit_row!(plain)
        row.update!(resolved_record_id: record.id)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        row.update!(status: "error", message: "commit falló: #{e.message}")
      end
    end
  end
end
