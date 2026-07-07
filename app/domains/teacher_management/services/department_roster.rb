module TeacherManagement
  # STUB roster of academic departments/areas. Mirrors the teachers grouped in
  # TeacherRoster so area_lead scope checks have something real to filter.
  #
  # TODO: reemplazar por StaffManagement::Department real cuando esté poblado
  # (hoy la tabla departments existe pero no tiene datos semilla).
  module DepartmentRoster
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
        Row.new(id: "dept-matematicas", name: "Matemáticas", kind: "academic"),
        Row.new(id: "dept-sociales", name: "Ciencias Sociales", kind: "academic"),
        Row.new(id: "dept-lenguaje", name: "Lengua Castellana", kind: "academic")
      ]
    end

    def self.find(id)
      all.find { |department| department.id == id.to_s }
    end
  end
end
