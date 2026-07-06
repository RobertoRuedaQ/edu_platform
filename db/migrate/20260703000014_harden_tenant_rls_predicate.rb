class HardenTenantRlsPredicate < ActiveRecord::Migration[8.1]
  # Recreate every tenant-isolation policy so the predicate tolerates an empty
  # GUC (''), which PostgreSQL leaves behind after SET LOCAL + COMMIT. Without
  # NULLIF, the next tenant-less query on a reused pooled connection raises
  # `invalid input syntax for type uuid: ""` instead of returning zero rows.
  NEW = "NULLIF(current_setting('app.current_institution_id', true), '')::uuid".freeze
  OLD = "current_setting('app.current_institution_id', true)::uuid".freeze

  def up  = rebuild_policies(NEW)
  def down = rebuild_policies(OLD)

  private

  def rebuild_policies(expr)
    tenant_tables.each do |table|
      policy = "#{table}_tenant_isolation"
      t = quote_table_name(table)
      execute "DROP POLICY IF EXISTS #{policy} ON #{t}"
      execute <<~SQL
        CREATE POLICY #{policy} ON #{t}
          USING (institution_id = #{expr})
          WITH CHECK (institution_id = #{expr})
      SQL
    end
  end

  def tenant_tables
    select_values(<<~SQL)
      SELECT tablename FROM pg_policies
      WHERE schemaname = 'public' AND policyname LIKE '%\\_tenant\\_isolation'
      ORDER BY tablename
    SQL
  end
end
