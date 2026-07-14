module Core
  module Access
    # Resolves "my acudidos" for an authenticated guardian — a security query,
    # not a view helper. Mirrors Core::Access::EntitledAddonKeys' shape (plain
    # module_function, no instance state); lives alongside it for the same
    # reason (recon: that file is under services/access/, not queries/access/
    # as first assumed — Zeitwerk collapses both identically, but consistency
    # with the sibling file wins).
    #
    # Returns a COMPOSABLE ActiveRecord relation, never an Array — explicit
    # scoping (institution_id + guardian_user_id + active link status) is the
    # PRIMARY guarantee; RLS is the backstop, never the only line of defense
    # (no default_scope). GS4: takes no search term, ever — this resolves
    # only the caller's own relations, never an open lookup. GS3: does NOT
    # filter by academic_term — mirrors the same documented limitation as
    # Core::Headcount::Snapshotter (enrollments.term is a free string with no
    # FK to academic_terms, so that join doesn't exist in the current
    # schema). Reversible once B2 closes.
    module GuardianScope
      module_function

      def for(user, institution: Current.institution)
        return GroupManagement::Student.none if user.nil? || institution.nil?

        GroupManagement::Student
          .where(institution_id: institution.id)
          .joins(:guardian_students)
          .where(guardian_students: { guardian_user_id: user.id, institution_id: institution.id, status: "active" })
      end
    end
  end
end
