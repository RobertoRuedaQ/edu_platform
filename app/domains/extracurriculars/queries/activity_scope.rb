module Extracurriculars
  # Scope de supervisión (molde #4): qué actividades ve/gestiona el actor.
  #
  # A DIFERENCIA de Attendance::GroupScope/TeacherManagement::TeacherScope, el
  # instructor NO se resuelve por scope de rol (jerarquía department/grade/
  # group vía Authorization::Assignment#covers?): la actividad es "mía" cuando
  # activities.instructor_staff_member_id == mi propio StaffMember#id — una
  # relación de IDENTIDAD/PROPIEDAD de una sola fila, no de jerarquía. Por eso
  # se filtra directo en el query por el FK (WHERE, no un .select per-fila con
  # covers?) y NO se toca SCOPE_READERS/covers?/role_assignments. Ver el
  # guardrail "ownership vs hierarchy" en OPEN_PROCESS.md §2.
  #
  # activity.manage (coordinador, institución-wide) ve TODAS; quien solo tiene
  # activity.instruct ve únicamente las propias. Un actor sin StaffMember (no
  # debería ocurrir para un instructor real) ve cero — fail-closed.
  class ActivityScope
    def initialize(context:, actor_staff_member:, institution: Current.institution)
      @context = context
      @actor_staff_member = actor_staff_member
      @institution = institution
    end

    def resolve
      base = Extracurriculars::Activity
        .where(institution_id: institution.id)
        .includes(:academic_term, :instructor_staff_member)
        .order(:name)

      return base if context.can?("activity.manage")
      return Extracurriculars::Activity.none if actor_staff_member.nil?

      base.where(instructor_staff_member_id: actor_staff_member.id)
    end

    private

    attr_reader :context, :actor_staff_member, :institution
  end
end
