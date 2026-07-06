require "test_helper"

# Discipline as a test. Any table that carries an institution_id column MUST be
# ENABLE+FORCE row-level-secured AND have an index whose LEADING column is
# institution_id. A future tenant table that forgets either fails CI loudly.
class TenantRlsGuardTest < ActiveSupport::TestCase
  # Tables that legitimately have NO tenant policy:
  #  - institutions / users / sessions are GLOBAL (institutions/users carry no
  #    institution_id; sessions uses current_institution_id, not institution_id)
  #  - Rails bookkeeping tables
  #  - Solid infra tables live in separate DBs and are never tenant-scoped
  GLOBAL_ALLOWLIST = %w[
    institutions users sessions
    schema_migrations ar_internal_metadata
  ].freeze
  SOLID_PREFIXES = %w[solid_queue_ solid_cache_ solid_cable_].freeze

  test "every institution_id table enforces FORCE RLS and a leading institution_id index" do
    offenders = tenant_tables.filter_map do |table|
      problems = []
      problems << "RLS is not ENABLE+FORCE"                         unless rls_forced?(table)
      problems << "no index whose leading column is institution_id" unless leading_index?(table)
      "#{table} -> #{problems.join('; ')}" if problems.any?
    end

    assert offenders.empty?, <<~MSG
      Tenant isolation guard failed. Fix with `enable_rls :<table>` and an index
      led by institution_id (e.g. add_index :t, [:institution_id, ...]).
      Offenders:
        - #{offenders.join("\n        - ")}
    MSG
  end

  private

  def conn = ActiveRecord::Base.connection
  def to_bool(v) = ActiveModel::Type::Boolean.new.cast(v)

  # Real tables in `public` that have an institution_id column, minus allowlist.
  def tenant_tables
    conn.select_values(<<~SQL).reject { |t| exempt?(t) }
      SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
        AND a.attname = 'institution_id'
        AND a.attnum > 0
        AND NOT a.attisdropped
    SQL
  end

  def exempt?(table)
    GLOBAL_ALLOWLIST.include?(table) || SOLID_PREFIXES.any? { |p| table.start_with?(p) }
  end

  def rls_forced?(table)
    row = conn.select_one(<<~SQL)
      SELECT c.relrowsecurity, c.relforcerowsecurity
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = #{conn.quote(table)}
    SQL
    row && to_bool(row["relrowsecurity"]) && to_bool(row["relforcerowsecurity"])
  end

  # indkey[0] is the FIRST indexed column's attnum (int2vector is 0-based).
  def leading_index?(table)
    conn.select_value(<<~SQL).to_i.positive?
      SELECT count(*)
      FROM pg_index i
      JOIN pg_class     t ON t.oid = i.indrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = i.indkey[0]
      WHERE n.nspname = 'public'
        AND t.relname = #{conn.quote(table)}
        AND a.attname = 'institution_id'
    SQL
  end
end
