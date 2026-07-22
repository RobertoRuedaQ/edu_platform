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
      "conversation_audited"            => "Conversación auditada (lectura por no-participante)",
      # analytics_bi (v1.35.0): written every time a bi_auditor reads the
      # cross-tenant report (edu_bi_reader/BYPASSRLS) — see
      # AnalyticsBi::CrossTenantReportsController.
      "cross_tenant_report_accessed"    => "Reporte cross-tenant accedido",
      # analytics_bi (v1.39.0, BI_DOCUMENT.md Slice 5, §5.4 resguardo #6):
      # written every time an hps.character.moderate holder withholds a peer/
      # guardian appreciation — see AnalyticsBi::Character::Moderation. Moderation
      # is an append-only status flip, never a destroy.
      "peer_appreciation.withheld"      => "Aporte de par/acudiente retirado por moderación",
      # analytics_bi (v1.43.0, BI_DOCUMENT.md Slice 8, §5.6): written whenever
      # AnalyticsBi::FamilyCoresController#show actually surfaces a sibling
      # decline alert (never on a plain graph view with no alert to show) —
      # this is a sensitive cross-student signal ("es una señal para
      # intervención humana, no un veredicto"), so every real exposure of it
      # is auditable, same posture as cross_tenant_report_accessed.
      "family_core.sibling_alert_viewed" => "Alerta de lazos fraternales vista",
      # student_support (v1.45.0, guidelines/CLOSURE_PLAN.md §3.1/Fase B):
      # written every time a disciplinary_logs.manage holder records a new
      # convivencia/disciplinary incident — see StudentSupport::
      # DisciplinaryLogsController#create. Sensitive (Class S), append-only:
      # every write is traceable both by the record's own
      # reported_by_institution_user_id AND this audit trail.
      "disciplinary_log.recorded" => "Registro de convivencia/disciplina creado"
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
