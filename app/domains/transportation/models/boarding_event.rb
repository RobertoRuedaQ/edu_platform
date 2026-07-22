module Transportation
  class BoardingEvent < ApplicationRecord
    self.table_name = "boarding_events"

    EVENT_TYPES = %w[boarded alighted].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :route, class_name: "Transportation::Route", inverse_of: :boarding_events
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :recorded_by, class_name: "Core::InstitutionUser", foreign_key: :recorded_by_institution_user_id

    validates :event_type, inclusion: { in: EVENT_TYPES }

    def event_type_label
      event_type == "boarded" ? "Abordaje" : "Descenso"
    end
  end
end
