module Transportation
  # THE single read path for a student/guardian portal view of transport —
  # same "one computation, many surfaces" discipline as Attendance::
  # StudentView/Finance::AccountStatement. No authorize!: the caller must
  # already have resolved `student` through Core::Access::GuardianScope/
  # StudentSelfScope before calling this — this query does not re-check
  # relation, it only reads. Returns 0, 1, or 2 rows (am/pm), never assumes one.
  module RiderView
    module_function

    def for(student:, institution: Current.institution)
      Transportation::RouteRider
        .where(institution_id: institution.id, student_id: student.id)
        .includes(:route, :route_stop)
        .order(:shift)
    end
  end
end
