module Admissions
  # Molde exacto Library::LoanScope — institución-wide (admisiones no tiene
  # dimensión de departamento/grupo propia), real relation + institution_id
  # explícito + can? por fila (aquí es donde el scope RBAC :grade_level de un
  # revisor limitado a un solo grado toma efecto — Application#grade_level_id
  # aliasea target_grade_level_id).
  class ApplicationScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Admissions::Application
        .where(institution_id: institution.id)
        .includes(:applicant, :campaign, :target_grade_level)
        .order(submitted_at: :desc)
        .select { |application| context.can?("admissions.applications.manage", application) }
    end

    private

    attr_reader :context, :institution
  end
end
