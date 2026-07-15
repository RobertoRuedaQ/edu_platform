module Communication
  # institution_user_id XOR guardian_user_id (DB CHECK enforces exactly-one
  # — see the migration). guardian_user_id points at Core::User directly,
  # same handle guardian_students.guardian_user_id uses — NOT
  # institution_user_id, even though a guardian also holds one of those
  # rows; the app-wide identity for "this person as a guardian" is always
  # the global user id.
  class ConversationParticipant < ApplicationRecord
    self.table_name = "conversation_participants"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :conversation, class_name: "Communication::Conversation", inverse_of: :participants
    belongs_to :institution_user, class_name: "Core::InstitutionUser", optional: true
    belongs_to :guardian_user, class_name: "Core::User", optional: true

    validate :exactly_one_identity

    def staff? = institution_user_id.present?
    def guardian? = guardian_user_id.present?

    def name
      staff? ? institution_user.user.name : guardian_user.name
    end

    private

    def exactly_one_identity
      return if [ institution_user_id, guardian_user_id ].compact.size == 1

      errors.add(:base, "debe tener exactamente un tipo de identidad (institution_user o guardian_user)")
    end
  end
end
