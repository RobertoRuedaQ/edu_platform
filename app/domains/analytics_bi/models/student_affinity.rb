module AnalyticsBi
  # One student <-> talent link (BI_DOCUMENT.md §5.5, Slice 7). T2 formativo. A
  # student is only ever linked to a curated AffinityTaxonomy node — never to
  # free text (§1.1.6). This is a DISCOVERY link ("who has this talent"), never a
  # score or a ranking between children (§1.1.3).
  #
  # source/context are closed sets backed by DB CHECKs (student_affinities_source_check
  # / _context_check); the app validations are only for friendly form errors. Only
  # `teacher_observed` has a write path this slice (AnalyticsBi::StudentAffinitiesController,
  # molde #4 supervision); guardian_reported/self_reported are reachable values whose
  # authoring UI (portal) is deferred (§6), exactly as Lens 2 was deferred from Slice 5.
  class StudentAffinity < ApplicationRecord
    self.table_name = "student_affinities"

    SOURCES  = %w[teacher_observed guardian_reported self_reported].freeze
    CONTEXTS = %w[in_school out_of_school].freeze

    SOURCE_LABELS = {
      "teacher_observed"  => "Observado por docente",
      "guardian_reported" => "Reportado por acudiente",
      "self_reported"     => "Autoreportado"
    }.freeze
    CONTEXT_LABELS = {
      "in_school"     => "Dentro del colegio",
      "out_of_school" => "Fuera del colegio"
    }.freeze

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student"
    belongs_to :taxonomy, class_name: "AnalyticsBi::AffinityTaxonomy",
      inverse_of: :student_affinities
    belongs_to :academic_term, class_name: "Core::AcademicTerm"

    validates :source, inclusion: { in: SOURCES }
    validates :context, inclusion: { in: CONTEXTS }
    # Mirrors the DB unique index for a friendly error before hitting Postgres.
    validates :taxonomy_id,
      uniqueness: { scope: %i[institution_id student_id academic_term_id] }

    # Scope-covering descriptor (#4 barrido): the WRITE path is gated on the
    # STUDENT (hps.affinity.author, scope :group via the student's section) — an
    # affinity has no group column of its own, so it delegates to the student it
    # is about, same trick as care_aura/character_evaluation.
    delegate :group_id, :grade_level_id, to: :student, allow_nil: true
  end
end
