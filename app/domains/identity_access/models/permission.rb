module IdentityAccess
  # GLOBAL capability catalog (no tenant). Seeded from code via SeedPermissions.
  class Permission < ApplicationRecord
    self.table_name = "permissions"
    has_many :role_permissions, class_name: "IdentityAccess::RolePermission",
             foreign_key: :permission_id, inverse_of: :permission, dependent: :destroy
    validates :key, presence: true, uniqueness: true
  end
end
