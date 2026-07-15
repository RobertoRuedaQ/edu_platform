module ReportCards
  # Live aggregation for (student, academic_term) — the "draft" a report card
  # is before it's published. Consumed by BOTH the supervision preview and
  # Publisher (which freezes this exact output once, at publish time — never
  # recomputed again for a published row, see ReportCard#readonly?).
  #
  # Per-subject grade: Schedules::Assessment carries `weight` and `max_score`
  # (recon: no scale/GPA logic existed yet in `schedules`, so this slice
  # introduces it here, never there). Each graded assessment is normalized to
  # the school's 0.0–5.0 scale before weighting, so a subject whose
  # assessments don't all share the same max_score still averages correctly.
  # A subject with zero graded assessments contributes no line (a report
  # card mid-term is allowed to be partial) — never a zero.
  class Computation
    Result = Data.define(:lines, :overall_average)
    Line = Data.define(:subject_id, :subject_name, :average)

    SCALE = BigDecimal("5.0")

    def self.call(student:, academic_term:, institution: Current.institution)
      new(student: student, academic_term: academic_term, institution: institution).call
    end

    def initialize(student:, academic_term:, institution:)
      @student = student
      @academic_term = academic_term
      @institution = institution
    end

    def call
      lines = enrollments.filter_map { |enrollment| line_for(enrollment) }
      overall_average = lines.any? ? (lines.sum(&:average) / lines.size).round(1) : nil
      Result.new(lines: lines, overall_average: overall_average)
    end

    private

    attr_reader :student, :academic_term, :institution

    def enrollments
      Schedules::Enrollment
        .where(institution_id: institution.id, student_id: student.id, academic_term_id: academic_term.id)
        .includes(:subject, :assessments)
    end

    def line_for(enrollment)
      graded = enrollment.assessments.select { |assessment| assessment.score.present? }
      return nil if graded.empty?

      total_weight = graded.sum(&:weight)
      weighted_sum = graded.sum { |assessment| (assessment.score / assessment.max_score * SCALE) * assessment.weight }
      average = (weighted_sum / total_weight).round(1)

      Line.new(subject_id: enrollment.subject_id, subject_name: enrollment.subject.name, average: average)
    end
  end
end
