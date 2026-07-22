module AnalyticsBi
  module Lens
    # Derives a per-student "needs attention" heat value (0..1) from EXISTING
    # T1 data (grades + attendance) and maps it to an HSL color server-side
    # (BI_DOCUMENT.md §10.2, Slice 2). In-memory over indexed AR reads — the
    # default processing strategy (§7), same mold as
    # AnalyticsBi::InstitutionDashboard / ReportCards::Computation. Reads only;
    # persists nothing; "who needs attention" is never a stored column.
    #
    # Signal convention: each sub-signal is 0..1 where HIGHER == BETTER
    # (grade = avg score / 5.0; attendance = present ÷ recorded, last 30 days).
    # wellbeing = mean of the AVAILABLE signals; heat = 1 - wellbeing, so a
    # HIGHER heat == more attention needed. A student with no grade AND no
    # attendance data yet has heat nil (a real empty state — dimmed/neutral,
    # never a misleading 0, same principle as InstitutionDashboard v1.34.0).
    class SpatialHeatmap
      GRADE_SCALE = 5.0
      ATTENDANCE_WINDOW_DAYS = 30
      # heat >= this surfaces as "needs attention" (icon + label, never
      # color-alone — AA, UX_UI §7).
      ATTENTION_THRESHOLD = 0.5
      # Hue sweep: heat 0 -> HUE_COOL (calm green), heat 1 -> 0 (warm red).
      HUE_COOL = 130

      Entry = Data.define(:heat, :hsl, :needs_attention, :grade, :attendance) do
        def known?
          !heat.nil?
        end
      end

      def self.for(**kwargs)
        new(**kwargs).build
      end

      def initialize(institution:, student_ids:)
        @institution = institution
        @student_ids = Array(student_ids).uniq
      end

      def build
        grades = grade_signals
        attendance = attendance_signals
        student_ids.index_with do |student_id|
          entry_for(grades[student_id], attendance[student_id])
        end
      end

      private

      attr_reader :institution, :student_ids

      def entry_for(grade, attendance)
        signals = [ grade, attendance ].compact
        if signals.empty?
          return Entry.new(heat: nil, hsl: "var(--heat-unknown)", needs_attention: false,
            grade: grade, attendance: attendance)
        end

        wellbeing = signals.sum / signals.size
        heat = (1.0 - wellbeing).clamp(0.0, 1.0).round(3)
        Entry.new(heat: heat, hsl: hsl_for(heat), needs_attention: heat >= ATTENTION_THRESHOLD,
          grade: grade, attendance: attendance)
      end

      def hsl_for(heat)
        hue = ((1.0 - heat) * HUE_COOL).round
        "hsl(#{hue}, 72%, 52%)"
      end

      # avg score / 5.0, clamped to 0..1. Only students with at least one
      # graded assessment appear.
      def grade_signals
        return {} if student_ids.empty?

        Schedules::Assessment.graded
          .joins(:enrollment)
          .where(institution_id: institution.id, enrollments: { student_id: student_ids })
          .group("enrollments.student_id")
          .average(:score)
          .transform_values { |avg| (avg.to_f / GRADE_SCALE).clamp(0.0, 1.0) }
      end

      # present ÷ total recorded days over the window. Only students with at
      # least one attendance record appear.
      def attendance_signals
        return {} if student_ids.empty?

        records = Attendance::AttendanceRecord
          .where(institution_id: institution.id, student_id: student_ids,
            date: ATTENDANCE_WINDOW_DAYS.days.ago.to_date..Date.current)
        totals = records.group(:student_id).count
        present = records.where(status: "present").group(:student_id).count

        totals.each_with_object({}) do |(student_id, total), memo|
          memo[student_id] = total.zero? ? nil : (present.fetch(student_id, 0).to_f / total)
        end
      end
    end
  end
end
