module Cafeteria
  # A completed cafeteria sale (guidelines/CLOSURE_PLAN.md Fase D — cafeteria
  # resto). Written ONLY by `Cafeteria::PurchaseRecorder`, always alongside
  # exactly one `Finance::Charge` (a purchase increases what the family owes,
  # same accounts-receivable model as tuition/extracurricular fees — there is
  # no prepaid-credit/top-up flow anywhere in this app). Immutable once
  # created: no update/destroy route, same append-only posture as
  # `disciplinary_logs`/`boarding_events`.
  class Purchase < ApplicationRecord
    self.table_name = "cafeteria_purchases"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :recorded_by, class_name: "Core::InstitutionUser",
      foreign_key: :recorded_by_institution_user_id
    belongs_to :charge, class_name: "Finance::Charge"
    has_many :purchase_lines, class_name: "Cafeteria::PurchaseLine", inverse_of: :purchase,
      dependent: :restrict_with_exception

    validates :total_price_cents, numericality: { greater_than: 0 }
    validates :purchased_at, presence: true

    def total_price_amount = BigDecimal(total_price_cents) / 100
    def item_names = purchase_lines.pluck(:item_name).join(", ")
  end
end
