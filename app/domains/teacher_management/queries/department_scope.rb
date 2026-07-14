module TeacherManagement
  # Same shape as TeacherScope (canonical #4 reference — see that class'
  # comment). Reads StaffManagement::Department directly (cross-domain by
  # FK, not a copy) — departments are owned by staff_management since D1;
  # teacher_management only reads them here and via DepartmentsController.
  # Explicit, per-row can? check, never default_scope; includes both
  # academic AND operational kinds — whichever the actor's scope covers.
  class DepartmentScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      StaffManagement::Department
        .where(institution_id: institution.id)
        .order(:name)
        .select { |department| context.can?("departments.view", department) }
    end

    private

    attr_reader :context, :institution
  end
end
