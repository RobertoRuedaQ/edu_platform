module Cafeteria
  # A student's dietary restriction (~5% of students carry one).
  class DietaryRestriction < ApplicationRecord
    self.table_name = "dietary_restrictions"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student", inverse_of: :dietary_restrictions

    validates :restriction_type, presence: true
  end
end
