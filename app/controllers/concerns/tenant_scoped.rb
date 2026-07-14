# Include in controllers that operate INSIDE a tenant. The GUC is set with
# SET LOCAL inside a per-request transaction, so every query in the action —
# and the DB backstop RLS — sees the right tenant, and nothing leaks after.
module TenantScoped
  extend ActiveSupport::Concern

  included do
    around_action :within_tenant
  end

  private

  def within_tenant
    Current.institution = Tenant::Resolver.call(request)

    if Current.institution
      ActiveRecord::Base.transaction do
        Tenant::Guc.set_local(Current.institution_id)
        yield
      end
    else
      # Legitimately tenant-less (login / tenant selection). No GUC set — RLS
      # policies use current_setting(KEY, true) and simply match zero rows.
      yield
    end
  end
end
