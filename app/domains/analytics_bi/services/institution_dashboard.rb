module AnalyticsBi
  # Real institution-wide KPIs for the actor's OWN tenant (v1.34.0 — replaces
  # the S1 stub). Every number is a plain tenant-scoped read under the
  # caller's own RLS/GUC — no BYPASSRLS, no cross-tenant reach here (that's
  # CrossTenantReportRoster's job, still a stub, a separate and more
  # sensitive slice). Never writes anything — total_students/avg_grade/
  # attendance_rate are computed live, NOT via Core::Headcount::Snapshotter
  # (which persists a row + an audit event on every call — wrong side effect
  # for a page view). enrollment_trend is the one exception that reads
  # already-persisted history (ControlPlane::StudentHeadcountSnapshot, real
  # since the v1.32.0 recurring snapshot job) rather than recomputing a trend.
  module InstitutionDashboard
    module_function

    def for(institution:)
      {
        total_students: total_students(institution),
        avg_grade: avg_grade(institution),
        attendance_rate: attendance_rate(institution),
        enrollment_trend: enrollment_trend(institution),
        grades_by_subject: grades_by_subject(institution),
        status_breakdown: status_breakdown(institution)
      }
    end

    # Same definition as Core::Headcount::Snapshotter (status == "active",
    # deliberately NOT term-filtered — see that module's own docstring).
    def total_students(institution)
      GroupManagement::Student.where(institution_id: institution.id, status: "active").count
    end

    def avg_grade(institution)
      avg = Schedules::Assessment.graded.where(institution_id: institution.id).average(:score)
      avg&.round(1)&.to_f
    end

    # present ÷ total over the last 30 days, nil (never a bare/misleading 0)
    # when there's no attendance data at all yet.
    def attendance_rate(institution)
      records = Attendance::AttendanceRecord.where(institution_id: institution.id, date: 30.days.ago..Date.current)
      total = records.count
      return nil if total.zero?

      (records.where(status: "present").count * 100.0 / total).round(1)
    end

    def enrollment_trend(institution)
      ControlPlane::StudentHeadcountSnapshot.for_institution(institution).most_recent_first.limit(6).to_a.reverse
        .map { |snapshot| { label: snapshot.as_of_date.strftime("%b"), value: snapshot.headcount } }
    end

    def grades_by_subject(institution)
      Schedules::Assessment.graded.where(institution_id: institution.id)
        .joins(enrollment: :subject).group("subjects.name").average(:score)
        .map { |name, avg| { label: name, value: avg.round(1).to_f } }
    end

    def status_breakdown(institution)
      GroupManagement::Student.where(institution_id: institution.id).group(:status).count
        .map { |status, count| { label: status.humanize, value: count } }
    end
  end
end
