module Counseling
  # Fulfills the "Orientación" nav Fase 0 pre-wired (permission counseling.read)
  # — the README for this domain flags the gate as "planned, not yet
  # implemented"; this is that gate.
  class CasesController < ApplicationController
    def index
      authorize!("counseling.read")
      @cases = Counseling::CaseScope.new(context: authorization_context).resolve
    end

    def show
      @case = Counseling::CaseRoster.find(params[:id]) or raise ActiveRecord::RecordNotFound
      authorize!("counseling.read", @case)
    end
  end
end
