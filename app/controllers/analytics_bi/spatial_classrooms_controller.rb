module AnalyticsBi
  # Lens 1 — "Mapa de Empatía Espacial" (BI_DOCUMENT.md §4/§9, Slice 2). A
  # SUPERVISION surface (molde #4): authorize!("hps.classroom.view") at the top
  # of every action, then a scoped Query object / read-model does the work.
  # can? is only cosmetic in the views. analytics_bi only READS the
  # group_management-owned classroom tables here (decision A2).
  class SpatialClassroomsController < ApplicationController
    def index
      authorize!("hps.classroom.view")
      @layouts = AnalyticsBi::Lens::SpatialClassroomScope.new(context: authorization_context).resolve
    end

    def show
      @section = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @section.nil?

      authorize!("hps.classroom.view", @section)
      @classroom = AnalyticsBi::Lens::SpatialClassroom.for(section: @section)
    end
  end
end
