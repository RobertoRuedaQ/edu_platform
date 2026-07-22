module AnalyticsBi
  module Lens
    # Read side of the Lens 4 orbital graph (BI_DOCUMENT.md §5.6, Slice 8).
    # Explicit institution_id filter, no default_scope — RLS is the backstop.
    #
    # Sibling detection reuses the EXISTING core.guardian_students link — no new
    # table (§5.6: "hermanos detectados por guardian_students compartido... no
    # requiere tabla nueva, es una query"). It matches the doc's own language
    # PRECISELY: siblings share the same PRIMARY caregiver
    # (GuardianRelationship#is_primary_caregiver), not just any shared guardian
    # — a household with two guardians and no primary marked yet simply has no
    # detected siblings (honest empty state, never a guess).
    class FamilyCoreScope
      def initialize(institution: Current.institution)
        @institution = institution
      end

      # Every active guardian relationship for this student, primary caregivers
      # first — what the graph places closest to the student in the center.
      def guardians_for(student)
        AnalyticsBi::GuardianRelationship
          .joins(:guardian_student)
          .where(institution_id: institution.id, guardian_students: { student_id: student.id, status: "active" })
          .order(is_primary_caregiver: :desc)
      end

      # Other active students who share a PRIMARY caregiver with this student —
      # never the student itself, never a duplicate.
      def siblings_for(student)
        primary_guardian_ids = primary_guardian_user_ids_for(student)
        return GroupManagement::Student.none if primary_guardian_ids.empty?

        GroupManagement::Student
          .joins("INNER JOIN guardian_students ON guardian_students.student_id = students.id")
          .where(institution_id: institution.id, guardian_students: {
            guardian_user_id: primary_guardian_ids, status: "active", institution_id: institution.id
          })
          .where.not(id: student.id)
          .distinct
      end

      private

      attr_reader :institution

      def primary_guardian_user_ids_for(student)
        AnalyticsBi::GuardianRelationship
          .joins(:guardian_student)
          .primary_caregivers
          .where(institution_id: institution.id, guardian_students: { student_id: student.id, status: "active" })
          .pluck("guardian_students.guardian_user_id")
      end
    end
  end
end
