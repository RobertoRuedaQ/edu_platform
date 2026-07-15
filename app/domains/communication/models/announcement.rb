module Communication
  # One-way broadcast, org-wide within the tenant. Retract is SOFT
  # (status: "retracted" + retracted_at) — the row always survives; a
  # retracted announcement simply drops out of Communication::AnnouncementFeed.
  # Never hard-deleted.
  class Announcement < ApplicationRecord
    self.table_name = "announcements"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :author_institution_user, class_name: "Core::InstitutionUser", optional: true

    validates :title, :body, presence: true
    validates :status, inclusion: { in: %w[published retracted] }

    scope :published, -> { where(status: "published") }

    def retract!
      update!(status: "retracted", retracted_at: Time.current)
    end
  end
end
