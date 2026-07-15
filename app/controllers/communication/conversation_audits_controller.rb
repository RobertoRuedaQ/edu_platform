module Communication
  # The auditor's route — RBAC (conversation.audit), completely SEPARATE
  # from InboxController (participation). Reads ANY conversation in the
  # institution, not just ones the actor participates in. Read-only: no
  # reply action exists here (an auditor who is ALSO a participant replies
  # through the normal inbox, using their participant identity, not this
  # surface).
  #
  # Audit-log rule (§ Guardrails): a conversation_audited event is written
  # if and only if the accessor holds conversation.audit AND is NOT a
  # participant of the conversation being read. A participant who happens
  # to also hold conversation.audit reading their OWN conversation via THIS
  # route still counts as "their own" — no event, no different from reading
  # it through the inbox. The trail is never surfaced to participants; it
  # only ever appears in the RBAC-gated audit_events viewer (v1.11.0).
  class ConversationAuditsController < ApplicationController
    def index
      authorize!("conversation.audit")
      @conversations = Communication::Conversation.where(institution_id: Current.institution_id)
        .order(updated_at: :desc)
    end

    def show
      @conversation = find_conversation
      authorize!("conversation.audit", @conversation)
      @messages = @conversation.messages.order(:created_at)
      log_audit_if_not_participant!
    end

    private

    def find_conversation
      conversation = Communication::Conversation.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if conversation.nil?

      conversation
    end

    def log_audit_if_not_participant!
      is_participant = Communication::ConversationParticipant.exists?(institution_id: Current.institution_id,
        conversation_id: @conversation.id, institution_user_id: Current.institution_user_id)
      return if is_participant

      IdentityAccess::Audit.log(institution: Current.institution, action: "conversation_audited",
        actor_institution_user: Current.institution_user, target: @conversation)
    end
  end
end
