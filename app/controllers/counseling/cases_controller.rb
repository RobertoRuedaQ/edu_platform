module Counseling
  # Fulfills the "Orientación" nav Fase 0 pre-wired (permission counseling.read)
  # — the README for this domain long flagged the gate as "planned, not yet
  # implemented"; #4 barrido (v1.14.0) makes it real, against real Case rows.
  # Read-only: no note/referral creation exists here (no counseling.write in
  # the catalog) — same as before, unchanged by this slice.
  class CasesController < ApplicationController
    def index
      authorize!("counseling.read")
      @cases = Counseling::CaseScope.new(context: authorization_context).resolve
    end

    def show
      @case = Counseling::Case.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if @case.nil?

      authorize!("counseling.read", @case)
      @session_notes = @case.session_notes.order(occurred_at: :desc)
      @referrals = @case.referrals.order(created_at: :desc)
    end
  end
end
