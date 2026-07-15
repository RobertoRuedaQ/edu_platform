module Portals
  # Reply-only — a guardian can respond in a conversation where they are a
  # participant, never initiate one (§0). Same confidentiality-first lookup
  # pattern as Communication::MessagesController: resolve THROUGH the
  # participant row, never a bare institution-scoped find.
  class GuardianMessagesController < ApplicationController
    def create
      participant = Communication::ConversationParticipant.find_by(institution_id: Current.institution_id,
        conversation_id: params[:inbox_id], guardian_user_id: Current.user.id)
      raise ActiveRecord::RecordNotFound if participant.nil?

      conversation = participant.conversation
      result = Communication::MessageSender.call(institution: Current.institution, conversation: conversation,
        guardian_user: Current.user, body: params[:body])

      if result.message
        redirect_to portal_guardian_inbox_path(conversation), notice: "Mensaje enviado."
      else
        redirect_to portal_guardian_inbox_path(conversation), alert: error_message(result.error)
      end
    end

    private

    def error_message(error)
      case error
      when :closed then "La conversación está cerrada."
      else "No se pudo enviar el mensaje."
      end
    end
  end
end
