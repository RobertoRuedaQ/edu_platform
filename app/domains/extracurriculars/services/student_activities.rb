module Extracurriculars
  # EL camino de lectura del portal (relación, NUNCA RBAC) — consumido por el
  # portal del estudiante (solo lectura) y el del acudiente (lectura +
  # inscribir/desinscribir), mismo patrón una-computación-muchas-superficies
  # que Assignments::StudentView. Alcance = actividades PUBLICADAS del término
  # activo; jamás un buscador.
  module StudentActivities
    module_function

    # Actividades PUBLICADAS del término activo — el conjunto en el que el
    # estudiante PUEDE estar/inscribirse. Es EL gate de escritura del portal:
    # el controller resuelve la actividad por aquí (.find) antes de llamar al
    # EnrollmentCreator, nunca por params directo. Una actividad draft/archived
    # o de otro término es inalcanzable gratis (no está en este scope).
    def enrollable(student, institution: Current.institution)
      active_term = Core::AcademicTerm.active.find_by(institution_id: institution.id)
      return Extracurriculars::Activity.none if active_term.nil?

      Extracurriculars::Activity.published
        .where(institution_id: institution.id, academic_term_id: active_term.id)
        .includes(:instructor_staff_member)
        .order(:name)
    end

    # Las inscripciones ACTIVAS del estudiante (con su actividad), para mostrar
    # "mis actividades". withdrawn nunca aparece: es historial.
    def enrollments_for(student, institution: Current.institution)
      Extracurriculars::Enrollment.active
        .where(institution_id: institution.id, student_id: student.id)
        .includes(activity: :instructor_staff_member)
        .order(enrolled_at: :desc)
    end

    # La inscripción activa del estudiante en ESTA actividad (o nil) — para
    # marcar "ya inscrito" en la vista y para resolver la baja.
    def active_enrollment_for(activity, student, institution: Current.institution)
      Extracurriculars::Enrollment.active.find_by(
        institution_id: institution.id, activity_id: activity.id, student_id: student.id
      )
    end
  end
end
