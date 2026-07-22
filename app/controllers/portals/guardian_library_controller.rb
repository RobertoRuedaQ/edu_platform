module Portals
  # Resolved by relation (Core::Access::GuardianScope), no authorize! — same
  # discipline as GuardianCafeteriaController. Summarizes ALL children on one
  # page (molde cafeteria/transport, not finance's per-child nesting — a
  # handful of current loans per child is light content).
  class GuardianLibraryController < ApplicationController
    layout "portal"

    def show
      @children = Core::Access::GuardianScope.for(Current.user)
      @loans_by_child = @children.index_with do |child|
        Library::Loan.where(institution_id: Current.institution_id, borrower_student_id: child.id)
          .order(borrowed_at: :desc)
      end
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
    end
  end
end
