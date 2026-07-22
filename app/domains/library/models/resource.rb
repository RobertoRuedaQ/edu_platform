module Library
  # A title/work in the catalog (guidelines/library_prompt.md). No status/
  # lifecycle of its own — availability lives on the physical ResourceCopy,
  # never here (a resource can have zero, one, or many copies).
  class Resource < ApplicationRecord
    self.table_name = "library_resources"

    belongs_to :institution, class_name: "Core::Institution"
    has_many :copies, class_name: "Library::ResourceCopy", inverse_of: :resource,
      dependent: :restrict_with_exception

    validates :title, presence: true

    def available_copies_count = copies.where(status: "available").count
  end
end
