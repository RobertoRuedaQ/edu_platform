module StudentSupport
  # Two tiers of the SAME resource: medical_history.view (full record — the
  # owner, medical_staff) and medical_history.view_summary (allergies/
  # contraindications only — counselor). authorize! only takes one permission
  # key, so this tries the wider grant first and falls back to the narrower
  # one; if NEITHER matches, it still raises via authorize! (the same hard
  # gate, same 403) — can? here decides WHICH tier renders, it never is the
  # last word on whether access is granted at all.
  class MedicalHistoryController < ApplicationController
    def show
      @record = StudentSupport::MedicalHistoryRoster.find_by_student(params[:student_id]) or
        raise ActiveRecord::RecordNotFound

      if authorization_context.can?("medical_history.view", @record)
        @tier = :full
      elsif authorization_context.can?("medical_history.view_summary", @record)
        @tier = :summary
      else
        authorize!("medical_history.view", @record) # no grant matches -> raises -> 403
      end
    end
  end
end
