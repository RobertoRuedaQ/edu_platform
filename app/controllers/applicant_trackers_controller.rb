# Tracker público de admisión (guidelines/library_prompt.md, Increment 3) —
# token-keyed, subdomain-scoped (molde exacto InvitationsController): sin
# sesión, sin RBAC. RLS + el filtro explícito por institution_id son el
# único portón — si Current.institution es nil (sin subdominio, o el
# subdominio equivocado), la fila simplemente no aparece y find_by! levanta
# RecordNotFound → 404 estándar, sin necesitar un before_action de tenant
# separado. Redacción de private_notes/evaluador vía Admissions::Tracker::
# PublicView (Data allowlist) — este controller NUNCA toca
# Admissions::Application directo en la vista.
class ApplicantTrackersController < ApplicationController
  allow_unauthenticated_access only: :show

  # El token de 256 bits ya hace el fuerza-bruta computacionalmente
  # inviable — el rate limit es defensa en profundidad, mismo criterio que
  # InvitationsController.
  rate_limit to: 30, within: 5.minutes, only: :show,
    with: -> { redirect_to root_path, alert: "Demasiados intentos. Intenta de nuevo más tarde." }

  layout "auth"

  def show
    application = Admissions::Application.find_by!(
      institution_id: Current.institution_id, tracker_token_digest: token_digest
    )
    @tracker = Admissions::Tracker::PublicView.for(application)
  end

  private

  def token_digest
    Digest::SHA256.hexdigest(params[:token].to_s)
  end
end
