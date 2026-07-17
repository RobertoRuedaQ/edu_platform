module Portals
  # Lectura de las actividades de UN hijo del acudiente + el catálogo
  # inscribible. Ambas acciones resuelven params[:student_id] por
  # Core::Access::GuardianScope (un hijo fuera del scope 404, nunca
  # GroupManagement::Student.find directo). Sin authorize! — la relación ES el
  # gate (§7). La escritura vive en GuardianActivityEnrollmentsController.
  class GuardianActivitiesController < ApplicationController
    layout "portal"

    def index
      set_portal_header
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      @enrollments = Extracurriculars::StudentActivities.enrollments_for(@student)
      @available = available_activities(@student)
      @idempotency_key = SecureRandom.uuid
    end

    def show
      set_portal_header
      @student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      # Resuelta por el MISMO scope inscribible que gatea la escritura — una
      # actividad draft/archived o de otro término 404 gratis.
      @activity = Extracurriculars::StudentActivities.enrollable(@student).find(params[:id])
      @enrollment = Extracurriculars::StudentActivities.active_enrollment_for(@activity, @student)
      @idempotency_key = SecureRandom.uuid
    end

    private

    # Lo inscribible que el hijo AÚN no tiene activo (para ofrecer "inscribir").
    def available_activities(student)
      enrolled_ids = Extracurriculars::StudentActivities.enrollments_for(student).map(&:activity_id)
      Extracurriculars::StudentActivities.enrollable(student).reject { |a| enrolled_ids.include?(a.id) }
    end

    def set_portal_header
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
    end
  end
end
