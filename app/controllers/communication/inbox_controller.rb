module Communication
  # Bandeja — participation, NEVER authorize!. An actor sees ONLY the
  # conversations where they are a participant (Communication::Inbox, the
  # SAME computation the guardian portal inbox uses). Closing/reopening is
  # staff-only (a guardian participant never gets this action, per §4) but
  # still gated by "is a participant", not by any permission.
  class InboxController < ApplicationController
    def index
      @rows = Communication::Inbox.call(institution: Current.institution, institution_user: Current.institution_user)
    end

    def show
      @conversation = find_conversation
      @participant = find_participant!
      @participant.update!(last_read_at: Time.current)
      @messages = @conversation.messages.order(:created_at)
    end

    # Staff-only by construction, not by an extra check here: a guardian
    # participant's row is keyed by guardian_user_id, never
    # institution_user_id, so find_participant! (which filters by
    # Current.institution_user_id) 404s for them before reaching this line
    # — the same structural separation that keeps the guardian portal on its
    # own controller (Portals::GuardianInboxController) with no
    # close/reopen action defined at all (§4: "acudientes no cierran").
    def close
      @conversation = find_conversation
      find_participant!
      @conversation.close!(by_institution_user: Current.institution_user)
      redirect_to communication_inbox_path(@conversation), notice: "Conversación cerrada."
    end

    def reopen
      @conversation = find_conversation
      find_participant!
      @conversation.reopen!
      redirect_to communication_inbox_path(@conversation), notice: "Conversación reabierta."
    end

    private

    def find_conversation
      conversation = Communication::Conversation.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if conversation.nil?

      conversation
    end

    # Confidentiality: a non-participant (even one with conversation.audit)
    # must 404 here, never render — see Communication::ConversationAuditsController
    # for the SEPARATE, RBAC-gated route non-participants use instead.
    def find_participant!
      participant = Communication::ConversationParticipant.find_by(institution_id: Current.institution_id,
        conversation_id: @conversation.id, institution_user_id: Current.institution_user_id)
      raise ActiveRecord::RecordNotFound if participant.nil?

      participant
    end
  end
end
