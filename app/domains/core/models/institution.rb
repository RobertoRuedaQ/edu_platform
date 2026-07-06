module Core
  # GLOBAL tenant root. No RLS. Resolved by subdomain slug; `code` is the
  # human-facing business id, distinct from the uuidv7 PK.
  class Institution < ApplicationRecord
    self.table_name = "institutions"

    has_many :memberships, class_name: "Core::InstitutionUser",
             foreign_key: :institution_id, inverse_of: :institution, dependent: :destroy
    has_one :settings, class_name: "Core::InstitutionSetting",
            foreign_key: :institution_id, inverse_of: :institution, dependent: :destroy

    validates :name, :slug, :code, presence: true
  end
end
