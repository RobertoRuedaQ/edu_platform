# Completes an invitation-based account (registro por invitación — nobody
# self-registers). Reachable only via the tenant-subdomain link the
# invitation email sends: the tenant resolves through the SAME mechanism as
# login (TenantScoped, by subdomain), so by the time the token is looked up
# here, RLS already scopes `invitations` to the right institution. No
# BYPASSRLS, no token-encoded institution_id needed.
class InvitationsController < ApplicationController
  allow_unauthenticated_access only: %i[edit update discrepancy]

  rate_limit to: 10, within: 3.minutes, only: %i[update discrepancy],
    with: -> { redirect_to edit_invitation_path(params[:token]), alert: "Demasiados intentos. Intenta de nuevo más tarde." }

  layout "auth"

  before_action :require_tenant
  before_action :load_invitation
  before_action :require_usable_invitation

  def edit
  end

  def update
    result = IdentityAccess::Invitations::Completer.call(
      invitation: @invitation, password: params[:password], password_confirmation: params[:password_confirmation]
    )
    result.success? ? complete(result.user) : reject
  end

  def discrepancy
    IdentityAccess::Invitations::DiscrepancyReporter.call(invitation: @invitation, message: params[:message])
    redirect_to edit_invitation_path(params[:token]), notice: "Reportamos la discrepancia a la institución."
  end

  private

  def require_tenant
    return if Current.institution

    redirect_to new_session_path, alert: "Abre el enlace desde tu correo de invitación."
  end

  def load_invitation
    return unless Current.institution

    @invitation = IdentityAccess::Invitation.find_by(token_digest: token_digest)
  end

  def token_digest
    Digest::SHA256.hexdigest(params[:token].to_s)
  end

  def require_usable_invitation
    render :invalid, status: :unprocessable_entity if Current.institution && @invitation&.usable? != true
  end

  def complete(user)
    start_new_session_for(user, institution: Current.institution)
    redirect_to root_path, notice: "Tu cuenta quedó activa."
  end

  def reject
    flash.now[:alert] = "No pudimos guardar tu contraseña. Verifica los requisitos e intenta de nuevo."
    render :edit, status: :unprocessable_entity
  end
end
