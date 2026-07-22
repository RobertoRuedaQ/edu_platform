# "Mis datos" — staff self-service (docente/coordinador/director/etc.),
# the staff analogue of the student/guardian portals (v1.9.0). Identity-
# gated (SS2): reachable by ANY authenticated staff member regardless of
# what they're allowed to see about anyone ELSE — there is no authorize!
# here, the self-scopes themselves (Core::Access::Staff*Scope) are the
# gate. Read-only (SS6): no forms.
#
# "My groups"/"my department" are DERIVED from the actor's own
# role_assignments' scope columns (StaffRoleAssignmentsScope), not from a
# separate teacher->group link — none exists in the schema (sections has
# no homeroom_teacher_id at all). A person with several roles sees the
# UNION of what those roles scope to (SS7) — never recut by the "acting
# as" selector, which doesn't exist as a real mechanism yet anyway.
class SelfServiceController < ApplicationController
  def show
    @profile = Core::Access::StaffProfileScope.for(Current.user)
    @role_assignments = Core::Access::StaffRoleAssignmentsScope.for(Current.user)
      .includes(:role, :scope_department, :scope_grade_level, :scope_group)

    group_ids = @role_assignments.where.not(scope_group_id: nil).distinct.pluck(:scope_group_id)
    @groups = GroupManagement::Section.where(id: group_ids)

    department_ids = @role_assignments.where.not(scope_department_id: nil).distinct.pluck(:scope_department_id)
    @departments = StaffManagement::Department.where(id: department_ids)

    # schedules' timetable half is real since v1.50.0 (Schedules::
    # MeetingPattern) — filtered by IDENTITY (the actor's own group ids
    # above), never by can?/authorize! (this page is not an RBAC surface,
    # same discipline as every other self-service panel).
    if Current.entitled_addon_keys.include?("schedules")
      own_group_ids = group_ids.map(&:to_s)
      @schedule_events = Schedules::MeetingPatternPresenter.rows_for(Current.institution)
        .select { |row| own_group_ids.include?(row.group_id.to_s) }
    end
  end
end
