module Portals
  # Resolved by self-scope (Core::Access::StudentSelfScope), no authorize! —
  # same discipline as StudentAttendanceController/StudentCafeteriaController.
  class StudentLibraryController < ApplicationController
    layout "portal"

    def show
      @student = Core::Access::StudentSelfScope.for(Current.user)
      @loans = @student ? Library::Loan.where(institution_id: Current.institution_id,
        borrower_student_id: @student.id).order(borrowed_at: :desc) : Library::Loan.none
      @catalog = Library::Resource.where(institution_id: Current.institution_id).order(:title)
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
    end
  end
end
