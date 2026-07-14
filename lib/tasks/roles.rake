# Bootstrap task: create/repair the three PostgreSQL roles. Idempotent.
# MUST be run by a superuser/DBA (it needs CREATEROLE); it is NOT part of the
# app's runtime privileges. Passwords are read from ENV, never hardcoded.
namespace :db do
  namespace :roles do
    desc "Create/repair edu_migrator, edu_app_runtime, edu_bi_reader (idempotent)"
    task create: :environment do
      migrator_pw = ENV.fetch("EDU_MIGRATOR_PASSWORD")
      runtime_pw  = ENV.fetch("EDU_APP_RUNTIME_PASSWORD")
      bi_pw       = ENV.fetch("EDU_BI_READER_PASSWORD")

      conn = ActiveRecord::Base.connection
      db   = conn.current_database

      # 1) Roles exist? (CREATE ROLE has no IF NOT EXISTS — guard with a DO block)
      conn.execute(<<~SQL)
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'edu_migrator')    THEN CREATE ROLE edu_migrator    LOGIN; END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'edu_app_runtime') THEN CREATE ROLE edu_app_runtime LOGIN; END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'edu_bi_reader')   THEN CREATE ROLE edu_bi_reader   LOGIN; END IF;
        END $$;
      SQL

      # 2) Attributes — spelled out so the security posture is greppable.
      #    migrator owns the schema but is still NOBYPASSRLS; FORCE RLS is what
      #    actually stops the owner from seeing other tenants' rows.
      conn.execute("ALTER ROLE edu_migrator    NOSUPERUSER NOCREATEROLE NOBYPASSRLS CREATEDB")
      conn.execute("ALTER ROLE edu_app_runtime NOSUPERUSER NOCREATEROLE NOBYPASSRLS NOCREATEDB")
      # bi_reader is the ONE sanctioned cross-tenant path. BYPASSRLS lives here
      # and ONLY here; every use must be audited.
      conn.execute("ALTER ROLE edu_bi_reader   NOSUPERUSER NOCREATEROLE BYPASSRLS   NOCREATEDB")

      # 3) Passwords (quote() = injection-safe).
      conn.execute("ALTER ROLE edu_migrator    PASSWORD #{conn.quote(migrator_pw)}")
      conn.execute("ALTER ROLE edu_app_runtime PASSWORD #{conn.quote(runtime_pw)}")
      conn.execute("ALTER ROLE edu_bi_reader   PASSWORD #{conn.quote(bi_pw)}")

      # 4) Schema ownership/authority: migrator creates objects.
      # CREATE ON DATABASE lets the migrator create extensions (e.g. citext),
      # which is a database-level privilege, not a schema-level one.
      conn.execute("GRANT CREATE ON DATABASE #{conn.quote_column_name(db)} TO edu_migrator")
      conn.execute("GRANT CREATE, USAGE ON SCHEMA public TO edu_migrator")
      conn.execute("GRANT CONNECT ON DATABASE #{conn.quote_column_name(db)} TO edu_app_runtime, edu_bi_reader")
      conn.execute("GRANT USAGE ON SCHEMA public TO edu_app_runtime, edu_bi_reader")

      # 5) Privileges on EXISTING objects (repairs prior state).
      conn.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO edu_app_runtime")
      conn.execute("GRANT USAGE, SELECT               ON ALL SEQUENCES IN SCHEMA public TO edu_app_runtime")
      conn.execute("GRANT SELECT                      ON ALL TABLES    IN SCHEMA public TO edu_bi_reader")

      # 6) Privileges on FUTURE objects the migrator creates (the important bit —
      #    app_runtime never owns a table, so it needs auto-granted DML).
      conn.execute("ALTER DEFAULT PRIVILEGES FOR ROLE edu_migrator IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES    TO edu_app_runtime")
      conn.execute("ALTER DEFAULT PRIVILEGES FOR ROLE edu_migrator IN SCHEMA public GRANT USAGE, SELECT               ON SEQUENCES TO edu_app_runtime")
      conn.execute("ALTER DEFAULT PRIVILEGES FOR ROLE edu_migrator IN SCHEMA public GRANT SELECT                      ON TABLES    TO edu_bi_reader")

      puts "Roles ready: edu_migrator (owner/DDL), edu_app_runtime (DML, NOBYPASSRLS), edu_bi_reader (BYPASSRLS, audited)."
      puts "NOTE: run once per database the migrator owns (primary + each Solid DB) so default privileges apply there too."
    end
  end
end
