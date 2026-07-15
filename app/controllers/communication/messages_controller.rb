module Communication
  # Reply — participation, NEVER authorize!. Communication::MessageSender is
  # the real gate (must already be a participant of an ACTIVE conversation);
  # this controller only translates its result into a response.
  class MessagesController < ApplicationController
    def create
      # Confidentiality (§6): look up the conversation THROUGH the actor's
      # own participant row, never a bare institution-scoped find — a
      # non-participant must 404 here exactly like InboxController#show,
      # not merely fail later inside MessageSender with an existence-
      # revealing error.
      participant = Communication::ConversationParticipant.find_by(institution_id: Current.institution_id,
        conversation_id: params[:inbox_id], institution_user_id: Current.institution_user_id)
      raise ActiveRecord::RecordNotFound if participant.nil?

      conversation = participant.conversation
      result = Communication::MessageSender.call(institution: Current.institution, conversation: conversation,
        institution_user: Current.institution_user, body: params[:body])

      if result.message
        redirect_to communication_inbox_path(conversation), notice: "Mensaje enviado."
      else
        redirect_to communication_inbox_path(conversation), alert: error_message(result.error)
      end
    end

    private

    def error_message(error)
      case error
      when :not_participant then "No eres participante de esta conversación."
      when :closed then "La conversación está cerrada."
      else "No se pudo enviar el mensaje."
      end
    end
  end
end
