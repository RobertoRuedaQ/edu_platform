module Portals
  # STUB transport info for the student's own portal — same "Ruta 3" already
  # shown on Portals::StudentDashboard's shortcut stat.
  # TODO: reemplazar por Transportation::RiderRoster real (students.user_id).
  class StudentTransportInfo
    def self.stub
      new(route_name: "Ruta 3", vehicle_plate: "XYZ-789", stop_name: "Calle 100", pickup_time: "06:30")
    end

    def initialize(route_name:, vehicle_plate:, stop_name:, pickup_time:)
      @route_name = route_name
      @vehicle_plate = vehicle_plate
      @stop_name = stop_name
      @pickup_time = pickup_time
    end

    attr_reader :route_name, :vehicle_plate, :stop_name, :pickup_time
  end
end
