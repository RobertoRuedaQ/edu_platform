module StaffManagement
  # STUB directory — StaffMember/Department tables are real but carry no seed
  # data (same gap found in teacher_management). Distinct from
  # TeacherManagement::TeacherRoster: these are the NON-teaching staff
  # categories (kitchen, transport, maintenance, security, admin).
  #
  # TODO: reemplazar por StaffManagement::StaffMember real cuando esté poblado.
  module StaffRoster
    Row = Data.define(:id, :name, :employee_number, :category, :employment_type, :status,
                       :department, :hire_date)

    def self.all
      [
        Row.new(id: "staff-1", name: "Rosa Elena Duarte", employee_number: "EMP-101",
                category: "kitchen", employment_type: "full_time", status: "active",
                department: "Cafetería", hire_date: Date.new(2019, 2, 1)),
        Row.new(id: "staff-2", name: "Pedro Sánchez", employee_number: "EMP-102",
                category: "transport", employment_type: "full_time", status: "active",
                department: "Transporte", hire_date: Date.new(2020, 8, 15)),
        Row.new(id: "staff-3", name: "Jorge Luis Peña", employee_number: "EMP-103",
                category: "maintenance", employment_type: "part_time", status: "active",
                department: "Mantenimiento", hire_date: Date.new(2021, 3, 10)),
        Row.new(id: "staff-4", name: "Diana Marcela Ríos", employee_number: "EMP-104",
                category: "security", employment_type: "full_time", status: "on_leave",
                department: "Seguridad", hire_date: Date.new(2018, 6, 1)),
        Row.new(id: "staff-5", name: "Andrés Felipe Gómez", employee_number: "EMP-105",
                category: "admin", employment_type: "full_time", status: "active",
                department: "Administración", hire_date: Date.new(2022, 1, 20))
      ]
    end
  end
end
