module Schedules
  # STUB roster of subject offerings (a subject taught to one specific group,
  # for one term) — this is what the pre-wired "Calificaciones" nav
  # (Fase 0, permission grades.read) and Apéndice A's orphaned "courses" bullet
  # (misassigned to core; the real models — Subject/Enrollment/Assessment —
  # live here) both need. Reuses the canonical stub-section ids so it lines up
  # with group_management/teacher_management's rosters.
  #
  # TODO: reemplazar por Schedules::Subject + Enrollment reales cuando haya
  # contexto de tenant resuelto por request.
  module SubjectRoster
    Row = Data.define(:id, :name, :code, :term, :group_id, :group_name)

    def self.all
      [
        Row.new(id: "sub-1", name: "Álgebra", code: "MAT-901", term: "2026-1",
                group_id: GroupManagement::GroupRoster::SECTION_9A_ID, group_name: "9°A"),
        Row.new(id: "sub-2", name: "Historia", code: "SOC-901", term: "2026-1",
                group_id: GroupManagement::GroupRoster::SECTION_9A_ID, group_name: "9°A"),
        Row.new(id: "sub-3", name: "Cálculo", code: "MAT-1001", term: "2026-1",
                group_id: GroupManagement::GroupRoster::SECTION_10A_ID, group_name: "10°A"),
        Row.new(id: "sub-4", name: "Sociología", code: "SOC-1101", term: "2026-1",
                group_id: GroupManagement::GroupRoster::SECTION_11B_ID, group_name: "11°B")
      ]
    end

    def self.find(id)
      all.find { |subject| subject.id == id.to_s }
    end
  end
end
