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
      @subject = Schedules::SubjectRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("grades.read", @subject)
      @grades = Schedules::GradeEntryRoster.for_subject(@subject.id)
    end
  end
end
