module Rls
  # Reusable, reversible RLS toggles for migrations. NOT applied to any table
  # here — this is infrastructure only; domain tables call these in their own
  # migrations.
  module MigrationHelpers
    def enable_rls(table, column: :institution_id, policy: nil)
      policy ||= "#{table}_tenant_isolation"
      t = quote_table_name(table)

      reversible do |dir|
        dir.up do
          execute "ALTER TABLE #{t} ENABLE ROW LEVEL SECURITY"
          # FORCE is the one that matters: without it the table OWNER (migrator)
          # silently bypasses the policy. With it, everyone is subject to RLS.
          execute "ALTER TABLE #{t} FORCE ROW LEVEL SECURITY"
          execute <<~SQL
            CREATE POLICY #{policy} ON #{t}
              USING (#{column} = #{tenant_guc_sql})
              WITH CHECK (#{column} = #{tenant_guc_sql})
          SQL
          # missing-ok flag (true) + NULLIF: an unset OR empty GUC -> NULL ->
          # predicate false. Reads return nothing and writes are rejected,
          # instead of erroring. NULLIF matters because after a SET LOCAL + commit
          # PostgreSQL leaves the custom GUC as '' (empty string), and ''::uuid
          # would raise on the next global (tenant-less) query on that connection.
        end

        dir.down do
          execute "DROP POLICY IF EXISTS #{policy} ON #{t}"
          execute "ALTER TABLE #{t} NO FORCE ROW LEVEL SECURITY"
          execute "ALTER TABLE #{t} DISABLE ROW LEVEL SECURITY"
        end
      end
    end

    # The tenant predicate expression. NULLIF turns both an unset GUC (NULL) and
    # a post-SET-LOCAL empty string ('') into NULL, so the comparison is simply
    # false for tenant-less connections instead of raising on ''::uuid.
    def tenant_guc_sql
      "NULLIF(current_setting('app.current_institution_id', true), '')::uuid"
    end

    def disable_rls(table, policy: nil)
      policy ||= "#{table}_tenant_isolation"
      t = quote_table_name(table)
      execute "DROP POLICY IF EXISTS #{policy} ON #{t}"
      execute "ALTER TABLE #{t} NO FORCE ROW LEVEL SECURITY"
      execute "ALTER TABLE #{t} DISABLE ROW LEVEL SECURITY"
    end
  end
end
