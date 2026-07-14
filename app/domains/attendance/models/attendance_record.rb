module Attendance
  # One student's attendance status for one day, taken against their homeroom
  # (GroupManagement::Section) — daily by homeroom only, per-subject
  # attendance is deferred (see HISTORIA.md v1.16.0). "group" is stored
  # explicitly rather than derived from the student's current section_id,
  # since that can change after the fact while past attendance must not.
  class AttendanceRecord < ApplicationRecord
    self.table_name = "attendance_records"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :group, class_name: "GroupManagement::Section"
    belongs_to :recorded_by_staff_member, class_name: "StaffManagement::StaffMember", optional: true

    validates :date, presence: true
    validates :status, inclusion: { in: %w[present absent late excused] }
  end
end
