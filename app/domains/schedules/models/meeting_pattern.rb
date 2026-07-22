module Schedules
  class MeetingPattern < ApplicationRecord
    self.table_name = "meeting_patterns"

    DAYS = %w[mon tue wed thu fri].freeze
    DAY_LABELS = { "mon" => "Lun", "tue" => "Mar", "wed" => "Mié", "thu" => "Jue", "fri" => "Vie" }.freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :subject, class_name: "Schedules::Subject"
    belongs_to :section, class_name: "GroupManagement::Section"
    belongs_to :room, class_name: "Schedules::Room", inverse_of: :meeting_patterns

    validates :day_of_week, inclusion: { in: DAYS }
    validates :ends_at, comparison: { greater_than: :starts_at }, if: -> { starts_at.present? && ends_at.present? }

    # Scope-covering descriptor a :group-scoped grant reads (schedule.view) —
    # a meeting_pattern belongs to whichever section/group it teaches.
    delegate :group_id, to: :section

    def day_label
      DAY_LABELS.fetch(day_of_week, day_of_week)
    end
  end
end
