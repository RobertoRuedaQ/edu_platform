module Portals
  # STUB dashboard for a guardian's own portal — child selector + per-child
  # shortcuts. In the real app this is resolved by guardian_students (the
  # StudentSupport::StudentGuardian join), NOT by an RBAC role: a guardian is a
  # person-entity, authorized by relationship to a student, never by
  # role_assignments.
  #
  # DECISIÓN ABIERTA: si más adelante se necesita un rol `guardian` liviano
  # (p. ej. permisos transversales fuera de sus hijos), esto se puede revertir
  # sin tocar la resolución por relación de los demás dominios.
  #
  # TODO: reemplazar por StudentSupport::Guardian -> guardian_students reales.
  class GuardianDashboard
    Child = Data.define(:id, :name, :section_name, :shortcuts)
    Shortcut = Data.define(:label, :path, :stat)

    def self.stub
      new(guardian_name: "Marta Gómez")
    end

    def initialize(guardian_name:)
      @guardian_name = guardian_name
    end

    attr_reader :guardian_name

    # One entry per child under this guardian (student_guardians join row).
    # TODO: montos/rutas reales vía helper `money` y los dominios de cafetería/transporte.
    def children
      [
        Child.new(id: "stub-child-1", name: "Ana Martínez", section_name: "9°A",
                  shortcuts: shortcuts_for(section: "9°A", balance: "$ 24.500", route: "Ruta 3")),
        Child.new(id: "stub-child-2", name: "Luis Martínez", section_name: "6°B",
                  shortcuts: shortcuts_for(section: "6°B", balance: "$ 10.200", route: "Ruta 1"))
      ]
    end

    private

    def shortcuts_for(section:, balance:, route:)
      [
        Shortcut.new(label: "Horario", path: "/portal/guardian/schedule",
                     stat: { value: section, label: "grupo" }),
        Shortcut.new(label: "Convivencia", path: "/portal/guardian/counseling", stat: nil),
        Shortcut.new(label: "Cafetería", path: "/portal/guardian/cafeteria",
                     stat: { value: balance, label: "saldo disponible" }),
        Shortcut.new(label: "Transporte", path: "/portal/guardian/transport",
                     stat: { value: route, label: "ruta asignada" })
      ]
    end
  end
end
