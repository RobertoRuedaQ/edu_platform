class InstitutionSwitchesController < ApplicationController
  # Institution switcher target. STUB: no session/tenant persistence is wired yet,
  # so it just acknowledges and returns. The real version will set the tenant on
  # the session (conceptually app.current_institution_id) and re-scope the view.
  # TODO: persistir la institución activa en la sesión del usuario autenticado.
  def create
    flash[:notice] = "Cambio de institución pendiente (stub)."
    redirect_back fallback_location: search_path
  end
end
