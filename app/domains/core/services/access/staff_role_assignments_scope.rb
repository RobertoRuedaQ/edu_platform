module Core
  module Access
    # Resolves "my currently-effective role_assignments" — the security
    # boundary self-service is built on (SS3/SS4): a docente/coordinador/
    # director's own groups and department are DERIVED from this relation's
    # scope_group_id/scope_department_id, not from a separate teacher->group
    # link (none exists in the schema — sections has no homeroom_teacher_id
    # at all). Mirrors Core::Access::GuardianScope's shape (a composable
    # relation, explicit institution_id + institution_user_id scoping, RLS as
    # backstop, no search term, ever).
    #
    # `.effective_now` (P1) is the REAL term filter here — valid_from/
    # valid_until — unlike group/enrollment membership, which has no FK to
    # academic_terms at all (B2/Cav., still open) and so is never
    # term-filtered anywhere in this app, self-service included.
    module StaffRoleAssignmentsScope
      module_function

      def for(user, institution: Current.institution)
        return IdentityAccess::RoleAssignment.none if user.nil? || institution.nil?

        institution_user = institution.memberships.active.find_by(user_id: user.id)
        return IdentityAccess::RoleAssignment.none if institution_user.nil?

        IdentityAccess::RoleAssignment
          .where(institution_id: institution.id, institution_user_id: institution_user.id)
          .effective_now
      end
    end
  end
end
