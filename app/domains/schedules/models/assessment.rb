module Schedules
  # A grade (nota) on the 0.0–5.0 scale (pass 3.0). Different kinds: quiz,
  # taller, parcial, proyecto, participación. A null score means "pendiente".
  class Assessment < ApplicationRecord
    self.table_name = "assessments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :enrollment,  class_name: "Schedules::Enrollment", inverse_of: :assessments

    validates :kind, :title, :term, presence: true

    scope :graded,  -> { where.not(score: nil) }
    scope :passing, -> { graded.where("score >= 3.0") }
    scope :failing, -> { graded.where("score < 3.0") }
  end
end
