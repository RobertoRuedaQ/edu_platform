module GroupManagement
  # STUB roster of students, grouped into GroupRoster's sections. Same
  # rationale as GroupRoster: real Student rows exist and are seeded (with a
  # real section_id!) but reading them needs a resolved tenant, which is out
  # of scope for a views-only domain prompt.
  #
  # TODO: reemplazar por GroupManagement::Student real (ya tiene section_id
  # real, a diferencia de teachers -> department) una vez haya tenant resuelto.
  module StudentRoster
    Enrollment = Data.define(:subject, :term, :status)
    Row = Data.define(:id, :name, :student_code, :status, :group_id, :group_name,
                       :grade_level_name, :enrollments)

    def self.all
      [
        Row.new(id: "s-1", name: "Valentina Suárez", student_code: "COL-E-101", status: "active",
                group_id: "stub-section-9a", group_name: "9°A", grade_level_name: "Grado 9",
                enrollments: enrollments_for([ "Álgebra", "Lengua Castellana", "Biología" ])),
        Row.new(id: "s-2", name: "Santiago Rojas", student_code: "COL-E-102", status: "active",
                group_id: "stub-section-9a", group_name: "9°A", grade_level_name: "Grado 9",
                enrollments: enrollments_for([ "Álgebra", "Historia", "Biología" ])),
        Row.new(id: "s-3", name: "Isabella Mendoza", student_code: "COL-E-103", status: "inactive",
                group_id: "stub-section-9a", group_name: "9°A", grade_level_name: "Grado 9",
                enrollments: enrollments_for([ "Lengua Castellana" ])),
        Row.new(id: "s-4", name: "Mateo Cárdenas", student_code: "COL-E-104", status: "active",
                group_id: "stub-section-10a", group_name: "10°A", grade_level_name: "Grado 10",
                enrollments: enrollments_for([ "Cálculo", "Geografía", "Química" ])),
        Row.new(id: "s-5", name: "Camila Vargas", student_code: "COL-E-105", status: "active",
                group_id: "stub-section-10a", group_name: "10°A", grade_level_name: "Grado 10",
                enrollments: enrollments_for([ "Cálculo", "Sociología" ])),
        Row.new(id: "s-6", name: "Nicolás Herrera", student_code: "COL-E-106", status: "active",
                group_id: "stub-section-10a", group_name: "10°A", grade_level_name: "Grado 10",
                enrollments: enrollments_for([ "Química", "Geografía" ])),
        Row.new(id: "s-7", name: "Daniela Ortiz", student_code: "COL-E-107", status: "active",
                group_id: "stub-section-11b", group_name: "11°B", grade_level_name: "Grado 11",
                enrollments: enrollments_for([ "Sociología", "Literatura" ])),
        Row.new(id: "s-8", name: "Sebastián Molina", student_code: "COL-E-108", status: "active",
                group_id: "stub-section-11b", group_name: "11°B", grade_level_name: "Grado 11",
                enrollments: enrollments_for([ "Literatura", "Historia" ])),
        Row.new(id: "s-9", name: "Luciana Restrepo", student_code: "COL-E-109", status: "on_leave",
                group_id: "stub-section-11b", group_name: "11°B", grade_level_name: "Grado 11",
                enrollments: enrollments_for([ "Historia" ]))
      ]
    end

    def self.find(id)
      all.find { |student| student.id == id.to_s }
    end

    def self.for_group(group_id)
      all.select { |student| student.group_id == group_id }
    end

    def self.enrollments_for(subjects)
      subjects.map { |subject| Enrollment.new(subject: subject, term: "2026-1", status: "enrolled") }
    end
    private_class_method :enrollments_for
  end
end
