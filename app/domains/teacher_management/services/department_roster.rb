module TeacherManagement
  # STUB roster of academic departments/areas. Mirrors the teachers grouped in
  # TeacherRoster so area_lead scope checks have something real to filter.
  #
  # TODO: reemplazar por StaffManagement::Department real cuando esté poblado
  # (hoy la tabla departments existe pero no tiene datos semilla).
  module DepartmentRoster
    # Canonical department ids. Same rationale as GroupManagement::GroupRoster's
    # SECTION_*_ID constants: scope_department_id is a real `uuid` column (P1
    # made the ASSIGNMENT side real), so these must be UUID-shaped even though
    # the resource layer here is still the in-memory stub (backlog #4).
    MATEMATICAS_ID = "bbbbbbbb-0000-4000-8000-000000000001".freeze
    SOCIALES_ID    = "bbbbbbbb-0000-4000-8000-000000000002".freeze
    LENGUAJE_ID    = "bbbbbbbb-0000-4000-8000-000000000003".freeze

    # department_id aliases id: a department IS the scoped resource, so
    # Authorization::Assignment#covers? reads department_id like any other
    # department-scoped resource.
    Row = Data.define(:id, :name, :kind) do
      def department_id
        id
      end
    end

    def self.all
      [
        Row.new(id: MATEMATICAS_ID, name: "Matemáticas", kind: "academic"),
        Row.new(id: SOCIALES_ID, name: "Ciencias Sociales", kind: "academic"),
        Row.new(id: LENGUAJE_ID, name: "Lengua Castellana", kind: "academic")
      ]
    end

    def self.find(id)
      all.find { |department| department.id == id.to_s }
    end
  end
end
