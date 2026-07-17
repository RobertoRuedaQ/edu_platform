module Portals
  # La ESCRITURA del portal del acudiente: inscribir/desinscribir a UN hijo ya
  # scopeado (B1 — el acudiente actúa en nombre del menor). Doble salto, misma
  # disciplina que GuardianSubmissionsController: GuardianScope resuelve el
  # ÚNICO hijo sobre el que puede actuar, y StudentActivities.enrollable
  # resuelve la ÚNICA actividad en la que puede inscribirlo (published + término
  # activo). Nunca se confía en params[:student_id]/[:activity_id] crudos.
  # enrolled_via: "guardian" + enrolled_by_user = el propio Core::User del
  # acudiente (atribución).
  class GuardianActivityEnrollmentsController < ApplicationController
    def create
      student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      activity = Extracurriculars::StudentActivities.enrollable(student).find(params[:activity_id])

      Extracurriculars::EnrollmentCreator.call(
        institution: Current.institution, activity: activity, student: student,
        enrolled_via: "guardian", enrolled_by_user: Current.user, idempotency_key: params[:idempotency_key]
      )
      redirect_to portal_guardian_student_activity_path(student, activity), notice: "Inscripción realizada."
    rescue Extracurriculars::EnrollmentCreator::CapacityExceeded
      redirect_to portal_guardian_student_activities_path(student), alert: "La actividad ya alcanzó su cupo."
    end

    def destroy
      student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      # La baja se resuelve por la inscripción ACTIVA propia del hijo (relación),
      # no por enrollable — así se puede retirar de una actividad ya archivada.
      enrollment = Extracurriculars::Enrollment.active.find_by!(
        institution_id: Current.institution_id, student_id: student.id, activity_id: params[:activity_id]
      )
      Extracurriculars::EnrollmentWithdrawer.call(
        institution: Current.institution, activity: enrollment.activity, student: student
      )
      redirect_to portal_guardian_student_activities_path(student), notice: "Inscripción retirada."
    end
  end
end
