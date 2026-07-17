module Attendance
  # The roster-taking action. Real target model (Attendance::AttendanceRecord)
  # exists in THIS slice (unlike teacher.evaluate, v1.13.0) — so the write is
  # cabled completely, not gate-only (BV6). Idempotent batch upsert: taking
  # attendance for the SAME (group, date) again updates the existing rows
  # (unique index on institution_id+student_id+date), never duplicates.
  class RecordsController < ApplicationController
    def new
      @group = find_group
      authorize!("attendance.record", @group)
      @date = parse_date(params[:date]) || Date.current
      @roster = roster_for(@group)
      @existing = Attendance::AttendanceRecord
        .where(institution_id: Current.institution_id, group_id: @group.id, date: @date)
        .index_by(&:student_id)
    end

    def create
      @group = find_group
      authorize!("attendance.record", @group)
      @date = parse_date(params[:date])
      if @date.nil?
        @error = "Fecha inválida."
        @roster = roster_for(@group)
        @existing = {}
        return render :new, status: :unprocessable_entity
      end

      recorder = StaffManagement::StaffMember.find_by(
        institution_id: Current.institution_id, institution_user_id: Current.institution_user_id
      )

      roster_for(@group).each do |student|
        status = params.dig(:statuses, student.id).presence || "present"
        record = Attendance::AttendanceRecord.find_or_initialize_by(
          institution_id: Current.institution_id, student_id: student.id, date: @date
        )
        record.institution = Current.institution
        record.group = @group
        record.status = status
        record.recorded_by_staff_member = recorder
        record.note = params.dig(:notes, student.id).presence
        record.save!
        emit_usage(record)
      end

      redirect_to attendance_groups_path, notice: "Asistencia de #{@group.name} guardada para #{@date.to_fs(:long)}."
    end

    private

    def find_group
      group = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:group_id])
      raise ActiveRecord::RecordNotFound if group.nil?

      group
    end

    # The roster tomable (A1): the intersection of "matriculado en el término
    # activo" (Schedules::ActiveTermEnrollmentScope — never re-derived here)
    # with "alumno de ESTE grupo". A student currently in the group but NOT
    # enrolled in the active term never appears.
    def roster_for(group)
      Schedules::ActiveTermEnrollmentScope.resolve(institution: Current.institution)
        .where(section_id: group.id)
        .order(:last_name, :first_name)
    end

    def parse_date(value)
      Date.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end

    # S3b (v1.30.0): one "registros" unit per AttendanceRecord saved. The
    # record's own id is the idempotency anchor — re-taking the SAME (group,
    # date) reuses the SAME row (find_or_initialize_by above), so it never
    # double-counts a re-take, only a genuinely new (student, date) record.
    def emit_usage(record)
      ControlPlane::Usage::Ingest.emit(institution: Current.institution, addon_key: "attendance",
        unit: "registros", occurred_at: record.date.in_time_zone, idempotency_key: "attendance_record:#{record.id}")
    end
  end
end
