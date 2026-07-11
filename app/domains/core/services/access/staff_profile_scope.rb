module Core
  module Access
    # Resolves the ONE StaffManagement::StaffMember a signed-in staff user IS
    # — the staff analogue of Core::Access::StudentSelfScope (a single record,
    # not a relation: "self" is inherently one-or-none). Explicit scoping
    # (institution_id + institution_user_id, RLS as backstop, no
    # default_scope), same discipline as every Core::Access::* self-scope —
    # no search term, ever.
    #
    # NOT every staff person has a row here (D1's additive transition:
    # teachers.staff_member_id is nullable and often unpopulated even when
    # the person IS a teacher) — a nil result is a normal empty state (SS8),
    # never an error.
    module StaffProfileScope
      module_function

      def for(user, institution: Current.institution)
        return nil if user.nil? || institution.nil?

        institution_user = institution.memberships.active.find_by(user_id: user.id)
        return nil if institution_user.nil?

        StaffManagement::StaffMember.find_by(institution_id: institution.id, institution_user_id: institution_user.id)
      end
    end
  end
end
