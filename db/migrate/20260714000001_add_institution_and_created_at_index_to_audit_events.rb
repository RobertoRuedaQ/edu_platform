class AddInstitutionAndCreatedAtIndexToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # audit_events is append-only and grows without bound. Neither existing
    # index (institution+action, institution+target) supports an
    # institution-scoped read ordered by created_at — the shape the audit
    # viewer/discrepancy inbox actually query (AV6). Without this, a paginated
    # "newest first" listing degrades to a full-table sort per page as the log
    # grows.
    add_index :audit_events, %i[institution_id created_at],
      name: "index_audit_events_on_institution_and_created_at", order: { created_at: :desc }
  end
end
