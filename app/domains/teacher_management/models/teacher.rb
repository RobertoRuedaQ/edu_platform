module TeacherManagement
  # A teacher/professor. Both genders represented. University teachers belong
  # to a faculty.
  class Teacher < ApplicationRecord
    self.table_name = "teachers"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :faculty, class_name: "GroupManagement::Faculty", optional: true
    # D1: a teacher is the teaching extension of a staff_member (nullable link
    # during the additive transition; see staff_management).
    belongs_to :staff_member, class_name: "StaffManagement::StaffMember",
               optional: true, inverse_of: :teacher
    has_many :teaching_assignments, class_name: "TeacherManagement::TeachingAssignment",
             foreign_key: :teacher_id, inverse_of: :teacher, dependent: :destroy

    validates :first_name, :last_name, :gender, :teacher_code, presence: true

    # The real scope descriptor (#4 slice 1): department_id/status are NOT
    # columns on teachers — they belong to the generalized staff_member (D1,
    # v1.12.0). allow_nil handles the additive transition: an unlinked
    # teacher (staff_member_id nil) has no department, so it never matches a
    # department-scoped grant — correct behavior (unlinked = not yet placed
    # in anyone's supervision scope), not a bug.
    delegate :department, :department_id, :status, to: :staff_member, allow_nil: true

    # Real subjects via teaching_assignments -> Schedules::Subject. There is
    # NO real teacher<->group/section link anywhere in the schema (same gap
    # documented since v1.10.0 self-service) — this domain never shows one.
    def subjects
      teaching_assignments.includes(:subject).map { |ta| ta.subject.name }
    end
  end
end
