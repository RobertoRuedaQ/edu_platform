module Schedules
  class GradeEntriesController < ApplicationController
    def new
      @subject = find_subject
      authorize!("grades.write", @subject)
    end

    # #4 barrido: unlike teacher.evaluate (no Evaluation model exists),
    # Schedules::Assessment already exists — so this persists for real
    # instead of staying gate-only.
    def create
      @subject = find_subject
      authorize!("grades.write", @subject)

      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, student_code: params[:student_id])
      if student.nil?
        @error = "No se encontró un estudiante con ese código en tu institución."
        return render :new, status: :unprocessable_entity
      end

      active_term = Core::AcademicTerm.active.find_by(institution_id: Current.institution_id)
      enrollment = Schedules::Enrollment.find_or_create_by!(institution: Current.institution, student: student,
        subject: @subject) { |e| e.term = @subject.term; e.academic_term = active_term }
      enrollment.assessments.create!(institution: Current.institution, kind: "parcial",
        title: params[:title], term: @subject.term, score: params[:score])

      redirect_to schedules_subject_path(@subject.id), notice: "Calificación registrada."
    end

    private

    def find_subject
      subject = Schedules::Subject.find_by(institution_id: Current.institution_id, id: params[:subject_id])
      raise ActiveRecord::RecordNotFound if subject.nil?

      subject
    end
  end
end
