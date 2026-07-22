module AnalyticsBi
  # One published (or draft) character evaluation of a student, by one staff
  # author, in one term, against one framework (BI_DOCUMENT.md §5.4). T2
  # formativo, STAFF authorship only — the peer/guardian path is a completely
  # separate table (AnalyticsBi::PeerAppreciation), never mixed with this.
  #
  # framework_snapshot is FROZEN at publish (AnalyticsBi::Character::Publisher),
  # exactly like assignments.rubric_snapshot — the dimension_scores reference
  # that frozen structure by dimension_key, never a live FK.
  class CharacterEvaluation < ApplicationRecord
    self.table_name = "character_evaluations"

    # Closed sets, backed by DB CHECKs; app validations for friendly errors.
    AUTHOR_KINDS = %w[teacher counselor].freeze
    STATUSES = %w[draft published].freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :academic_term, class_name: "Core::AcademicTerm"
    belongs_to :framework, class_name: "AnalyticsBi::CharacterFramework"
    # Identity of the authoring staff member (docente/orientador) — a plain FK to
    # institution_users, same accountability posture as care_auras.authored_by_counselor.
    belongs_to :author, class_name: "Core::InstitutionUser",
      foreign_key: :author_institution_user_id
    has_many :character_dimension_scores, class_name: "AnalyticsBi::CharacterDimensionScore",
      foreign_key: :evaluation_id, inverse_of: :evaluation, dependent: :destroy

    validates :author_kind, inclusion: { in: AUTHOR_KINDS }
    validates :status, inclusion: { in: STATUSES }
    # Mirrors the DB unique index for a friendly error before hitting Postgres.
    validates :author_institution_user_id,
      uniqueness: { scope: %i[institution_id student_id academic_term_id framework_id] }

    scope :published, -> { where(status: "published") }

    # Scope-covering descriptor (#4 barrido): an evaluation has no group column
    # of its own — it's derived from the student it's about (same trick as
    # care_aura#group_id). A :group-scoped hps.character.author grant covers
    # evaluations for students in that section.
    delegate :group_id, :grade_level_id, to: :student, allow_nil: true

    def published?
      status == "published"
    end
  end
end
