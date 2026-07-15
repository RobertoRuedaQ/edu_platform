module Assignments
  # The roster tomable for a subject — three layers, never collapsed (same
  # discipline as attendance/report_cards): (1) Schedules::
  # ActiveTermEnrollmentScope (raw academic fact, institution-wide, never
  # re-derived) ∩ (2) THIS subject's enrollments in the active term
  # (composed explicitly — ActiveTermEnrollmentScope alone doesn't take a
  # subject param) ∩ (3) the caller's own RBAC check (authorize!("assignment.
  # manage", subject), done by the controller before calling this, not here).
  #
  # Unlike messaging (v1.20.0), THIS domain's raw fact layer correctly IS
  # ActiveTermEnrollmentScope — an assignment is for students actually
  # enrolled in the subject/term, which is exactly what that resolver means.
  module Roster
    module_function

    def for_subject(subject, institution: Current.institution)
      active_term = Core::AcademicTerm.active.find_by(institution_id: institution.id)
      return GroupManagement::Student.none if active_term.nil?

      Schedules::ActiveTermEnrollmentScope.resolve(institution: institution)
        .where(id: Schedules::Enrollment.where(institution_id: institution.id, subject_id: subject.id,
          academic_term_id: active_term.id).select(:student_id))
    end
  end
end
