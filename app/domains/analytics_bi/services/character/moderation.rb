module AnalyticsBi
  module Character
    # Moderation of a peer/guardian appreciation (BI_DOCUMENT.md §5.4 resguardo
    # #6). APPEND-ONLY: withholding is a status FLIP to withheld_by_moderation,
    # NEVER a destroy — the row (and its giver identity) stays for the audit
    # trail. Gated at the controller by hps.character.moderate; this is the only
    # actor allowed to see attribution at all (§5.4 resguardo #3).
    #
    # Every moderation action audits via IdentityAccess::Audit.log with the
    # peer_appreciation.withheld action (registered in AuditEventIndex::ACTIONS).
    module Moderation
      module_function

      # Withhold a contribution. Idempotent: an already-withheld row is left
      # untouched and no duplicate audit event is written.
      def withhold!(appreciation:, actor:, institution: Current.institution)
        return appreciation if appreciation.withheld?

        appreciation.update!(status: "withheld_by_moderation")
        IdentityAccess::Audit.log(
          institution: institution,
          action: "peer_appreciation.withheld",
          actor_institution_user: actor,
          target: appreciation,
          metadata: { tag_id: appreciation.tag_id, student_id: appreciation.student_id }
        )
        appreciation
      end
    end
  end
end
