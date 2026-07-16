module Assignments
  # A reusable rubric — author-owned (this slice; "share with department"
  # is a future decision, not built here). Editable freely: an Assignment
  # that used this template froze its OWN immutable snapshot at publish
  # time (Assignment#rubric_snapshot) — editing (or even destroying) this
  # template afterward never touches an already-published assignment.
  class RubricTemplate < ApplicationRecord
    self.table_name = "rubric_templates"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :authored_by, class_name: "Core::User", foreign_key: :authored_by_user_id
    has_many :rubric_criteria, -> { order(:position) }, class_name: "Assignments::RubricCriterion",
      foreign_key: :rubric_template_id, inverse_of: :rubric_template, dependent: :destroy
    has_many :rubric_levels, -> { order(:position) }, class_name: "Assignments::RubricLevel",
      foreign_key: :rubric_template_id, inverse_of: :rubric_template, dependent: :destroy

    validates :name, presence: true

    # Built from the LIVE criteria/levels/descriptors at the one moment
    # this is ever read for grading purposes: Assignments::Publisher
    # freezing an Assignment#rubric_snapshot. Nothing else calls this.
    def snapshot
      {
        "template_id" => id,
        "template_name" => name,
        "criteria" => rubric_criteria.map { |c| { "id" => c.id, "name" => c.name, "weight" => c.weight.to_s } },
        "levels" => rubric_levels.map { |l| { "id" => l.id, "label" => l.label, "points" => l.points.to_s } },
        "descriptors" => RubricCellDescriptor.where(rubric_criterion_id: rubric_criteria.map(&:id))
          .each_with_object({}) do |cell, memo|
            (memo[cell.rubric_criterion_id] ||= {})[cell.rubric_level_id] = cell.descriptor
          end
      }
    end
  end
end
