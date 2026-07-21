module AnalyticsBi
  # One peer/guardian contribution toward a student (BI_DOCUMENT.md §5.4). A
  # SEPARATE, far more constrained table than the staff instrument — never mixed
  # with CharacterEvaluation authorship.
  #
  # ANTI-BULLYING INVARIANTS (§5.4 resguardos, all non-optional):
  #  1. No free text: the contribution carries only a PeerAppreciationTag (closed
  #     catalog). There is no text column here to write an insult into.
  #  2. Never attributable outside the moderate permission: the giver identity
  #     columns exist ONLY for AnalyticsBi::Character::Moderation and the audit
  #     trail. The read-model that feeds the ficha (AnalyticsBi::Character::
  #     PeerAppreciationDigest) exposes aggregate counts ONLY — never giver ids.
  #  6. Append-only moderation: withheld_by_moderation is a status flip, never a
  #     destroy. active == a contribution that counts toward aggregation.
  #
  # XOR giver identity: exactly one of giver_student_id / giver_guardian_user_id
  # (guardian is a global Core::User, matching guardian_students). Enforced at
  # the DB (peer_appreciations_giver_identity_check, num_nonnulls) and mirrored
  # here for a friendly error.
  class PeerAppreciation < ApplicationRecord
    self.table_name = "peer_appreciations"

    GIVER_KINDS = %w[peer_student guardian].freeze
    STATUSES = %w[active withheld_by_moderation].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :tag, class_name: "AnalyticsBi::PeerAppreciationTag"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :giver_student, class_name: "GroupManagement::Student", optional: true
    belongs_to :giver_guardian, class_name: "Core::User",
      foreign_key: :giver_guardian_user_id, optional: true

    validates :giver_kind, inclusion: { in: GIVER_KINDS }
    validates :status, inclusion: { in: STATUSES }
    validate :exactly_one_giver_identity

    scope :active, -> { where(status: "active") }

    def active?
      status == "active"
    end

    def withheld?
      status == "withheld_by_moderation"
    end

    private

    def exactly_one_giver_identity
      return if [ giver_student_id, giver_guardian_user_id ].compact.size == 1

      errors.add(:base, "el aporte debe pertenecer exactamente a un par o a un acudiente, nunca ambos ni ninguno")
    end
  end
end
