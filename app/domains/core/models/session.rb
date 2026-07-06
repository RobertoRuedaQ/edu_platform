module Core
  # GLOBAL — a session belongs to a global user; current_institution is the
  # tenant it is presently acting within (nullable UI/routing state). No RLS.
  class Session < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :user, class_name: "Core::User"
    belongs_to :current_institution, class_name: "Core::Institution", optional: true
  end
end
