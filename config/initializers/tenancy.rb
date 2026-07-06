# Wire the tenancy infrastructure into the framework.

# 1) Make the RLS helpers callable inside every migration.
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.include(Rls::MigrationHelpers)
end

# 2) Connection check-in safety net. When any unit of work (request or job)
#    completes and a DB connection was used, RESET the GUC before that
#    connection returns to the pool. SET LOCAL already scopes it to the
#    transaction; this guards against any stray session-level SET and makes
#    cross-tenant leak across pooled connections impossible.
Rails.application.executor.to_complete do
  Tenant::Guc.reset! if ActiveRecord::Base.connection_pool.active_connection?
end
