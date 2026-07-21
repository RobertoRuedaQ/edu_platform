module AnalyticsBi
  module Hps
    # Computes and writes one AnalyticsBi::HpsTermSnapshot per ACTIVE student for
    # (institution, academic_term) — the term-snapshot mold (BI_DOCUMENT.md §7,
    # Slice 4). Same shape as Core::Headcount::Snapshotter: in-memory compute
    # over indexed AR reads, then persist; runs under the tenant's own GUC (the
    # caller — HpsTermSnapshotJob — fixes it, this service trusts it, exactly
    # like every Query object trusts TenantScoped's around_action).
    #
    # PAYLOAD (jsonb, so later slices extend it without a migration):
    #   attendance_rate  present ÷ recorded within the term window, nil if none
    #   average_grade    avg Schedules::Assessment.score for enrollments in THIS
    #                    term, nil if none (never a misleading 0 — the v1.34.0
    #                    nil/"—" rule)
    #   grade_scale      the denominator (5.0) so a reader interprets average_grade
    #   wellbeing        mean of the AVAILABLE 0..1 signals, nil if none
    #   heat             1 - wellbeing (higher == more attention needed) — same
    #                    convention as AnalyticsBi::Lens::SpatialHeatmap, but
    #                    TERM-scoped here (not a rolling 30-day window), which is
    #                    the whole point of a historical term snapshot
    #   section_id/name, grade_level_id/name  the placement that was in effect for
    #                    this term (from student_placements — the §5.2 axis),
    #                    NEVER students.section_id (which only knows the present)
    #
    # "Active student" == GroupManagement::Student.status "active" (same
    # definition as headcount). Idempotent per (student, term): re-running
    # updates the existing row (find_or_initialize_by on the unique triple),
    # never duplicates.
    module Snapshotter
      module_function

      GRADE_SCALE = 5.0

      def call(institution:, academic_term:)
        students = GroupManagement::Student.where(institution_id: institution.id, status: "active").to_a
        return [] if students.empty?

        student_ids = students.map(&:id)
        grades = grade_signals(institution, academic_term, student_ids)
        attendance = attendance_signals(institution, academic_term, student_ids)
        placements = placement_signals(institution, academic_term, student_ids)
        section_names, grade_level_names = label_lookups(institution, placements.values)

        students.map do |student|
          write_snapshot(
            institution: institution, academic_term: academic_term, student: student,
            grade: grades[student.id], attendance: attendance[student.id],
            placement: placements[student.id], section_names: section_names,
            grade_level_names: grade_level_names
          )
        end
      end

      # --- persistence -----------------------------------------------------

      def write_snapshot(institution:, academic_term:, student:, grade:, attendance:,
                         placement:, section_names:, grade_level_names:)
        snapshot = AnalyticsBi::HpsTermSnapshot.find_or_initialize_by(
          institution_id: institution.id, student_id: student.id, academic_term_id: academic_term.id
        )
        snapshot.assign_attributes(
          captured_on: Date.current,
          payload: build_payload(grade, attendance, placement, section_names, grade_level_names)
        )
        snapshot.save!
        snapshot
      end

      def build_payload(grade, attendance, placement, section_names, grade_level_names)
        average_grade = grade && (grade * GRADE_SCALE).round(2)
        wellbeing = wellbeing_for(grade, attendance)
        {
          "attendance_rate" => attendance&.round(3),
          "average_grade"   => average_grade,
          "grade_scale"     => GRADE_SCALE,
          "wellbeing"       => wellbeing&.round(3),
          "heat"            => wellbeing && (1.0 - wellbeing).round(3),
          "section_id"      => placement&.section_id,
          "section_name"    => placement && section_names[placement.section_id],
          "grade_level_id"  => placement&.grade_level_id,
          "grade_level_name" => placement && grade_level_names[placement.grade_level_id]
        }
      end

      # wellbeing = mean of the available 0..1 signals (HIGHER == better), nil
      # if none — same convention as SpatialHeatmap.
      def wellbeing_for(grade, attendance)
        signals = [ grade, attendance ].compact
        return nil if signals.empty?

        (signals.sum / signals.size).clamp(0.0, 1.0)
      end

      # --- signals (term-scoped) ------------------------------------------

      # avg score / 5.0, clamped 0..1, only for enrollments IN this term. Ties
      # the grade to the term via enrollments.academic_term_id (v1.15.0), never
      # a rolling window.
      def grade_signals(institution, academic_term, student_ids)
        Schedules::Assessment.graded
          .joins(:enrollment)
          .where(institution_id: institution.id,
            enrollments: { student_id: student_ids, academic_term_id: academic_term.id })
          .group("enrollments.student_id")
          .average(:score)
          .transform_values { |avg| (avg.to_f / GRADE_SCALE).clamp(0.0, 1.0) }
      end

      # present ÷ recorded within the term's calendar window, clamped to today so
      # a not-yet-finished term never counts future days.
      def attendance_signals(institution, academic_term, student_ids)
        window = academic_term.starts_on..[ academic_term.ends_on, Date.current ].min
        records = Attendance::AttendanceRecord
          .where(institution_id: institution.id, student_id: student_ids, date: window)
        totals = records.group(:student_id).count
        present = records.where(status: "present").group(:student_id).count

        totals.each_with_object({}) do |(student_id, total), memo|
          memo[student_id] = total.zero? ? nil : (present.fetch(student_id, 0).to_f / total)
        end
      end

      # The placement that was in effect for this (student, term) — the §5.2
      # axis, keyed by student_id (last one wins if reassigned mid-term).
      def placement_signals(institution, academic_term, student_ids)
        GroupManagement::StudentPlacement
          .where(institution_id: institution.id, student_id: student_ids,
            academic_term_id: academic_term.id)
          .order(:valid_from)
          .index_by(&:student_id)
      end

      def label_lookups(institution, placements)
        section_ids = placements.map(&:section_id).uniq
        grade_level_ids = placements.map(&:grade_level_id).uniq
        [
          GroupManagement::Section.where(institution_id: institution.id, id: section_ids).pluck(:id, :name).to_h,
          GroupManagement::GradeLevel.where(institution_id: institution.id, id: grade_level_ids).pluck(:id, :name).to_h
        ]
      end
    end
  end
end
