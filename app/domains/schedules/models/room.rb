module Schedules
  class Room < ApplicationRecord
    self.table_name = "rooms"

    KINDS = %w[classroom lab other].freeze

    belongs_to :institution, class_name: "Core::Institution"
    has_many :meeting_patterns, class_name: "Schedules::MeetingPattern", dependent: :restrict_with_error,
             inverse_of: :room

    validates :name, presence: true
    validates :kind, inclusion: { in: KINDS }
  end
end
