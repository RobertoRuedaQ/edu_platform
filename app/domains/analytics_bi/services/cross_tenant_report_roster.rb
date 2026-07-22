module AnalyticsBi
  # Real cross-tenant rollup (v1.35.0, BI_DOCUMENT.md §6.1/§9 Slice 1) — SOLO
  # bi_auditor reads this (CrossTenantReportsController). Runs through
  # AnalyticsBi::BiReader::* (edu_bi_reader, BYPASSRLS) — the first real
  # BYPASSRLS wiring in this app.
  #
  # The "doble filtro a nivel de aplicación" guardrail (BI_DOCUMENT.md §6.1.2):
  # once RLS is bypassed, the app-level GROUP BY institution_id is the ONLY
  # thing standing between "one row per institution" and "one blended number
  # across every tenant" — every aggregate below groups by institution_id
  # explicitly, never a bare .average/.count with no grouping.
  #
  # Only aggregates per institution ever leave this method — no student-level
  # row, name, or PII crosses back to the caller (BI_DOCUMENT.md §6.1.3).
  module CrossTenantReportRoster
    Row = Data.define(:id, :institution_name, :institution_kind, :student_count, :avg_grade)

    def self.all
      institutions = BiReader::Institution.order(:name).to_a

      student_counts = BiReader::Student.where(status: "active").group(:institution_id).count
      avg_grades = BiReader::Assessment.where.not(score: nil).group(:institution_id).average(:score)

      institutions.map do |institution|
        Row.new(
          id: institution.id, institution_name: institution.name, institution_kind: institution.kind,
          student_count: student_counts[institution.id] || 0,
          avg_grade: (avg = avg_grades[institution.id]) ? avg.round(1) : nil
        )
      end
    end
  end
end
