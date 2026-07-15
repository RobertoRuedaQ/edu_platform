module Communication
  # Compose — RBAC, a DIFFERENT gate from the participation-only inbox
  # (Communication::InboxController). Staff-initiated only this slice: a
  # guardian can reply (see Portals::GuardianMessagesController) but never
  # start a conversation here.
  class ConversationsController < ApplicationController
    def new
      authorize!("conversation.compose")
      @recipients = Communication::ComposeRecipients.new(context: authorization_context)
    end

    def create
      authorize!("conversation.compose")

      result = Communication::ConversationComposer.call(
        institution: Current.institution, context: authorization_context,
        creator_institution_user: Current.institution_user,
        subject: params[:subject], body: params[:body],
        staff_user_ids: Array(params[:staff_user_ids]), guardian_user_ids: Array(params[:guardian_user_ids])
      )

      if result.conversation
        redirect_to communication_inbox_path(result.conversation), notice: "Conversación iniciada."
      else
        @recipients = Communication::ComposeRecipients.new(context: authorization_context)
        @error = result.errors.join(", ")
        render :new, status: :unprocessable_entity
      end
    end
  end
end
