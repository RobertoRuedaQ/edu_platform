module TeacherManagement
  # STUB roster of teachers with a department + groups attached.
  #
  # Neither linkage exists in real data yet: teachers.department_id does not
  # exist (only the unseeded staff_members.department_id, via the nullable
  # teachers.staff_member_id — no seeded teacher has one), and there is no
  # teacher-to-section/group model at all. Views/queries read this roster
  # instead so scope-aware filtering (department for authorize!/can?) is
  # actually exercised.
  #
  # TODO: reemplazar por TeacherManagement::Teacher -> StaffManagement::StaffMember
  # -> department real, y por el vínculo docente-grupo real cuando exista.
  module TeacherRoster
    Row = Data.define(:id, :name, :teacher_code, :department_id, :department_name,
                       :group_ids, :subjects, :qualifications, :status)

    def self.all
      [
        Row.new(id: "t-1", name: "María Fernanda Ríos", teacher_code: "COL-T-001",
                department_id: TeacherManagement::DepartmentRoster::MATEMATICAS_ID, department_name: "Matemáticas",
                group_ids: %w[stub-section-10a stub-section-11b],
                subjects: [ "Álgebra", "Cálculo" ],
                qualifications: [ "Lic. Matemáticas", "Maestría en Educación" ], status: "active"),
        Row.new(id: "t-2", name: "Carlos Andrés Peña", teacher_code: "COL-T-002",
                department_id: TeacherManagement::DepartmentRoster::MATEMATICAS_ID, department_name: "Matemáticas",
                group_ids: %w[stub-section-9a],
                subjects: [ "Geometría" ],
                qualifications: [ "Lic. Matemáticas" ], status: "active"),
        Row.new(id: "t-3", name: "Laura Gómez Duarte", teacher_code: "COL-T-003",
                department_id: TeacherManagement::DepartmentRoster::SOCIALES_ID, department_name: "Ciencias Sociales",
                group_ids: %w[stub-section-9a stub-section-10a],
                subjects: [ "Historia", "Geografía" ],
                qualifications: [ "Lic. Ciencias Sociales" ], status: "active"),
        Row.new(id: "t-4", name: "Jorge Iván Salas", teacher_code: "COL-T-004",
                department_id: TeacherManagement::DepartmentRoster::SOCIALES_ID, department_name: "Ciencias Sociales",
                group_ids: %w[stub-section-11b],
                subjects: [ "Sociología" ],
                qualifications: [ "Lic. Ciencias Sociales" ], status: "on_leave"),
        Row.new(id: "t-5", name: "Ana Sofía Beltrán", teacher_code: "COL-T-005",
                department_id: TeacherManagement::DepartmentRoster::LENGUAJE_ID, department_name: "Lengua Castellana",
                group_ids: %w[stub-section-9a],
                subjects: [ "Lengua Castellana" ],
                qualifications: [ "Lic. Literatura" ], status: "active")
      ]
    end

    def self.find(id)
      all.find { |teacher| teacher.id == id.to_s }
    end

    def self.for_department(department_id)
      all.select { |teacher| teacher.department_id == department_id }
    end
  end
end
