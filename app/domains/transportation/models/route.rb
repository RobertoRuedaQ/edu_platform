module Transportation
  class Route < ApplicationRecord
    self.table_name = "routes"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :driver_staff_member, class_name: "StaffManagement::StaffMember", optional: true

    has_many :route_stops, -> { order(:position) }, class_name: "Transportation::RouteStop",
             dependent: :destroy, inverse_of: :route
    has_many :route_riders, class_name: "Transportation::RouteRider", dependent: :destroy, inverse_of: :route
    has_many :boarding_events, class_name: "Transportation::BoardingEvent", dependent: :destroy, inverse_of: :route

    validates :name, presence: true

    # A route IS the scoped resource for Authorization::Assignment::
    # SCOPE_READERS[:route] — same pattern as Department/Section/GradeLevel,
    # which read their own id under a differently-named method.
    def route_id
      id
    end

    def driver_name
      driver_staff_member&.name
    end
  end
end
