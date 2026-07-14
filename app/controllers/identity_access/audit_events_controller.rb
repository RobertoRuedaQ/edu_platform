module IdentityAccess
  # Admin surface — RBAC-gated (authorize!), the opposite of the identity-gated
  # self-service/portal surfaces (v1.9.0/v1.10.0). audit_events is append-only:
  # this controller only ever reads (no update/create/destroy action exists
  # here at all).
  class AuditEventsController < ApplicationController
    def index
      authorize!("audit_events.read")
      @page = AuditEventIndex.call(institution: Current.institution, page: params[:page], **filter_params)
      @actor_options = actor_options
    end

    # The discrepancy inbox (AV3): same query, action forced to the reporter's
    # marker — not a separate table, not a separate permission.
    def discrepancies
      authorize!("audit_events.read")
      @page = AuditEventIndex.call(institution: Current.institution, page: params[:page],
        action: AuditEventIndex::DISCREPANCY_ACTION)
      render :discrepancies
    end

    private

    # Actor filter is a select over the institution's OWN staff (not a
    # student/person search box — Habeas Data is about not building a minor
    # directory, not about listing your own admins/teachers, same surface
    # already listed plainly on the "Personas" index).
    def actor_options
      Current.institution.memberships.active.includes(:user)
        .map { |iu| [ iu.user.name, iu.id ] }
        .sort_by(&:first)
    end

    def filter_params
      {
        actor_institution_user_id: params[:actor_institution_user_id].presence,
        action: params[:action_key].presence,
        from: parse_date(params[:from]),
        to: parse_date(params[:to])
      }
    end

    # Malformed input never errors the page (AV: "filtro sin resultados ->
    # empty state, no error") — an unparseable date is simply ignored.
    def parse_date(value)
      Date.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
