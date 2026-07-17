module Portals
  # Solo lectura: "mis actividades" (las inscripciones ACTIVAS del propio
  # estudiante). Sin authorize! — el gate es la RELACIÓN (StudentSelfScope),
  # como todo el portal (§7). La escritura (inscribir/desinscribir) es del
  # acudiente (GuardianActivityEnrollmentsController), no del estudiante:
  # decidir en qué se apunta un menor es responsabilidad del acudiente/colegio.
  class StudentActivitiesController < ApplicationController
    layout "portal"

    def index
      set_portal_header
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @enrollments = if @student
        Extracurriculars::StudentActivities.enrollments_for(@student)
      else
        Extracurriculars::Enrollment.none
      end
    end

    # #show narrowed a UNA inscripción propia — una actividad en la que el
    # estudiante NO está inscrito activo 404 (find_by! sobre su propio scope),
    # igual que no aparecería en #index.
    def show
      set_portal_header
      @student = Core::Access::StudentSelfScope.for(Current.user)
      raise ActiveRecord::RecordNotFound if @student.nil?

      @enrollment = Extracurriculars::Enrollment.active.find_by!(
        institution_id: Current.institution_id, student_id: @student.id, activity_id: params[:id]
      )
      @activity = @enrollment.activity
    end

    private

    def set_portal_header
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
    end
  end
end
