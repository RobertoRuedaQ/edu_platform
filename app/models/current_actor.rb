# Presenter of the signed-in person for the shell (header identity + the
# institution switcher). Wraps the REAL Current.user / Current.institution now
# that authentication is wired. Only rendered on authenticated shell pages, so
# Current.user is always present here (login/OTP pages use the `auth` layout).
class CurrentActor
  def initialize(user: Current.user, institution: Current.institution)
    @user = user
    @institution = institution
  end

  def name = @user.name

  # Under RLS the runtime connection only ever sees THIS tenant's membership,
  # and login already proved membership here — so the actor's institution set is
  # exactly the resolved current tenant. Cross-tenant switching is a separate,
  # deferred concern (institution_switches_controller stub).
  def institutions = @institution ? [ @institution ] : []

  def current_institution = @institution

  def multiple_institutions? = institutions.size > 1
end
