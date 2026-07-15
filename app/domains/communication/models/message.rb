module Communication
  # institution_user_id XOR guardian_user_id, same discipline as
  # ConversationParticipant. "Sender must be a participant of the
  # conversation" is enforced by Communication::MessageSender (the service),
  # not here or at the DB — a cross-row invariant a model validation/CHECK
  # can't express without an extra query, which the service already runs.
  # touch: true on the conversation keeps Communication::Inbox's
  # most-recent-activity sort correct without extra bookkeeping.
  class Message < ApplicationRecord
    self.table_name = "messages"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :conversation, class_name: "Communication::Conversation", inverse_of: :messages, touch: true
    belongs_to :institution_user, class_name: "Core::InstitutionUser", optional: true
    belongs_to :guardian_user, class_name: "Core::User", optional: true

    validates :body, presence: true
    validate :exactly_one_identity

    def staff? = institution_user_id.present?
    def guardian? = guardian_user_id.present?

    def sender_name
      staff? ? institution_user.user.name : guardian_user.name
    end

    private

    def exactly_one_identity
      return if [ institution_user_id, guardian_user_id ].compact.size == 1

      errors.add(:base, "debe tener exactamente un tipo de identidad (institution_user o guardian_user)")
    end
  end
end
