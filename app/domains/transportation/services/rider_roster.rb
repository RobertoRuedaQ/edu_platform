module Transportation
  # STUB: which (stub) students ride which (stub) route.
  # TODO: reemplazar por un modelo real de asignación de pasajeros.
  module RiderRoster
    Row = Data.define(:student_id, :student_name, :route_id, :stop_name)

    def self.all
      [
        Row.new(student_id: "s-1", student_name: "Valentina Suárez", route_id: "route-1", stop_name: "Calle 100"),
        Row.new(student_id: "s-7", student_name: "Daniela Ortiz", route_id: "route-1", stop_name: "Portal Norte"),
        Row.new(student_id: "s-4", student_name: "Mateo Cárdenas", route_id: "route-3", stop_name: "Av. Boyacá")
      ]
    end

    def self.for_route(route_id)
      all.select { |rider| rider.route_id == route_id.to_s }
    end

    def self.for_student(student_id)
      all.find { |rider| rider.student_id == student_id.to_s }
    end
  end
end
