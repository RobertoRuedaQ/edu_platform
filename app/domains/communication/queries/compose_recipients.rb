module Communication
  # The BOUNDED recipient selector for composing a conversation — staff ∪
  # guardians of students within the actor's scope. NEVER a directory: no
  # free-text/name/document search (Habeas Data, same invariant as
  # Core::Access::GuardianScope). Three layers, same discipline attendance/
  # report_cards established: (1) groups this actor can compose for
  # (RBAC scope, per-row can? — mirrors Attendance::GroupScope) ∩ (2) the
  # students of those groups (business fact — GroupManagement, NOT
  # Schedules::ActiveTermEnrollmentScope: that resolver is subject-enrollment
  # eligibility, semantically unrelated to "whose guardian can this staff
  # message about", so this deliberately does NOT reuse it) ∩ (3) the
  # guardians actually linked to those students (inverse of GuardianScope).
  # Staff is UNSCOPED on purpose (§4: "staff de la institución", no
  # qualifier) — only the guardian side is bounded.
  class ComposeRecipients
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    # NOT "every active institution_user" — a guardian ALSO gets a
    # membership row (Core::People::Resolver, so login is possible at all),
    # so "staff" here means specifically an institution_user backed by a
    # StaffManagement::StaffMember row (D1's generalized staff employment),
    # never inferred from "holds zero role_assignments" (too fragile: a
    # newly-invited staff member with no role yet would wrongly look like a
    # guardian under that signal).
    def staff
      staff_institution_user_ids = StaffManagement::StaffMember.where(institution_id: institution.id)
        .select(:institution_user_id)
      Core::InstitutionUser.active
        .where(institution_id: institution.id, id: staff_institution_user_ids)
        .includes(:user)
        .map(&:user)
    end

    def guardians
      Core::GuardianStudent.active
        .where(institution_id: institution.id, student_id: students_in_scope.select(:id))
        .includes(:guardian)
        .map(&:guardian)
        .uniq
    end

    private

    attr_reader :context, :institution

    def students_in_scope
      GroupManagement::Student.where(institution_id: institution.id, section_id: composable_group_ids)
    end

    def composable_group_ids
      GroupManagement::Section
        .where(institution_id: institution.id)
        .select { |group| context.can?("conversation.compose", group) }
        .map(&:id)
    end
  end
end
