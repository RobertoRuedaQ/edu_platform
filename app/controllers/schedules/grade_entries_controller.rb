module Schedules
  class GradeEntriesController < ApplicationController
    def new
      @subject = find_subject
      authorize!("grades.write", @subject)
    end

    def create
      @subject = find_subject
      authorize!("grades.write", @subject)

      # STUB: no persistence yet. TODO: reemplazar por Schedules::Assessment real.
      flash[:notice] = "Calificación registrada (stub) para #{@subject.name}."
      redirect_to schedules_subject_path(@subject.id)
    end

    private

    def find_subject
      Schedules::SubjectRoster.find(params[:subject_id]) or raise ActiveRecord::RecordNotFound
    end
  end
end
