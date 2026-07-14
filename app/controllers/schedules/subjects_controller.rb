module Schedules
  # Fulfills the "Calificaciones" nav Fase 0 pre-wired (permission grades.read)
  # and the courses#index/show Apéndice A had misassigned to core — the real
  # models (Subject/Enrollment/Assessment) live here.
  class SubjectsController < ApplicationController
    def index
      authorize!("grades.read")
      @subjects = Schedules::SubjectScope.new(context: authorization_context).resolve
    end

    def show
      @subject = Schedules::Subject.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @subject.nil?

      authorize!("grades.read", @subject)
      @enrollments = @subject.enrollments.includes(:student, :assessments).to_a
        .sort_by { |e| [ e.student.last_name, e.student.first_name ] }
    end
  end
end
