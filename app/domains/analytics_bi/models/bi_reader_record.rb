module AnalyticsBi
  # THE only connection in this app that runs as edu_bi_reader (BYPASSRLS,
  # SELECT-only — see lib/tasks/roles.rake). A SEPARATE connection pool,
  # never swaps/reconfigures the primary edu_app_runtime pool every other
  # model uses — same physical database, different Postgres role/password
  # (EDU_BI_READER_PASSWORD). Only classes under AnalyticsBi::BiReader::*
  # (this file's siblings) may subclass this; it is the single sanctioned
  # cross-tenant doorway (BI_DOCUMENT.md §6.1, PROJECT_STATE.md §7).
  #
  # Configs_for parses database.yml without requiring an already-open
  # connection (unlike reading ActiveRecord::Base.connection_db_config,
  # which would need the primary pool live first) — safe at class-body
  # eval time during boot/autoload.
  class BiReaderRecord < ActiveRecord::Base
    self.abstract_class = true

    # ENV["EDU_BI_READER_PASSWORD"] (not .fetch — nil is a valid value, same
    # as the primary connection's own EDU_DB_PASSWORD in database.yml): local
    # Postgres trusts TCP connections from localhost regardless of role, so
    # dev/test need no password at all. Only a real deployment (which trusts
    # nothing) requires the env var actually set.
    establish_connection(
      ActiveRecord::Base.configurations
        .configs_for(env_name: Rails.env, name: "primary")
        .configuration_hash.merge(username: "edu_bi_reader", password: ENV["EDU_BI_READER_PASSWORD"])
    )
  end
end
