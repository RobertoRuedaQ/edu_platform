module Calendar
  # Portal visibility, by RELATION — NOT RBAC (no authorize!), same spirit as
  # Core::Access::GuardianScope/StudentSelfScope. Given a student, the real
  # Calendar::Event rows they can see: institution-wide events + events scoped
  # to their grade level + events scoped to their section. Composable relation,
  # explicit scoping (institution_id + the student's own grade/section), RLS as
  # backstop, never default_scope. A student with a nil grade_level_id/section_id
  # simply won't match a grade/group event (SQL `= NULL` is never true) — the
  # institution-wide branch still applies, no special-casing needed.
  module VisibleScope
    module_function

    def for(student:, institution: Current.institution)
      return Calendar::Event.none if student.nil? || institution.nil?

      Calendar::Event
        .where(institution_id: institution.id)
        .where(
          "(scope_grade_level_id IS NULL AND scope_group_id IS NULL) " \
          "OR scope_grade_level_id = :grade OR scope_group_id = :section",
          grade: student.grade_level_id, section: student.section_id
        )
        .order(starts_at: :asc)
    end
  end
end
