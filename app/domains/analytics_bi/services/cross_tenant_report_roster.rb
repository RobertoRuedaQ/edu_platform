module AnalyticsBi
  # STUB cross-tenant rollup — SOLO bi_auditor reads this. Real cross-tenant
  # querying needs the audited edu_bi_reader Postgres role (BYPASSRLS; see
  # lib/tasks/roles.rake), which control_plane's own BaseController already
  # defers ("no DB access this phase") — this follows that same precedent
  # rather than being the first real BYPASSRLS wiring in the app.
  #
  # TODO: reemplazar por una consulta real vía edu_bi_reader, auditada.
  module CrossTenantReportRoster
    Row = Data.define(:id, :institution_name, :institution_kind, :student_count, :avg_grade)

    def self.all
      [
        Row.new(id: "inst-1", institution_name: "Colegio San José", institution_kind: "school",
                student_count: 187, avg_grade: 3.8),
        Row.new(id: "inst-2", institution_name: "Universidad Andina", institution_kind: "university",
                student_count: 412, avg_grade: 3.6),
        Row.new(id: "inst-3", institution_name: "Instituto Los Andes", institution_kind: "school",
                student_count: 96, avg_grade: 4.0)
      ]
    end
  end
end
