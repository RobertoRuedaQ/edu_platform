module Portals
  # The guardian's consent grant/revoke for a child's participation in the peer
  # path (BI_DOCUMENT.md §5.4 point 5 — deferred from Slice 5 to here). An
  # IDENTITY action for the guardian's OWN child (same class as
  # GuardianActivityEnrollmentsController), never an RBAC permission: the
  # GuardianScope resolution IS the gate — a child outside the caller's active
  # links 404s. AnalyticsBi::CharacterProgramConsent.grant!/.revoke! are both
  # idempotent and append-only (built + tested in Slice 5; not touched here), so
  # no idempotency key is needed — a double submit is a documented no-op.
  class GuardianCharacterConsentsController < ApplicationController
    def create
      student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      AnalyticsBi::CharacterProgramConsent.grant!(
        student: student, guardian_user: Current.user, institution: Current.institution
      )
      redirect_to portal_guardian_student_character_card_path(student), notice: "Autorización registrada."
    end

    def destroy
      student = Core::Access::GuardianScope.for(Current.user).find(params[:student_id])
      AnalyticsBi::CharacterProgramConsent.revoke!(student: student, institution: Current.institution)
      redirect_to portal_guardian_student_character_card_path(student), notice: "Autorización revocada."
    end
  end
end
