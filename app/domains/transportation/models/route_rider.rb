module Transportation
  class RouteRider < ApplicationRecord
    self.table_name = "route_riders"

    SHIFTS = %w[am pm].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :route, class_name: "Transportation::Route", inverse_of: :route_riders
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :route_stop, class_name: "Transportation::RouteStop", optional: true, inverse_of: :route_riders

    validates :shift, inclusion: { in: SHIFTS }
    validates :student_id, uniqueness: { scope: %i[institution_id shift] }

    def student_name
      "#{student.first_name} #{student.last_name}"
    end

    def stop_name
      route_stop&.name
    end

    def shift_label
      shift == "am" ? "Mañana" : "Tarde"
    end
  end
end
