module Portals
  # STUB dashboard for a student's own portal. In the real app this is resolved
  # by students.user_id — the student record owned by the signed-in user.
  # TODO: reemplazar por datos reales (Core::User -> GroupManagement::Student).
  class StudentDashboard
    Shortcut = Data.define(:label, :path, :stat)

    def self.stub
      new(student_name: "Ana Martínez", section_name: "9°A")
    end

    def initialize(student_name:, section_name:)
      @student_name = student_name
      @section_name = section_name
    end

    attr_reader :student_name, :section_name

    # Shortcuts to the student's own things. Destinations land with the domain
    # prompts; the stat values are stubs. TODO: montos reales vía helper `money`.
    def shortcuts
      [
        Shortcut.new(label: "Mi horario", path: "/portal/student/schedule",
                     stat: { value: "5", label: "clases hoy" }),
        Shortcut.new(label: "Mis grupos", path: "/portal/student/groups",
                     stat: { value: section_name, label: "grupo principal" }),
        Shortcut.new(label: "Cafetería", path: "/portal/student/cafeteria",
                     stat: { value: "$ 24.500", label: "saldo disponible" }),
        Shortcut.new(label: "Transporte", path: "/portal/student/transport",
                     stat: { value: "Ruta 3", label: "ruta asignada" })
      ]
    end
  end
end
