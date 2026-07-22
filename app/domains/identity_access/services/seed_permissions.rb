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
      "audit_events.read" => "Ver el registro de auditoría y discrepancias reportadas",
      # attendance (v1.16.0): daily-by-homeroom only. One permission covers
      # both taking attendance and viewing what was already taken — same
      # unified-permission call as disciplinary_logs.manage (no read/write
      # split like accommodations/medical_history, since there's no
      # confidentiality tier here).
      "attendance.record" => "Registrar y ver la asistencia de un grupo",
      # report_cards (v1.17.0): split view/publish, unlike attendance's single
      # permission — publicar un boletín es una acción distinta y más
      # sensible que solo previsualizarlo (más cerca del split de
      # accommodations.view/manage que de attendance.record).
      "report_card.view"    => "Ver boletines (previsualización y publicados)",
      "report_card.publish" => "Publicar boletines",
      # communication (v1.19.0), subsystem (A) anuncios only. One permission
      # (unlike report_card's split) — anyone who can publish can also edit/
      # retract, same unified-permission call as attendance.record. Leer NO
      # usa permiso: es una superficie de membresía (cualquier miembro activo
      # ve los anuncios publicados), no RBAC — ver Guardrails.
      "announcement.publish" => "Crear, editar y retractar anuncios",
      # communication (v1.20.0), subsistema (B) mensajería. Iniciar es RBAC
      # (compose); leer/responder la propia bandeja es participación, sin
      # permiso — ver Guardrails. Auditar es un permiso aparte, deliberada-
      # mente separado de compose: quien puede iniciar conversaciones NO
      # necesariamente puede leer las de otros (rector/institution_admin
      # solamente, nunca el super-admin de plataforma).
      "conversation.compose" => "Iniciar conversaciones con acudientes/estudiantes",
      "conversation.audit"   => "Leer cualquier conversación de la institución (deja rastro de auditoría)",
      # assignments (v1.21.0), slice 1/4. Un solo permiso cubre crear/editar/
      # publicar/archivar/calificar — mismo criterio unificado que
      # attendance.record (no hay nivel de confidencialidad que justifique
      # partirlo, a diferencia de report_card.view/publish). Ver la propia
      # tarea desde el portal NO usa permiso: es relación (StudentSelfScope/
      # GuardianScope), ver Guardrails.
      "assignment.manage" => "Crear, editar, publicar, archivar y calificar tareas",
      # extracurriculars (v1.27.0): split manage/instruct — pero NO por
      # confidencialidad (como report_card.view/publish) sino por ALCANCE de
      # PROPIEDAD. activity.manage es institución-wide (el coordinador ve/edita
      # TODO el catálogo e inscribe en cualquier actividad). activity.instruct
      # es el piso de acceso a la superficie Y el roster de las actividades
      # PROPIAS del instructor (activities.instructor_staff_member_id == su
      # StaffMember) — la propiedad se resuelve por FK en
      # Extracurriculars::ActivityScope, NO por un scope_type nuevo en
      # role_assignments/covers? (relación de identidad, no de jerarquía). El
      # rol activity_coordinator se siembra con AMBOS (manage + instruct): así
      # una sola tile de nav, gateada por instruct, sirve a los dos roles sin
      # duplicarla. Inscribir/desinscribir es de AMBAS vías (colegio y
      # acudiente); el acudiente lo hace por RELACIÓN en el portal, sin permiso.
      "activity.manage"   => "Gestionar todo el catálogo de extracurriculares e inscribir en cualquiera",
      "activity.instruct" => "Acceder a extracurriculares y gestionar el roster de las actividades propias",
      # calendar (v1.27.0): un solo permiso con scope (crear/editar/eliminar
      # eventos), mismo criterio unificado que attendance.record/assignment.
      # manage. El scope se ejerce eligiendo la audiencia del evento (grupo/
      # grado/institución-wide), que decide el resource pasado a authorize! —
      # ver Calendar::EventsController. Leer desde el portal NO usa permiso:
      # es relación (Calendar::VisibleScope/Timeline), ver Guardrails.
      "calendar.manage" => "Crear y gestionar eventos del calendario (con alcance)",
      # analytics_bi HPS Lens 1 (v1.36.0, BI_DOCUMENT.md Slice 2): "Mapa de
      # Empatía Espacial". SUPERVISION (RBAC + scope: section via :group /
      # :grade_level reader), same molde as attendance.record — one permission
      # to view the spatial map + heat overlay. hps.* is a NORMAL per-institution
      # permission (institution_admin inherits it via bootstrap, like every
      # other key EXCEPT cross_tenant_reports.view) — it is NOT cross-tenant.
      # Reconfiguring the layout itself is a WRITE gated by groups.manage
      # (group_management owns the tables, decision A2), not by this key.
      "hps.classroom.view" => "Ver el mapa espacial del aula (Lente 1 del HPS)",
      # analytics_bi HPS Lens 5 (v1.37.0, BI_DOCUMENT.md Slice 3): "Auras de
      # Cuidado", the TEACHER side of the two-sided permission split (§4). The
      # counselor side authoring the projection reuses the EXISTING
      # counseling.write ("Registrar notas de orientación") — no new write key.
      # This grants a teacher the ABSTRACT aura badge overlaid on the Lens 1
      # seat grid (aura_kind + guidance_text + dates ONLY) — never anything from
      # counseling's tables. SUPERVISION, scope group_id (same as
      # hps.classroom.view). hps.* is a NORMAL per-institution permission
      # (institution_admin inherits it via bootstrap, like every key EXCEPT
      # cross_tenant_reports.view) — it is NOT cross-tenant.
      "hps.aura.view" => "Ver auras de cuidado sobre el mapa del aula (Lente 5 del HPS, proyección abstracta)",
      # analytics_bi HPS T2 formativo (v1.39.0, BI_DOCUMENT.md Slice 5): the
      # character-evaluation instrument (§5.4). Two WRITE keys, split by ACTION
      # (author vs moderate), not by confidentiality:
      #   hps.character.author  — a docente/orientador creates/publishes character
      #     evaluations against a framework (AnalyticsBi::CharacterEvaluationsController,
      #     molde #4 supervision, scope group_id via the student's section).
      #   hps.character.moderate — moderates peer/guardian appreciations (flip to
      #     withheld_by_moderation, append-only + audited). This is ALSO the only
      #     key that may ever see giver attribution (§5.4 resguardo #3).
      # The ACT of a peer/guardian GIVING an appreciation is NOT gated by RBAC —
      # it's an identity action (co-membership + guardian consent, §4), handled by
      # AnalyticsBi::Character::PeerAppreciationRecorder, never an authorize!.
      # hps.* is a NORMAL per-institution permission (institution_admin inherits
      # it via bootstrap, like every key EXCEPT cross_tenant_reports.view) — it is
      # NOT cross-tenant.
      "hps.character.author"   => "Crear y publicar evaluaciones de carácter (Lente 2 del HPS, T2)",
      "hps.character.moderate" => "Moderar aportes de pares/acudientes (retirar y ver trazabilidad, auditado)",
      # analytics_bi HPS Lens 3 (v1.42.0, BI_DOCUMENT.md Slice 7): "Constelación de
      # Afinidades". Two keys, split by ACTION (view vs author), not by
      # confidentiality — the same read/write discipline the Lens-1 tests rely on
      # (hps.classroom.view never implies a write):
      #   hps.constellation.view — SUPERVISION (RBAC + scope): institución-wide
      #     (orientación/directivas) OR department_id (a specialist), resolved in
      #     AnalyticsBi::Lens::ConstellationScope via the EXISTING :department scope
      #     reader (no new scope_type). Views the transversal talent graph.
      #   hps.affinity.author — the MINIMAL teacher_observed tagging write
      #     (AnalyticsBi::StudentAffinitiesController, molde #4, scope group_id via
      #     the student's section). guardian_reported/self_reported authoring is a
      #     deferred portal slice. Mirrors hps.character.author exactly.
      # hps.* is a NORMAL per-institution permission (institution_admin inherits it
      # via bootstrap, like every key EXCEPT cross_tenant_reports.view) — NOT cross-tenant.
      "hps.constellation.view" => "Ver la constelación de afinidades (Lente 3 del HPS)",
      "hps.affinity.author"    => "Registrar afinidades observadas por el docente (Lente 3 del HPS, T2)"
    }.freeze

    def self.call
      CATALOG.each do |key, description|
        record = Permission.find_or_initialize_by(key: key)
        record.update!(description: description)
      end
    end
  end
end
