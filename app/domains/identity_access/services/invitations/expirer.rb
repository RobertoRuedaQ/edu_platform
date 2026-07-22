module IdentityAccess
  module Invitations
    # Sweeps past-due "sent" invitations to "expired" for one institution.
    # Purely a bookkeeping pass for admin-facing status columns — the actual
    # security check (an expired invitation can never complete signup) is
    # Invitation#usable?, which reads expires_at directly and doesn't depend
    # on this having run. Called opportunistically from the people index, AND
    # (v1.32.0) swept daily for every institution by
    # IdentityAccess::Invitations::ExpireAllJob (config/recurring.yml) — both
    # call this same method, neither duplicates its logic.
    class Expirer
      def self.call(institution:)
        Invitation.where(institution_id: institution.id, status: "sent")
          .where("expires_at < ?", Time.current)
          .update_all(status: "expired")
      end
    end
  end
end
