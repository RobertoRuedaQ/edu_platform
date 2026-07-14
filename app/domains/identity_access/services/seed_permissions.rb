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
      "routes.view"       => "Ver rutas de transporte",
      "boarding.manage"   => "Registrar abordaje/descenso en una ruta",
      "counseling.read"   => "Ver orientación (confidencial)",
      "counseling.write"  => "Registrar notas de orientación",
      "medical_history.view"         => "Ver historia médica completa (personal médico)",
      "medical_history.view_summary" => "Ver solo alergias/contraindicaciones",
      "accommodations.view"    => "Ver acomodaciones/adaptaciones",
      "accommodations.manage"  => "Gestionar acomodaciones/adaptaciones",
      "disciplinary_logs.manage" => "Ver y registrar convivencia/disciplina",
      "support_dashboard.view"   => "Ver el tablero de bienestar estudiantil",
      "institution_dashboard.view" => "Ver KPIs de la propia institución",
      # SOLO bi_auditor. NUNCA sumar esta clave a institution_admin ni a
      # ningún rol de runtime normal — es el único camino cross-tenant
      # sancionado, y debe quedar auditado (ver edu_bi_reader en roles.rake).
      "cross_tenant_reports.view" => "Ver reportes cross-tenant (rol auditado BYPASSRLS)",
      "roles.manage"      => "Administrar roles y asignaciones",
      # Distinct from roles.manage: onboarding a human (crear/invitar/suspender
      # su cuenta) is not the same capability as granting institution_admin —
      # a registrar can do the former without the latter.
      "people.manage"     => "Crear personas, invitar y suspender/reactivar cuentas",
      # Gates the audit_events viewer + discrepancy inbox (RBAC-gated admin
      # surface — unlike self-service, which is identity-gated with no
      # authorize! at all). Read-only: audit_events is append-only regardless
      # of who holds this.
      "audit_events.read" => "Ver el registro de auditoría y discrepancias reportadas"
    }.freeze

    def self.call
      CATALOG.each do |key, description|
        record = Permission.find_or_initialize_by(key: key)
        record.update!(description: description)
      end
    end
  end
end
