module Core
  # GLOBAL identity — a user can belong to many institutions via memberships.
  # No RLS. (has_secure_password is intentionally not wired yet: bcrypt is not
  # in the bundle. Add `gem "bcrypt"` + `has_secure_password` in the auth phase.)
  class User < ApplicationRecord
    self.table_name = "users"

    has_many :memberships, class_name: "Core::InstitutionUser",
             foreign_key: :user_id, inverse_of: :user, dependent: :destroy
    has_many :sessions, class_name: "Core::Session",
             foreign_key: :user_id, dependent: :destroy

    validates :email, presence: true, uniqueness: true
  end
end
