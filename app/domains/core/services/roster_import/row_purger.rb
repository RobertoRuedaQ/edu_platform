module Core
  module RosterImport
    # Deletes the raw rows (jsonb `raw`, sensitive fields encrypted via
    # Cipher) of committed batches once the retention window elapses —
    # guidelines/OPEN_PROCESS.md item #2 (onboarding hardening, gated closed
    # 2026-07-22). Nothing else in the app ever purges roster_import_rows
    # (Core::RosterImportBatch#roster_import_rows is dependent: :destroy, but
    # batches themselves are never destroyed) — these rows would otherwise
    # carry PII forever with zero ongoing purpose past commit.
    #
    # ONLY committed batches are ever purged — uploaded/validated/previewed/
    # failed batches keep their rows indefinitely (staff may still need to
    # fix and resubmit), matching the backlog item's own framing ("purga...
    # post-commit"), not a general retention policy for every batch state.
    #
    # RETENTION is a boring, conservative default — 30 days gives staff a
    # real window to review a commit's per-row outcome (RosterImportsController
    # #show renders line_number/status/message from these exact rows) before
    # the PII is gone. PLACEHOLDER: no business rule confirmed by the owner,
    # same posture as HEAT_RISK_THRESHOLD/RECENT_DISCIPLINARY_WINDOW_DAYS
    # elsewhere in this codebase — revisit if a real need surfaces.
    class RowPurger
      RETENTION = 30.days

      def self.call(institution:)
        new(institution: institution).call
      end

      def initialize(institution:)
        @institution = institution
      end

      def call
        Core::RosterImportRow
          .where(institution_id: institution.id, roster_import_batch_id: purgeable_batch_ids)
          .delete_all
      end

      private

      attr_reader :institution

      def purgeable_batch_ids
        Core::RosterImportBatch
          .where(institution_id: institution.id, status: "committed")
          .where(committed_at: ..RETENTION.ago)
          .select(:id)
      end
    end
  end
end
