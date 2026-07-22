module AnalyticsBi
  module Lens
    # Read-model signal, computed LIVE, never persisted (§7 default, decision
    # A6 "vivas al inicio"; BI_DOCUMENT.md §5.6). Detects when SEVERAL siblings
    # (same primary caregiver, AnalyticsBi::Lens::FamilyCoreScope) show a
    # decline in attendance/grades in the SAME recent window — a signal for
    # human intervention, NEVER a verdict (§5.6: "es una señal para
    # intervención humana, no un veredicto"). Surfaced only to hps.family.view.
    #
    # Heuristic (documented, "aburrido sobre ingenioso" — no real threshold has
    # been confirmed by the owner yet, same open-decision posture as
    # CLOSURE_PLAN.md's alertas tempranas item): a student is "declining" when
    # BOTH windows have data AND the recent window is at least
    # ATTENDANCE_DROP_THRESHOLD/GRADE_DROP_THRESHOLD worse than the baseline
    # window. An alert triggers when >= MIN_SIBLINGS_DECLINING siblings in the
    # same primary-caregiver group are declining at once. A student with no
    # data in either window is never counted as declining (absence of data is
    # never treated as a decline).
    class SiblingBondAlert
      RECENT_WINDOW_DAYS = 14
      BASELINE_WINDOW_DAYS = 30
      ATTENDANCE_DROP_THRESHOLD = 0.2 # 20 percentage points
      GRADE_DROP_THRESHOLD = 1.0      # 1.0 point on a 5.0 scale
      MIN_SIBLINGS_DECLINING = 2

      Alert = Data.define(:guardian_name, :students)

      def self.for(institution: Current.institution, as_of: Date.current)
        new(institution: institution, as_of: as_of).call
      end

      def initialize(institution:, as_of: Date.current)
        @institution = institution
        @as_of = as_of
      end

      def call
        sibling_groups.filter_map { |guardian_id, students| alert_for(guardian_id, students) }
      end

      private

      attr_reader :institution, :as_of

      # Group active students by their PRIMARY caregiver's guardian_user_id —
      # the same identity FamilyCoreScope uses, computed directly here since we
      # need every group at once (not one student's siblings at a time).
      def sibling_groups
        AnalyticsBi::GuardianRelationship
          .joins(:guardian_student)
          .primary_caregivers
          .where(institution_id: institution.id, guardian_students: { institution_id: institution.id, status: "active" })
          .pluck("guardian_students.guardian_user_id", "guardian_students.student_id")
          .group_by(&:first)
          .transform_values { |pairs| pairs.map(&:last).uniq }
          .select { |_guardian_id, student_ids| student_ids.size > 1 }
      end

      def alert_for(guardian_id, student_ids)
        declining = GroupManagement::Student.where(institution_id: institution.id, id: student_ids)
          .select { |student| declining?(student) }
        return nil if declining.size < MIN_SIBLINGS_DECLINING

        Alert.new(guardian_name: Core::User.find_by(id: guardian_id)&.name, students: declining)
      end

      def declining?(student)
        attendance_declined?(student) || grade_declined?(student)
      end

      def attendance_declined?(student)
        recent = attendance_rate(student, recent_window)
        baseline = attendance_rate(student, baseline_window)
        return false if recent.nil? || baseline.nil?

        (baseline - recent) >= ATTENDANCE_DROP_THRESHOLD
      end

      def grade_declined?(student)
        recent = average_grade(student, recent_window)
        baseline = average_grade(student, baseline_window)
        return false if recent.nil? || baseline.nil?

        (baseline - recent) >= GRADE_DROP_THRESHOLD
      end

      def recent_window
        (as_of - RECENT_WINDOW_DAYS)..as_of
      end

      def baseline_window
        (as_of - (RECENT_WINDOW_DAYS + BASELINE_WINDOW_DAYS))..(as_of - RECENT_WINDOW_DAYS)
      end

      def attendance_rate(student, window)
        records = Attendance::AttendanceRecord.where(institution_id: institution.id, student_id: student.id, date: window)
        total = records.count
        return nil if total.zero?

        records.where(status: "present").count.to_f / total
      end

      def average_grade(student, window)
        Schedules::Assessment.graded
          .joins(:enrollment)
          .where(institution_id: institution.id, enrollments: { student_id: student.id }, assessed_on: window)
          .average(:score)&.to_f
      end
    end
  end
end
