module IdentityAccess
  class Role < ApplicationRecord
    self.table_name = "roles"
    belongs_to :institution, class_name: "Core::Institution"
    has_many :role_permissions, class_name: "IdentityAccess::RolePermission",
             foreign_key: :role_id, inverse_of: :role, dependent: :destroy
    has_many :permissions, through: :role_permissions, class_name: "IdentityAccess::Permission"
    has_many :role_assignments, class_name: "IdentityAccess::RoleAssignment",
             foreign_key: :role_id, inverse_of: :role, dependent: :destroy
    validates :key, :name, presence: true
  end
end
