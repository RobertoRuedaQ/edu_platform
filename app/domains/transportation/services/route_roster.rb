module Transportation
  # STUB routes — no routes/vehicles/stops table exists in the schema at all
  # (the most greenfield domain yet, more so than schedules' timetable).
  #
  # route_id aliases id: a route IS the scoped resource, same pattern as
  # Department/Section/Group — see Authorization::Assignment::SCOPE_READERS,
  # which now includes :route.
  #
  # TODO: reemplazar por un modelo real de rutas/vehículos cuando exista.
  module RouteRoster
    Stop = Data.define(:name, :time)
    Row = Data.define(:id, :name, :driver_name, :vehicle_plate, :capacity, :stops) do
      def route_id
        id
      end
    end

    def self.all
      [
        Row.new(id: "route-1", name: "Ruta 1", driver_name: "Pedro Sánchez", vehicle_plate: "ABC-123",
                capacity: 20,
                stops: [
                  Stop.new(name: "Portal Norte", time: "06:15"),
                  Stop.new(name: "Calle 100", time: "06:30"),
                  Stop.new(name: "Colegio", time: "07:00")
                ]),
        Row.new(id: "route-3", name: "Ruta 3", driver_name: "Marta Londoño", vehicle_plate: "XYZ-789",
                capacity: 24,
                stops: [
                  Stop.new(name: "Suba", time: "06:00"),
                  Stop.new(name: "Av. Boyacá", time: "06:25"),
                  Stop.new(name: "Colegio", time: "07:00")
                ])
      ]
    end

    def self.find(id)
      all.find { |route| route.id == id.to_s }
    end
  end
end
