module IdentityAccess
  # Idempotent upsert of the GLOBAL permission catalog. Capabilities are defined
  # in code (not per-tenant); roles reference them. Run from db/seeds or a task.
  class SeedPermissions
    CATALOG = {
      "students.read"     => "Ver estudiantes",
      "students.write"    => "Crear/editar estudiantes",
      "groups.view"       => "Ver grupos/secciones",
      "groups.manage"     => "Gestionar matrícula de un grupo",
      "grades.read"       => "Ver calificaciones",
      "grades.write"      => "Registrar calificaciones",
      "schedule.view"     => "Ver el horario propio",
      "timetable.manage"  => "Construir/ver el horario institucional",
      "rooms.view"        => "Ver salones",
      "staff.read"        => "Ver personal",
      "staff.write"       => "Gestionar personal",
      "teachers.view"     => "Ver docentes",
      "teacher.evaluate"  => "Evaluar docentes",
      "departments.view"  => "Ver departamentos/áreas",
      "finance.read"      => "Ver cartera y pagos",
      "finance.write"     => "Registrar cargos y pagos",
      "menu.view"         => "Ver el menú de cafetería",
      "checkout.manage"   => "Registrar compras en cafetería",
      "counseling.read"   => "Ver orientación (confidencial)",
      "counseling.write"  => "Registrar notas de orientación",
      "medical_history.view"         => "Ver historia médica completa (personal médico)",
      "medical_history.view_summary" => "Ver solo alergias/contraindicaciones",
      "accommodations.view"    => "Ver acomodaciones/adaptaciones",
      "accommodations.manage"  => "Gestionar acomodaciones/adaptaciones",
      "disciplinary_logs.manage" => "Ver y registrar convivencia/disciplina",
      "support_dashboard.view"   => "Ver el tablero de bienestar estudiantil",
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
