module Entitlement
  # Gate #1 of the two serial gates (§7.1): "does the INSTITUTION have this
  # module?" — runs BEFORE gate #2 (Authorization::Controller's authorize!,
  # called manually inside actions, so any before_action here already runs
  # first). A module the institution hasn't contracted responds with a
  # friendly "not entitled" page, never RBAC details, and never 404.
  #
  # ONE piece, included ONCE in ApplicationController — no domain-specific
  # branching. addon_key is INFERRED from the controller's top-level module
  # name (Cafeteria::MenuController -> "cafeteria"), matched against
  # Entitlement::Registry (tenant-side declared list, see that class). A
  # namespace Entitlement::Registry never declared (foundational domains,
  # top-level controllers, Portals::*) is simply never gated — no allowlist
  # needed for those, absence from the registry IS "not gated".
  module Controller
    extend ActiveSupport::Concern

    included do
      class_attribute :gated_addon_key, instance_writer: false, default: nil
      # Deliberately NOT prepended: TenantScoped's around_action (institution
      # resolution + GUC) and Authentication's before_action (session resume)
      # are registered earlier in ApplicationController, and BOTH must have
      # already run before this reads Current.institution/entitled_addon_keys
      # or renders a full-shell page. A plain before_action still runs before
      # authorize! — that's called manually inside actions, never as a
      # before_action, so ANY position here satisfies "gate #1 before gate #2".
      before_action :require_entitlement!
    end

    class_methods do
      # Escape hatch for the rare controller where namespace inference isn't
      # the right addon_key (E2). Nothing in app/domains/* needs this today —
      # every domain controller's namespace already matches its addon key.
      def gated_by_addon(key)
        self.gated_addon_key = key.to_s
      end
    end

    private

    def require_entitlement!
      key = gated_addon_key || self.class.module_parent_name&.underscore
      return if key.nil? || !Entitlement::Registry.gated?(key)
      return if Current.entitled_addon_keys.include?(key)

      # Fail-closed (E6) can legitimately fire with no institution resolved
      # at all — the normal shell's role switcher assumes one, so fall back
      # to the same minimal layout pre-login pages already use rather than
      # crash. The common case (institution resolved, just not entitled)
      # keeps the normal shell, same as the RBAC 403.
      if Current.institution
        render "errors/module_not_entitled", status: :forbidden
      else
        render "errors/module_not_entitled", status: :forbidden, layout: "auth"
      end
    end
  end
end
