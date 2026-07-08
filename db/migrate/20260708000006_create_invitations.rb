class CreateInvitations < ActiveRecord::Migration[8.1]
  # BREADCRUMB (not designed here): invitation acceptance happens BEFORE the
  # visitor has a tenant context, so this table's RLS policy will hide the row
  # from an unauthenticated request. The later Invitations::Completer service
  # must provide a tenant-less lookup path (the token has to carry or resolve
  # institution_id). Do not build that seam in this schema pass.
  def change
    create_table :invitations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }

      t.string :email, null: false           # snapshot at issue time
      t.string :token_digest                  # digest only, never the raw token
      t.string :status, null: false, default: "sent"

      t.datetime :expires_at, null: false
      t.datetime :sent_at,    null: false
      t.datetime :completed_at

      t.references :created_by, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }

      t.timestamps
    end

    # At most one LIVE (sent) invitation per person per tenant.
    add_index :invitations, %i[institution_id user_id], unique: true,
      where: "status = 'sent'", name: "index_invitations_one_live_per_user"

    # Digest lookup + collision safety (partial: rows may exist pre-token).
    add_index :invitations, :token_digest, unique: true,
      where: "token_digest IS NOT NULL", name: "index_invitations_on_token_digest"

    add_check_constraint :invitations,
      "status IN ('sent','completed','expired','bounced')",
      name: "invitations_status_check"

    enable_rls :invitations
  end
end
