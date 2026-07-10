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
    # Canonical section ids, shared by every domain's roster that scopes a row
    # to a section (schedules, student_support, teacher_management) and by
    # real IdentityAccess::RoleAssignment rows seeded in tests (grant_role!) —
    # scope_group_id is a real `uuid` column (no FK), so these MUST be
    # UUID-shaped even though the resource layer is still an in-memory stub
    # (P1 only made the ASSIGNMENT side real; the resource layer conversion is
    # backlog #4). Kept greppable/deterministic rather than random so a test's
    # grant_role!(scope_id: ...) and a roster row's group_id always agree.
    SECTION_9A_ID  = "aaaaaaaa-0000-4000-8000-00000000009a".freeze
    SECTION_10A_ID = "aaaaaaaa-0000-4000-8000-0000000010a0".freeze
    SECTION_11B_ID = "aaaaaaaa-0000-4000-8000-0000000011b0".freeze

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
        Row.new(id: SECTION_9A_ID, name: "9°A", grade_level_name: "Grado 9",
                academic_year: 2026, homeroom_teacher_name: "Ana Sofía Beltrán",
                schedule_summary: "Lun-Vie 6:30-14:00"),
        Row.new(id: SECTION_10A_ID, name: "10°A", grade_level_name: "Grado 10",
                academic_year: 2026, homeroom_teacher_name: "María Fernanda Ríos",
                schedule_summary: "Lun-Vie 6:30-14:20"),
        Row.new(id: SECTION_11B_ID, name: "11°B", grade_level_name: "Grado 11",
                academic_year: 2026, homeroom_teacher_name: "Laura Gómez Duarte",
                schedule_summary: "Lun-Vie 6:30-14:40")
      ]
    end

    def self.find(id)
      all.find { |group| group.id == id.to_s }
    end
  end
end
