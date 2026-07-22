module StudentSupport
  # accommodations.view (read — counselor/coordinator/homeroom) is narrower
  # than accommodations.manage (write — counselor/coordinator only). Scope is
  # the student's own group; authorize! checks it against the student/
  # accommodation directly (both delegate group_id to GroupManagement::Student
  # — group_management owns the Student resource, not this domain).
  #
  # REAL since guidelines/CLOSURE_PLAN.md Fase D — StudentSupport::
  # Accommodation replaces the AccommodationRoster stub (#update was a
  # literal no-op). new/create added here too: the stub never had a way to
  # CREATE an accommodation at all (only 3 hardcoded fake rows existed),
  # which would have left this feature permanently inoperable the same way
  # Core::AcademicTerm was before v1.44.0 — same fix, same reasoning.
  class AccommodationsController < ApplicationController
    def index
      @student = find_student
      authorize!("accommodations.view", @student)
      @accommodations = StudentSupport::Accommodation
        .where(institution_id: Current.institution_id, student_id: @student.id)
        .order(created_at: :desc)
    end

    def new
      @student = find_student
      authorize!("accommodations.manage", @student)
      @accommodation = StudentSupport::Accommodation.new
    end

    def create
      @student = find_student
      authorize!("accommodations.manage", @student)
      @accommodation = StudentSupport::Accommodation.new(accommodation_params.merge(
        institution_id: Current.institution_id, student: @student, authorized_by: Current.institution_user
      ))
      if @accommodation.save
        redirect_to student_support_student_accommodations_path(@student.id), notice: "Acomodación creada."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @accommodation = find_accommodation
      authorize!("accommodations.manage", @accommodation)
    end

    def update
      @accommodation = find_accommodation
      authorize!("accommodations.manage", @accommodation)

      if @accommodation.update(update_params)
        redirect_to student_support_student_accommodations_path(params[:student_id]), notice: "Acomodación actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def find_student
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    def find_accommodation
      accommodation = StudentSupport::Accommodation.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if accommodation.nil?

      accommodation
    end

    def accommodation_params
      params.require(:accommodation).permit(:kind, :description)
    end

    # update only ever edits the description (matches the pre-existing edit
    # form) — kind/status changes are a bigger product decision (should
    # changing kind after creation be allowed? should there be an explicit
    # "expire" action?) deliberately left for a future increment.
    def update_params
      params.require(:accommodation).permit(:description)
    end
  end
end
