module Communication
  # Creates a conversation + its participants + the first message, all in
  # ONE transaction. Recipients are RE-VALIDATED server-side against
  # Communication::ComposeRecipients — the bounded checklist a compose form
  # renders is a UI convenience, never the actual security boundary. A
  # tampered request selecting an out-of-scope guardian silently drops that
  # id here rather than trusting whatever the client posted.
  class ConversationComposer
    Result = Data.define(:conversation, :errors)

    def self.call(institution:, context:, creator_institution_user:, subject:, body:,
                   staff_user_ids: [], guardian_user_ids: [])
      new(institution: institution, context: context, creator_institution_user: creator_institution_user,
        subject: subject, body: body, staff_user_ids: staff_user_ids, guardian_user_ids: guardian_user_ids).call
    end

    def initialize(institution:, context:, creator_institution_user:, subject:, body:,
                    staff_user_ids:, guardian_user_ids:)
      @institution = institution
      @context = context
      @creator_institution_user = creator_institution_user
      @subject = subject
      @body = body
      @staff_user_ids = Array(staff_user_ids).map(&:to_s)
      @guardian_user_ids = Array(guardian_user_ids).map(&:to_s)
    end

    def call
      selected_staff_ids = staff_user_ids & allowed_staff_ids
      selected_guardian_ids = guardian_user_ids & allowed_guardian_ids

      if selected_staff_ids.empty? && selected_guardian_ids.empty?
        return Result.new(conversation: nil, errors: [ "Selecciona al menos un destinatario dentro de tu alcance." ])
      end

      conversation = nil
      Conversation.transaction do
        conversation = Conversation.create!(institution: institution, subject: subject, status: "active",
          created_by_institution_user: creator_institution_user)
        ConversationParticipant.create!(institution: institution, conversation: conversation,
          institution_user: creator_institution_user)

        selected_staff_ids.each { |user_id| add_staff_participant!(conversation, user_id) }
        selected_guardian_ids.each { |user_id| add_guardian_participant!(conversation, user_id) }

        Message.create!(institution: institution, conversation: conversation,
          institution_user: creator_institution_user, body: body)
      end

      Result.new(conversation: conversation, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(conversation: nil, errors: e.record.errors.full_messages)
    end

    private

    attr_reader :institution, :context, :creator_institution_user, :subject, :body,
      :staff_user_ids, :guardian_user_ids

    def recipients
      @recipients ||= Communication::ComposeRecipients.new(context: context, institution: institution)
    end

    def allowed_staff_ids
      @allowed_staff_ids ||= recipients.staff.map { |user| user.id.to_s }
    end

    def allowed_guardian_ids
      @allowed_guardian_ids ||= recipients.guardians.map { |user| user.id.to_s }
    end

    def add_staff_participant!(conversation, user_id)
      institution_user = institution.memberships.active.find_by(user_id: user_id)
      return if institution_user.nil? || institution_user.id == creator_institution_user.id

      ConversationParticipant.create!(institution: institution, conversation: conversation,
        institution_user: institution_user)
    end

    def add_guardian_participant!(conversation, user_id)
      ConversationParticipant.create!(institution: institution, conversation: conversation,
        guardian_user_id: user_id)
    end
  end
end
