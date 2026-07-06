module Tenant
  # The one place that reads/writes the PostgreSQL GUC that RLS policies match:
  #   institution_id = current_setting('app.current_institution_id')::uuid
  module Guc
    KEY = "app.current_institution_id"

    # SET LOCAL, via set_config(..., is_local => true). Transaction-scoped:
    # it clears automatically at COMMIT/ROLLBACK, so it can NEVER survive into
    # the next checkout of this pooled connection. This is the real guarantee
    # against cross-request/tenant leak; reset! below is only a backstop.
    def self.set_local(institution_id)
      conn = ActiveRecord::Base.connection
      conn.execute(
        "SELECT set_config(#{conn.quote(KEY)}, #{conn.quote(institution_id.to_s)}, true)"
      )
    end

    # Belt-and-suspenders: force the session-level value back to unset.
    def self.reset!
      ActiveRecord::Base.connection.execute("RESET #{KEY}")
    end
  end
end
