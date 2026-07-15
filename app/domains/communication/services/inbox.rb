module Communication
  # THE single "my bandeja" computation — participation, not RBAC (no
  # authorize!, no permission). Shared by the staff inbox and the guardian
  # portal inbox (same pattern as AnnouncementFeed, v1.19.0): one query,
  # N surfaces, so they can never disagree on which conversations show or
  # how many are unread.
  module Inbox
    Row = Data.define(:conversation, :participant, :unread_count)
    module_function

    def call(institution:, institution_user: nil, guardian_user: nil)
      scope = ConversationParticipant.where(institution_id: institution.id)
      scope = institution_user ? scope.where(institution_user_id: institution_user.id) : scope.where(guardian_user_id: guardian_user.id)

      scope.includes(:conversation).map do |participant|
        Row.new(conversation: participant.conversation, participant: participant,
          unread_count: unread_count_for(participant))
      end.sort_by { |row| row.conversation.updated_at }.reverse
    end

    # A message counts as unread when it arrived after this participant's
    # last_read_at AND wasn't sent by this participant themself. Written as
    # explicit "IS NULL OR != " (not where.not) so a message from the OTHER
    # identity kind (guardian_user_id NULL for a staff-sent message, and vice
    # versa) is never accidentally excluded by a NULL-comparison trap.
    def unread_count_for(participant)
      since = participant.last_read_at || participant.conversation.created_at
      scope = participant.conversation.messages.where("created_at > ?", since)
      if participant.institution_user_id
        scope.where("institution_user_id IS NULL OR institution_user_id != ?", participant.institution_user_id).count
      else
        scope.where("guardian_user_id IS NULL OR guardian_user_id != ?", participant.guardian_user_id).count
      end
    end
  end
end
