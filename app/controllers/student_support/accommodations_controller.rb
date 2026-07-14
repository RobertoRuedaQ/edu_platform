module StudentSupport
  # accommodations.view (read — counselor/coordinator/homeroom) is narrower
  # than accommodations.manage (write — counselor/coordinator only). Scope is
  # the student's own group; authorize! checks it against the student (cross-
  # domain read of GroupManagement::StudentRoster — group_management owns the
  # Student resource, not this domain).
  class AccommodationsController < ApplicationController
    def index
      @student = find_student
      authorize!("accommodations.view", @student)
      @accommodations = StudentSupport::AccommodationRoster.for_student(@student.id)
    end

    def edit
      @accommodation = find_accommodation
      authorize!("accommodations.manage", @accommodation)
    end

    def update
      @accommodation = find_accommodation
      authorize!("accommodations.manage", @accommodation)

      # STUB: no persistence yet. TODO: reemplazar por UPDATE real.
      flash[:notice] = "Acomodación actualizada (stub)."
      redirect_to student_support_student_accommodations_path(params[:student_id])
    end

    private

    def find_student
      GroupManagement::StudentRoster.find(params[:student_id]) or raise ActiveRecord::RecordNotFound
    end

    def find_accommodation
      StudentSupport::AccommodationRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
    end
  end
end
