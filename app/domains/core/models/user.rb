module Core
  # GLOBAL identity — a user can belong to many institutions via memberships.
  # No RLS.
  class User < ApplicationRecord
    self.table_name = "users"

    has_secure_password

    # Deterministic so the partial unique index on national_id can enforce
    # uniqueness against the stored ciphertext.
    encrypts :national_id, deterministic: true

    has_many :memberships, class_name: "Core::InstitutionUser",
             foreign_key: :user_id, inverse_of: :user, dependent: :destroy
    has_many :sessions, class_name: "Core::Session",
             foreign_key: :user_id, dependent: :destroy

    # A user MAY be a student; deleting the user detaches, never deletes, the
    # tenant's student record (matches the FK's on_delete: :nullify).
    has_one :student, class_name: "GroupManagement::Student", dependent: :nullify

    # NEW guardian links (keyed on this global user), separate from the legacy
    # StudentSupport guardian tables.
    has_many :guardian_links, class_name: "Core::GuardianStudent",
             foreign_key: :guardian_user_id, dependent: :destroy
    has_many :guarded_students, through: :guardian_links, source: :student

    validates :email, presence: true, uniqueness: true
  end
end
