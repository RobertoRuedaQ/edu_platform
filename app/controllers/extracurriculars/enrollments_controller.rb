module Extracurriculars
  # Inscribir/desinscribir desde SUPERVISIÓN (colegio) — la otra vía de
  # inscripción, junto con la del acudiente en el portal (decisión de diseño:
  # ambos pueden). Gate = activity.instruct (piso), y la PROPIEDAD la hace
  # cumplir ActivityScope: el coordinador (manage) opera sobre cualquier
  # actividad; el instructor solo sobre las suyas (una actividad ajena 404,
  # porque activity_scope.resolve.find no la encuentra — misma convención que
  # los portales: fuera de alcance es 404, no 403).
  class EnrollmentsController < ApplicationController
    def create
      authorize!("activity.instruct")
      activity = activity_scope.resolve.find(params[:activity_id])
      student = find_student(params[:student_id])

      Extracurriculars::EnrollmentCreator.call(
        institution: Current.institution, activity: activity, student: student,
        enrolled_via: "staff", enrolled_by_user: Current.user, idempotency_key: params[:idempotency_key]
      )
      redirect_to extracurriculars_activity_path(activity), notice: "Estudiante inscrito."
    rescue Extracurriculars::EnrollmentCreator::CapacityExceeded
      redirect_to extracurriculars_activity_path(params[:activity_id]),
        alert: "La actividad ya alcanzó su cupo."
    end

    def destroy
      authorize!("activity.instruct")
      activity = activity_scope.resolve.find(params[:activity_id])
      enrollment = Extracurriculars::Enrollment.find_by!(
        institution_id: Current.institution_id, activity_id: activity.id, id: params[:id]
      )

      Extracurriculars::EnrollmentWithdrawer.call(
        institution: Current.institution, activity: activity, student: enrollment.student
      )
      redirect_to extracurriculars_activity_path(activity), notice: "Inscripción retirada."
    end

    private

    def find_student(id)
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: id)
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    def activity_scope
      Extracurriculars::ActivityScope.new(context: authorization_context, actor_staff_member: actor_staff_member)
    end

    def actor_staff_member
      @actor_staff_member ||= StaffManagement::StaffMember.find_by(
        institution_id: Current.institution_id, institution_user_id: Current.institution_user_id
      )
    end
  end
end
