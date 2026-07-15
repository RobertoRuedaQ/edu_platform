class CreateConversationsAndMessages < ActiveRecord::Migration[8.1]
  # communication (v1.20.0, item #5b of the MVP critical path) — subsystem
  # (B) messaging. Multipart conversations: 2+ participants, everyone in a
  # conversation sees every message (no hub-and-spoke fan-out this slice —
  # see HISTORIA.md v1.20.0). Plain messages, no threading
  # (parent_message_id deferred, additive when built).
  def change
    create_table :conversations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :subject, null: false
      t.string :status, null: false, default: "active"
      # Attribution only (nullable + nullify, same convention as
      # announcements.author_institution_user_id) — the conversation and its
      # participants/messages survive independent of who created/closed it.
      t.references :created_by_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }
      t.datetime :closed_at
      t.references :closed_by_institution_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :nullify }

      t.timestamps
    end
    add_index :conversations, %i[institution_id status], name: "index_conversations_on_institution_and_status"
    add_check_constraint :conversations, "status IN ('active','closed')", name: "conversations_status_check"
    enable_rls :conversations

    # Participant = institution_user (staff) OR guardian_user (a Core::User,
    # same guardian_user_id convention as guardian_students — NOT
    # institution_user_id, even though a guardian technically also holds an
    # institution_users row; the app-wide handle for "this person AS a
    # guardian" is always the global user id). Exactly one of the two is set
    # — enforced by a real CHECK (num_nonnulls), not just app validation.
    # CASCADE (not nullify) on both identity columns: unlike attribution
    # columns above, a participant row with NEITHER identity set would
    # violate the CHECK, so the identity itself must go if the person does
    # (same convention guardian_students already uses on guardian_user_id).
    create_table :conversation_participants, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :conversation, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :institution_user, type: :uuid, null: true, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :guardian_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :cascade }
      t.datetime :last_read_at

      t.timestamps
    end
    add_index :conversation_participants, %i[institution_id conversation_id institution_user_id],
      unique: true, name: "idx_participants_unique_institution_user"
    add_index :conversation_participants, %i[institution_id conversation_id guardian_user_id],
      unique: true, name: "idx_participants_unique_guardian_user"
    add_index :conversation_participants, %i[institution_id institution_user_id],
      name: "idx_participants_on_institution_user"
    add_index :conversation_participants, %i[institution_id guardian_user_id],
      name: "idx_participants_on_guardian_user"
    add_check_constraint :conversation_participants,
      "num_nonnulls(institution_user_id, guardian_user_id) = 1",
      name: "conversation_participants_identity_check"
    enable_rls :conversation_participants

    # Sender = institution_user OR guardian_user, same exactly-one discipline.
    # "Sender must be a participant of the conversation" is a cross-row
    # invariant a CHECK can't express cleanly — enforced by
    # Communication::MessageSender, not the DB.
    create_table :messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :conversation, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :institution_user, type: :uuid, null: true, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :guardian_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :cascade }
      t.text :body, null: false

      t.timestamps
    end
    add_index :messages, %i[institution_id conversation_id created_at], name: "idx_messages_on_conversation_and_time"
    add_check_constraint :messages, "num_nonnulls(institution_user_id, guardian_user_id) = 1",
      name: "messages_sender_identity_check"
    enable_rls :messages
  end
end
