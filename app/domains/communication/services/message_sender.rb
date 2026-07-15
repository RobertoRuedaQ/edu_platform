module Communication
  # The reply gate — participation, NEVER authorize!. A sender must already
  # be a participant of an ACTIVE conversation; anyone else (including a
  # conversation.audit holder who is NOT a participant) is rejected here,
  # not merely hidden from a view.
  class MessageSender
    Result = Data.define(:message, :error)

    def self.call(institution:, conversation:, body:, institution_user: nil, guardian_user: nil)
      new(institution: institution, conversation: conversation, institution_user: institution_user,
        guardian_user: guardian_user, body: body).call
    end

    def initialize(institution:, conversation:, institution_user:, guardian_user:, body:)
      @institution = institution
      @conversation = conversation
      @institution_user = institution_user
      @guardian_user = guardian_user
      @body = body
    end

    def call
      return Result.new(message: nil, error: :not_participant) if participant.nil?
      return Result.new(message: nil, error: :closed) unless conversation.active?

      message = Message.create!(institution: institution, conversation: conversation,
        institution_user: institution_user, guardian_user: guardian_user, body: body)
      Result.new(message: message, error: nil)
    end

    private

    attr_reader :institution, :conversation, :institution_user, :guardian_user, :body

    def participant
      scope = ConversationParticipant.where(institution_id: institution.id, conversation_id: conversation.id)
      institution_user ? scope.find_by(institution_user_id: institution_user.id) : scope.find_by(guardian_user_id: guardian_user.id)
    end
  end
end
