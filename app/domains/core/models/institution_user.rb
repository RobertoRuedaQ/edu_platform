module Core
  # TENANT-SCOPED membership join. RLS-enforced at the DB.
  class InstitutionUser < ApplicationRecord
    self.table_name = "institution_users"

    belongs_to :institution, class_name: "Core::Institution", inverse_of: :memberships
    belongs_to :user,        class_name: "Core::User",        inverse_of: :memberships
    has_many :role_assignments, class_name: "IdentityAccess::RoleAssignment",
      foreign_key: :institution_user_id, inverse_of: :institution_user, dependent: :destroy

    validates :user_id, uniqueness: { scope: :institution_id }
    validates :status, inclusion: { in: %w[active suspended] }

    scope :active, -> { where(status: "active") }

    def suspend!     = update!(status: "suspended")
    def reactivate!  = update!(status: "active")
    def active?      = status == "active"
  end
end
