module IdentityAccess
  # Idempotent upsert of the GLOBAL permission catalog. Capabilities are defined
  # in code (not per-tenant); roles reference them. Run from db/seeds or a task.
  class SeedPermissions
    CATALOG = {
      "students.read"     => "Ver estudiantes",
      "students.write"    => "Crear/editar estudiantes",
      "grades.read"       => "Ver calificaciones",
      "grades.write"      => "Registrar calificaciones",
      "staff.read"        => "Ver personal",
      "staff.write"       => "Gestionar personal",
      "teachers.view"     => "Ver docentes",
      "teacher.evaluate"  => "Evaluar docentes",
      "departments.view"  => "Ver departamentos/áreas",
      "finance.read"      => "Ver cartera y pagos",
      "finance.write"     => "Registrar cargos y pagos",
      "counseling.read"   => "Ver orientación (confidencial)",
      "counseling.write"  => "Registrar notas de orientación",
      "roles.manage"      => "Administrar roles y asignaciones"
    }.freeze

    def self.call
      CATALOG.each do |key, description|
        record = Permission.find_or_initialize_by(key: key)
        record.update!(description: description)
      end
    end
  end
end
