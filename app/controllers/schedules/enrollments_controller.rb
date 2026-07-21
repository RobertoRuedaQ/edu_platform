module Schedules
  # Deliberate "matricular estudiante" action — closes CLOSURE_PLAN §4.4: until
  # now Schedules::Enrollment only ever appeared as a side effect of
  # GradeEntriesController#create (find_or_create_by! on a student's FIRST
  # grade). Reuses that SAME idempotent creation call and the SAME
  # student_code lookup convention, just exposed on its own so staff can
  # enroll a student with no grade required. grades.write already implicitly
  # covers "can affect this subject's enrollment" (it already does, via the
  # grading side effect) — reused as-is, no new permission key.
  class EnrollmentsController < ApplicationController
    def create
      @subject = find_subject
      authorize!("grades.write", @subject)

      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, student_code: params[:student_id])
      if student.nil?
        @error = "No se encontró un estudiante con ese código en tu institución."
        return render_subject_with_error
      end

      active_term = Core::AcademicTerm.active.find_by(institution_id: Current.institution_id)
      enrollment = Schedules::Enrollment.find_or_create_by!(institution: Current.institution, student: student,
        subject: @subject) { |e| e.term = @subject.term; e.academic_term = active_term }

      notice = enrollment.previously_new_record? ? "Estudiante matriculado." : "Ya estaba matriculado."
      redirect_to schedules_subject_path(@subject), notice: notice
    end

    private

    def find_subject
      subject = Schedules::Subject.find_by(institution_id: Current.institution_id, id: params[:subject_id])
      raise ActiveRecord::RecordNotFound if subject.nil?

      subject
    end

    # Unknown student code: re-render the subject's own show page (where the
    # "Matricular estudiante" form lives) with the error, never a 500 — same
    # posture as GradeEntriesController's :new re-render.
    def render_subject_with_error
      @enrollments = @subject.enrollments.includes(:student, :assessments).to_a
        .sort_by { |e| [ e.student.last_name, e.student.first_name ] }
      render "schedules/subjects/show", status: :unprocessable_entity
    end
  end
end
