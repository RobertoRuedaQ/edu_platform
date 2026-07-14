module Portals
  # STUB transport info per child — same route names GuardianDashboard's
  # shortcuts already show (Ruta 3 / Ruta 1).
  # TODO: reemplazar por Transportation::RiderRoster real vía guardian_students.
  module GuardianTransportInfo
    Info = Data.define(:child_id, :child_name, :route_name, :stop_name, :pickup_time)

    def self.for_children
      [
        Info.new(child_id: "stub-child-1", child_name: "Ana Martínez", route_name: "Ruta 3",
                 stop_name: "Calle 100", pickup_time: "06:30"),
        Info.new(child_id: "stub-child-2", child_name: "Luis Martínez", route_name: "Ruta 1",
                 stop_name: "Portal Norte", pickup_time: "06:15")
      ]
    end
  end
end
