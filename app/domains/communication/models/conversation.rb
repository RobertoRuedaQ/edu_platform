module Communication
  # Multipart conversation — 2+ participants, everyone sees every message
  # (no hub-and-spoke fan-out this slice; that's a future composition helper
  # over this same base, see HISTORIA.md v1.20.0). Closing is SOFT
  # (status + closed_at/closed_by) — messages/participants are never
  # deleted.
  class Conversation < ApplicationRecord
    self.table_name = "conversations"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :created_by_institution_user, class_name: "Core::InstitutionUser", optional: true
    belongs_to :closed_by_institution_user, class_name: "Core::InstitutionUser", optional: true
    has_many :participants, class_name: "Communication::ConversationParticipant",
      foreign_key: :conversation_id, inverse_of: :conversation, dependent: :destroy
    has_many :messages, class_name: "Communication::Message",
      foreign_key: :conversation_id, inverse_of: :conversation, dependent: :destroy

    validates :subject, presence: true
    validates :status, inclusion: { in: %w[active closed] }

    scope :active, -> { where(status: "active") }
    scope :closed, -> { where(status: "closed") }

    def active? = status == "active"

    def close!(by_institution_user:)
      update!(status: "closed", closed_at: Time.current, closed_by_institution_user: by_institution_user)
    end

    def reopen!
      update!(status: "active", closed_at: nil, closed_by_institution_user: nil)
    end
  end
end
