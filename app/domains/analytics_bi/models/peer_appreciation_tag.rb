module AnalyticsBi
  # The CLOSED, curated, constructive-only catalog a peer/guardian may select
  # from (BI_DOCUMENT.md §5.4 resguardo #1). This is the ONLY thing a
  # contribution can carry — there is deliberately no free-text column reachable
  # from the giving path, so it is impossible to write an insult.
  class PeerAppreciationTag < ApplicationRecord
    self.table_name = "peer_appreciation_tags"

    belongs_to :institution, class_name: "Core::Institution"

    validates :label, presence: true
    validates :category, presence: true

    scope :active, -> { where(active: true) }
  end
end
