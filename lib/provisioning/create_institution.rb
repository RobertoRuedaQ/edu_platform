module Provisioning
  # Admin/provisioning path — NOT a normal request; no tenant is resolved from a
  # subdomain here. In ONE transaction: insert the GLOBAL institutions row, then
  # SET LOCAL the tenant GUC to the new id and insert the 1:1 tenant-scoped
  # institution_settings row, so its FORCE-RLS WITH CHECK passes.
  class CreateInstitution
    Result = Data.define(:institution)

    def self.call(...) = new(...).call

    def initialize(name:, slug:, code:, kind: "school", settings: {})
      @name     = name
      @slug     = slug
      @code     = code
      @kind     = kind
      @settings = settings
    end

    def call
      ActiveRecord::Base.transaction do
        # Global table, no RLS — safe to insert with no GUC set.
        institution = Core::Institution.create!(name: @name, slug: @slug, code: @code, kind: @kind)

        # Now become that tenant for the rest of THIS transaction so the
        # tenant-scoped insert satisfies WITH CHECK (institution_id = GUC).
        Tenant::Guc.set_local(institution.id)
        Core::InstitutionSetting.create!(@settings.merge(institution_id: institution.id))

        Result.new(institution: institution)
      end
    end
  end
end
