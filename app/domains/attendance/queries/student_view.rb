module Attendance
  # THE single read path for a student/guardian portal view of attendance —
  # same "one computation, many surfaces" discipline as
  # Finance::AccountStatement/ReportCards::Computation. No authorize!: the
  # caller must already have resolved `student` through
  # Core::Access::GuardianScope/StudentSelfScope before calling this — this
  # query does not re-check relation, it only reads.
  module StudentView
    module_function

    # Most recent day first, same ordering convention as
    # ReportCards::ReportCard (published_at: :desc).
    def for(student:, institution: Current.institution)
      AttendanceRecord
        .where(institution_id: institution.id, student_id: student.id)
        .includes(:group)
        .order(date: :desc)
    end
  end
end
