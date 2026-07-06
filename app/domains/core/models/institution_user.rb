module Core
  # TENANT-SCOPED membership join. RLS-enforced at the DB.
  class InstitutionUser < ApplicationRecord
    self.table_name = "institution_users"

    belongs_to :institution, class_name: "Core::Institution", inverse_of: :memberships
    belongs_to :user,        class_name: "Core::User",        inverse_of: :memberships

    validates :user_id, uniqueness: { scope: :institution_id }
  end
end
