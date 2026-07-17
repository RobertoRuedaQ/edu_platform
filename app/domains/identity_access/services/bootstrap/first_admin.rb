module IdentityAccess
  module Bootstrap
    # The chicken-and-egg this closes: PeopleController#create (how every
    # OTHER person joins an institution) requires authorize!("people.manage"),
    # which requires an EXISTING RoleAssignment — a freshly provisioned
    # institution has none. This is the one path allowed to create the first
    # RoleAssignment directly, called ONLY from
    # Provisioning::ProvisionInstitution (never from a tenant request).
    #
    # Grants EVERY permission in the catalog except
    # "cross_tenant_reports.view" (§ guardrail: that key is reserved for
    # bi_auditor/edu_bi_reader, never a normal per-institution role) — this
    # role is the tenant's own "root", not a curated staff role like the
    # RoleRoster stub rows.
    class FirstAdmin
      Result = Data.define(:user, :role)

      ROLE_KEY = "institution_admin".freeze

      def self.call(...) = new(...).call

      def initialize(institution:, email:, name:)
        @institution = institution
        @email = email
        @name = name
      end

      def call
        Tenant::Guc.set_local(institution.id) # idempotent even if the caller already set it
        SeedPermissions.call # global catalog; safe/cheap to re-run

        role = find_or_create_role
        grant_all_permissions(role)

        resolved = Core::People::Resolver.call(email: email, name: name, institution: institution)
        RoleAssignment.find_or_create_by!(institution: institution, institution_user: resolved.institution_user, role: role)

        Invitations::Issuer.call(user: resolved.user, institution: institution, created_by: nil)
        Audit.log(institution: institution, action: "institution.admin_bootstrapped", target: resolved.user)

        Result.new(user: resolved.user, role: role)
      end

      private

      attr_reader :institution, :email, :name

      def find_or_create_role
        Role.find_or_create_by!(institution: institution, key: ROLE_KEY) do |r|
          r.name = "Administrador de institución"
          r.description = "Acceso completo a la institución (provisto al crearla)."
          r.system = true
        end
      end

      def grant_all_permissions(role)
        granted_keys = SeedPermissions::CATALOG.keys - %w[cross_tenant_reports.view]
        granted_keys.each do |key|
          permission = Permission.find_by!(key: key)
          RolePermission.find_or_create_by!(institution: institution, role: role, permission: permission)
        end
      end
    end
  end
end
