module Portals
  # Bandeja del acudiente — participation, same shared Communication::Inbox
  # computation the staff shell uses. No compose, no close/reopen: a
  # guardian may only reply (Portals::GuardianMessagesController), never
  # initiate or close a conversation (§0/§4). No authorize!, outside
  # Navigation::Registry.
  class GuardianInboxController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @rows = Communication::Inbox.call(institution: Current.institution, guardian_user: Current.user)
    end

    def show
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @conversation = find_conversation
      @participant = find_participant!
      @participant.update!(last_read_at: Time.current)
      @messages = @conversation.messages.order(:created_at)
    end

    private

    def find_conversation
      conversation = Communication::Conversation.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if conversation.nil?

      conversation
    end

    # Same confidentiality discipline as Communication::InboxController: a
    # non-participant guardian must 404, never render.
    def find_participant!
      participant = Communication::ConversationParticipant.find_by(institution_id: Current.institution_id,
        conversation_id: @conversation.id, guardian_user_id: Current.user.id)
      raise ActiveRecord::RecordNotFound if participant.nil?

      participant
    end
  end
end
