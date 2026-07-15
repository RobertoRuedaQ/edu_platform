module IdentityAccess
  # Read-only, tenant-scoped, paginated index of audit_events. Backs BOTH the
  # audit viewer and the discrepancy inbox (AV3) — the inbox is this SAME
  # query with `action` forced to DISCREPANCY_ACTION, never a separate table
  # (DiscrepancyReporter already documents audit_events as the inbox).
  #
  # Filters are actor / action / date range ONLY, and action is drawn from a
  # KNOWN set (ACTIONS) rather than free text — this can never grow into a
  # search box over people (Habeas Data, AV5). No default_scope: institution_id
  # is explicit on every query; RLS is the backstop, not the only guard.
  class AuditEventIndex
    PER_PAGE = 25

    DISCREPANCY_ACTION = "invitation.discrepancy_reported"

    # The full, real set of actions ever written by IdentityAccess::Audit.log
    # — grepped across ALL domains (not just identity_access's own call
    # sites; v1.20.0 added communication's), not guessed. Adding a new call
    # site means adding its key here too, so the filter select never drifts
    # silently out of sync with what actually gets written.
    ACTIONS = {
      "invitation.sent"                 => "Invitación enviada",
      "invitation.bounced"              => "Invitación rebotada",
      "invitation.completed"            => "Invitación completada",
      DISCREPANCY_ACTION                => "Discrepancia reportada",
      "person.created"                  => "Persona creada",
      "person.suspended"                => "Persona suspendida",
      "person.reactivated"              => "Persona reactivada",
      "roster_import.validated"         => "Carga de roster validada",
      "roster_import.commit_enqueued"   => "Carga de roster aplicada",
      # communication (v1.20.0): written ONLY when a conversation.audit
      # holder reads a conversation they are NOT a participant of — a
      # participant reading their own conversation never writes this.
      "conversation_audited"            => "Conversación auditada (lectura por no-participante)"
    }.freeze

    Page = Data.define(:events, :page, :total_pages, :total_count)

    def self.call(...)
      new(...).call
    end

    def initialize(institution:, actor_institution_user_id: nil, action: nil, from: nil, to: nil, page: 1)
      @institution = institution
      @actor_institution_user_id = actor_institution_user_id.presence
      @action = action if ACTIONS.key?(action)
      @from = from
      @to = to
      @page = [ page.to_i, 1 ].max
    end

    def call
      return Page.new(events: [], page: 1, total_pages: 0, total_count: 0) if institution.nil?

      total_count = filtered_scope.count
      events = filtered_scope
        .order(created_at: :desc, id: :desc)
        .limit(PER_PAGE)
        .offset((page - 1) * PER_PAGE)
        .to_a

      Page.new(events: events, page: page, total_pages: total_pages_for(total_count), total_count: total_count)
    end

    private

    attr_reader :institution, :actor_institution_user_id, :action, :from, :to, :page

    def filtered_scope
      scope = AuditEvent.where(institution_id: institution.id)
      scope = scope.where(actor_institution_user_id: actor_institution_user_id) if actor_institution_user_id
      scope = scope.where(action: action) if action
      scope = scope.where(created_at: from.beginning_of_day..) if from
      scope = scope.where(created_at: ..to.end_of_day) if to
      scope
    end

    def total_pages_for(total_count)
      return 0 if total_count.zero?

      (total_count.to_f / PER_PAGE).ceil
    end
  end
end
