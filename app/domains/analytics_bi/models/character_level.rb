module AnalyticsBi
  # A qualitative level within a CharacterDimension ("En desarrollo"/
  # "Consolidado"/"Destacado", …). descriptor is observable text, NEVER a number
  # (§1.1.2 — the system describes observed strengths, it never scores a minor's
  # personality).
  class CharacterLevel < ApplicationRecord
    self.table_name = "character_levels"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :dimension, class_name: "AnalyticsBi::CharacterDimension"

    validates :label, presence: true
  end
end
