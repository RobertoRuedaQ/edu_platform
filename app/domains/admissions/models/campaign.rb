module Admissions
  # An admission cycle (guidelines/library_prompt.md, Increment 2).
  # `target_entry_year` is a plain integer, never a Core::AcademicTerm FK —
  # a campaign opens months before the term it admits into even exists.
  class Campaign < ApplicationRecord
    self.table_name = "admission_campaigns"

    STATUSES = %w[draft open closed].freeze

    belongs_to :institution, class_name: "Core::Institution"
    has_many :applications, class_name: "Admissions::Application", inverse_of: :campaign,
      dependent: :restrict_with_exception

    validates :name, :target_entry_year, :opens_on, :closes_on, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :open, -> { where(status: "open") }

    # EL único puente cents (F6) -> decimal, molde Extracurriculars::Activity#fee_amount.
    def application_fee_amount
      BigDecimal(application_fee_cents) / 100
    end
  end
end
