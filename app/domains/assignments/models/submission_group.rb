module Assignments
  # A per-TASK work group (v1.23.0) — NOT GroupManagement::Section (the
  # class/homeroom concept); groups are formed fresh for each assignment,
  # never reused across tasks (§0). Its shared entrega lives on
  # Assignments::Submission via submission_group_id (the group-anchored
  # half of that model's student XOR group CHECK).
  class SubmissionGroup < ApplicationRecord
    self.table_name = "submission_groups"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :assignment, class_name: "Assignments::Assignment"
    has_many :group_memberships, class_name: "Assignments::GroupMembership",
      foreign_key: :submission_group_id, inverse_of: :submission_group, dependent: :destroy
    has_many :students, through: :group_memberships
    has_one :submission, class_name: "Assignments::Submission",
      foreign_key: :submission_group_id, inverse_of: :submission_group, dependent: :destroy

    validates :name, presence: true
  end
end
