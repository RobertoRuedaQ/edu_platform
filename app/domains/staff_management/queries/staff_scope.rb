module StaffManagement
  # Same shape as TeacherManagement::TeacherScope/DepartmentScope (the #4
  # canonical reference) — copied here, not reinvented, because the
  # "Personal" directory needs the identical per-row scope treatment: an
  # institution-wide grant (e.g. institution_admin) sees every staff member,
  # a department-scoped grant (e.g. area_lead) sees only their own
  # department's, and a staff member with department_id NULL (non-academic,
  # D1) is correctly invisible to a department-scoped viewer — nil never
  # equals a real department id — while still visible institution-wide.
  class StaffScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      StaffManagement::StaffMember
        .where(institution_id: institution.id)
        .includes(:department)
        .select { |staff_member| context.can?("staff.read", staff_member) }
    end

    private

    attr_reader :context, :institution
  end
end
