module Provisioning
  # THE control-plane entry point (v1.29.0, MVP item #10): one flow, one
  # transaction — create the institution, then bootstrap its first
  # institution_admin (IdentityAccess::Bootstrap::FirstAdmin) so it can
  # actually onboard the rest of its people the moment it exists. Composes
  # CreateInstitution rather than duplicating it (db/seeds.rb's demo
  # institutions still use CreateInstitution directly, with no admin — this
  # wrapper is additive, not a replacement).
  class ProvisionInstitution
    Result = Data.define(:institution, :admin_user)

    def self.call(...) = new(...).call

    def initialize(name:, slug:, code:, admin_email:, admin_name:, kind: "school", settings: {})
      @name = name
      @slug = slug
      @code = code
      @kind = kind
      @settings = settings
      @admin_email = admin_email
      @admin_name = admin_name
    end

    def call
      ActiveRecord::Base.transaction do
        institution = CreateInstitution.call(name: @name, slug: @slug, code: @code, kind: @kind, settings: @settings).institution
        admin = IdentityAccess::Bootstrap::FirstAdmin.call(institution: institution, email: @admin_email, name: @admin_name)
        Result.new(institution: institution, admin_user: admin.user)
      end
    end
  end
end
