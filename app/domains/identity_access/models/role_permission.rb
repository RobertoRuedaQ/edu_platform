module IdentityAccess
  class RolePermission < ApplicationRecord
    self.table_name = "role_permissions"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :role, class_name: "IdentityAccess::Role", inverse_of: :role_permissions
    belongs_to :permission, class_name: "IdentityAccess::Permission", inverse_of: :role_permissions
  end
end
