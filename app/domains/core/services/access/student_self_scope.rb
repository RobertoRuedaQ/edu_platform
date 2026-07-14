module Core
  module Access
    # Resolves the ONE GroupManagement::Student a signed-in student user IS —
    # the symmetric, minimal counterpart to GuardianScope (GS5). A single
    # record, not a relation: "self" is inherently one-or-none. Same explicit
    # scoping discipline (institution_id + user_id, RLS as backstop, no
    # default_scope) and the same invariant — no search term, ever; this
    # resolves only the caller's own record.
    module StudentSelfScope
      module_function

      def for(user, institution: Current.institution)
        return nil if user.nil? || institution.nil?

        GroupManagement::Student.find_by(institution_id: institution.id, user_id: user.id)
      end
    end
  end
end
