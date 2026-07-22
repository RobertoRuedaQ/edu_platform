module Core
  module RosterImport
    # Recurring fan-out (config/recurring.yml), molde IdentityAccess::
    # Invitations::ExpireAllJob — roster_import_rows is tenant-scoped/RLS, so
    # this can't run GUC-less; ApplicationJob's around_perform only fixes ONE
    # institution_id per job instance, so this job manages its own
    # per-institution loop + GUC instead. RowPurger.call is cheap enough (one
    # DELETE) not to need its own queued job per institution, same reasoning
    # ExpireAllJob already documents.
    class PurgeRowsAllJob < ApplicationJob
      def perform
        Core::Institution.find_each do |institution|
          begin
            ActiveRecord::Base.transaction do
              Tenant::Guc.set_local(institution.id)
              RowPurger.call(institution: institution)
            end
          ensure
            Tenant::Guc.reset!
          end
        end
      end
    end
  end
end
