module GroupManagement
  # STUB roster of groups (sections). Real Section/GradeLevel rows exist and
  # are seeded, but reading them requires a resolved tenant (TenantScoped is
  # only wired into ControlPlane::BaseController today) — so this phase stays
  # on the same self-contained stub convention as every other domain, using
  # the SAME canonical section ids the Fase 0 demo persona and
  # teacher_management's roster already reference (stub-section-9a/10a/11b).
  #
  # TODO: reemplazar por GroupManagement::Section real + GradeLevel una vez
  # que haya contexto de tenant resuelto por request.
  module GroupRoster
    # group_id aliases id: a group/section IS the scoped resource, so
    # Authorization::Assignment#covers? reads group_id like any other
    # group-scoped resource (see Authorization::Assignment::SCOPE_READERS).
    Row = Data.define(:id, :name, :grade_level_name, :academic_year,
                       :homeroom_teacher_name, :schedule_summary) do
      def group_id
        id
      end
    end

    def self.all
      [
        Row.new(id: "stub-section-9a", name: "9°A", grade_level_name: "Grado 9",
                academic_year: 2026, homeroom_teacher_name: "Ana Sofía Beltrán",
                schedule_summary: "Lun-Vie 6:30-14:00"),
        Row.new(id: "stub-section-10a", name: "10°A", grade_level_name: "Grado 10",
                academic_year: 2026, homeroom_teacher_name: "María Fernanda Ríos",
                schedule_summary: "Lun-Vie 6:30-14:20"),
        Row.new(id: "stub-section-11b", name: "11°B", grade_level_name: "Grado 11",
                academic_year: 2026, homeroom_teacher_name: "Laura Gómez Duarte",
                schedule_summary: "Lun-Vie 6:30-14:40")
      ]
    end

    def self.find(id)
      all.find { |group| group.id == id.to_s }
    end
  end
end
