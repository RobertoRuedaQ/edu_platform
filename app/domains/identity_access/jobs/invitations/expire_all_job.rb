module IdentityAccess
  module Invitations
    # Recurring fan-out (v1.32.0) — the entry config/recurring.yml points at.
    # Invitation is tenant-scoped/RLS (unlike ControlPlane::Usage::RollupJob's
    # global tables), so this can't run GUC-less — but ApplicationJob's
    # around_perform only fixes ONE institution_id per job instance, so this
    # job manages its own per-institution loop + GUC instead of relying on
    # that mechanism (same posture as the other *AllJob fan-outs this slice
    # adds). Previously only ran opportunistically from PeopleController#index
    # (see Expirer's own docstring) — this is the first scheduled sweep.
    class ExpireAllJob < ApplicationJob
      def perform
        Core::Institution.find_each do |institution|
          begin
            ActiveRecord::Base.transaction do
              Tenant::Guc.set_local(institution.id)
              Expirer.call(institution: institution)
            end
          ensure
            Tenant::Guc.reset!
          end
        end
      end
    end
  end
end
