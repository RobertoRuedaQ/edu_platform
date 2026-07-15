module ReportCards
  # Idempotent batch publish — same spirit as attendance's roster upsert
  # (v1.16.0): re-publishing the SAME (student, academic_term) regenerates
  # the frozen snapshot, never duplicates it — the unique index on
  # (institution_id, student_id, academic_term_id) guarantees that. Never
  # UPDATEs a persisted ReportCard row (ReportCard#readonly? blocks that) —
  # regeneration always bulk-deletes-and-recreates (delete_all, which
  # bypasses the readonly? guard on purpose, same as
  # ControlPlane::Billing::PeriodCut's own idempotent re-cut of invoice
  # lines — a deliberate whole-snapshot regeneration is not the same
  # operation readonly? exists to prevent).
  # Synchronous this slice (§5) — no async job.
  class Publisher
    def self.call(institution:, academic_term:, students:, published_by_staff_member: nil)
      new(institution: institution, academic_term: academic_term, students: students,
        published_by_staff_member: published_by_staff_member).call
    end

    def initialize(institution:, academic_term:, students:, published_by_staff_member:)
      @institution = institution
      @academic_term = academic_term
      @students = students
      @published_by_staff_member = published_by_staff_member
    end

    def call
      students.map { |student| publish_one(student) }
    end

    private

    attr_reader :institution, :academic_term, :students, :published_by_staff_member

    def publish_one(student)
      result = Computation.call(student: student, academic_term: academic_term, institution: institution)

      ReportCard.transaction do
        ReportCard.where(institution_id: institution.id, student_id: student.id,
          academic_term_id: academic_term.id).delete_all

        ReportCard.create!(
          institution: institution, student: student, academic_term: academic_term,
          status: "published",
          lines_snapshot: result.lines.map do |line|
            { "subject_id" => line.subject_id, "subject_name" => line.subject_name, "average" => line.average.to_s }
          end,
          overall_average: result.overall_average,
          published_at: Time.current,
          published_by_staff_member: published_by_staff_member
        )
      end
    end
  end
end
