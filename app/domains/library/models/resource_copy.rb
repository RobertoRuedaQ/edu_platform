module Library
  # A physical unit on the shelf (guidelines/library_prompt.md). `status` is
  # the ONE seam Library::LoanRecorder/ReturnRecorder guard under
  # `copy.lock!` — never destroyed, only status-transitioned (available ->
  # loaned -> available, or -> maintenance/lost), so its FK from
  # library_loans is RESTRICT-safe: that constraint never actually fires.
  class ResourceCopy < ApplicationRecord
    self.table_name = "library_resource_copies"

    STATUSES = %w[available loaned maintenance lost].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :resource, class_name: "Library::Resource", inverse_of: :copies
    has_many :loans, class_name: "Library::Loan", inverse_of: :copy,
      dependent: :restrict_with_exception

    validates :barcode, presence: true, uniqueness: { scope: :institution_id }
    validates :status, inclusion: { in: STATUSES }

    scope :available, -> { where(status: "available") }
  end
end
