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

    # Gate #1 of the two serial gates (§7.1): "does THIS institution have
    # addon_key active right now?" Delegates entirely to the control plane's
    # own predicate (S2a) — never reimplemented here. Always fresh (no
    # caching); Current.entitled_addon_keys is the per-request memo on top of
    # this, used by the enforcement concern and the nav filter.
    def entitled?(addon_key)
      ControlPlane::Entitlements::Check.entitled?(institution: self, addon_key: addon_key)
    end
  end
end
