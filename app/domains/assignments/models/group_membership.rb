module Assignments
  # A student's placement in a work group FOR ONE ASSIGNMENT — a student is
  # in at most one group per assignment (real unique index on
  # institution_id+assignment_id+student_id). assignment_id is denormalized
  # from submission_group.assignment_id so "is this student already grouped
  # for THIS task" is queryable without an extra join.
  class GroupMembership < ApplicationRecord
    self.table_name = "group_memberships"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :submission_group, class_name: "Assignments::SubmissionGroup", inverse_of: :group_memberships
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :assignment, class_name: "Assignments::Assignment"

    validates :student_id, uniqueness: { scope: :assignment_id }
  end
end
