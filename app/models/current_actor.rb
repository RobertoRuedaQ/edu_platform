# STUB presenter of the signed-in person, for the shell only (header identity +
# the institution switcher). No auth/session is wired yet, so this is hardcoded
# with TWO institutions so the switcher is actually exercised.
#
# TODO: reemplazar por el usuario autenticado real (Core::User + memberships).
class CurrentActor
  Institution = Data.define(:id, :name)

  def name
    "Docente de prueba"
  end

  # Real data source: Core::User#memberships -> institutions.
  def institutions
    [
      Institution.new(id: "stub-inst-1", name: "Colegio San Martín"),
      Institution.new(id: "stub-inst-2", name: "Instituto Andes")
    ]
  end

  def current_institution
    institutions.first
  end

  def multiple_institutions?
    institutions.size > 1
  end
end
