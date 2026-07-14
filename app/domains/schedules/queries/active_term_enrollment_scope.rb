module Schedules
  # THE canonical resolver for "the student enrolled in the active term"
  # (v1.15.0, closes the model half of Cav./B2). Every academic slice that
  # follows (attendance, notas-por-término, inscripción a actividades,
  # targeting de asignaciones) is meant to consume this rather than
  # re-deriving its own term join.
  #
  # Deliberately NOT identity-gated (unlike Core::Access::GuardianScope/
  # StudentSelfScope) — this resolves "everyone enrolled this term" for the
  # institution, not "my own" anything. Callers apply whatever further
  # RBAC/scope filtering their own domain needs on top (same layering as
  # TeacherManagement::TeacherScope filtering per-row after this).
  #
  # "Active term" leans entirely on the DB's own one-active-per-institution
  # invariant (the partial unique index on academic_terms) — this never
  # re-derives or second-guesses it, just reads Core::AcademicTerm.active.
  # No default_scope; institution_id explicit; no search term, ever
  # (Habeas Data — same discipline as GuardianScope).
  module ActiveTermEnrollmentScope
    module_function

    def resolve(institution:)
      active_term = Core::AcademicTerm.active.find_by(institution_id: institution.id)
      return GroupManagement::Student.none if active_term.nil?

      GroupManagement::Student
        .where(institution_id: institution.id)
        .where(id: Schedules::Enrollment.where(institution_id: institution.id, academic_term_id: active_term.id)
                                         .select(:student_id))
        .distinct
    end
  end
end
