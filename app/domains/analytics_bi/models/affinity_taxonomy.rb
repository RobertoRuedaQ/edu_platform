module AnalyticsBi
  # Lens 3 — "Constelación de Afinidades" (BI_DOCUMENT.md §5.5, Slice 7). The
  # curated tree of talents (Deportes > Fútbol; Artes > Piano). T2 formativo,
  # STAFF-curated only — there is NO free-text talent per minor (§1.1.6): a
  # student is only ever LINKED to a node in this closed tree (StudentAffinity),
  # never allowed to type one.
  #
  # SEARCH: the taxonomy search (§1.1.6 "sin buscador de personas") runs over the
  # PG18-generated `search_tsv` (see AnalyticsBi::Lens::TaxonomySearchScope) — it
  # queries THIS table, never a student name.
  #
  # SCOPE: an optional department_id makes a node coverable by the existing
  # :department scope reader (Authorization::Assignment::SCOPE_READERS reads
  # resource.department_id), so a department-scoped specialist (§4) sees only
  # their department's talents while the constellation stays transversal al
  # colegio. A NULL department_id is an institution-level talent (covered only by
  # an institution-wide grant). This is the same scope-covering-descriptor trick
  # care_aura/character_evaluation use via #group_id — no new scope_type.
  class AffinityTaxonomy < ApplicationRecord
    self.table_name = "affinity_taxonomy"

    # Closed set, backed by a DB CHECK (affinity_taxonomy_kind_check); the app
    # validation is only here for friendly form errors.
    KINDS = %w[sport art hobby academic].freeze

    KIND_LABELS = {
      "sport"    => "Deporte",
      "art"      => "Arte",
      "hobby"    => "Pasatiempo",
      "academic" => "Académico"
    }.freeze

    def self.kind_label(kind)
      KIND_LABELS.fetch(kind.to_s, kind.to_s.humanize)
    end

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :parent, class_name: "AnalyticsBi::AffinityTaxonomy", optional: true,
      inverse_of: :children
    belongs_to :department, class_name: "StaffManagement::Department", optional: true
    has_many :children, class_name: "AnalyticsBi::AffinityTaxonomy",
      foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
    has_many :student_affinities, class_name: "AnalyticsBi::StudentAffinity",
      foreign_key: :taxonomy_id, inverse_of: :taxonomy, dependent: :destroy

    validates :name, presence: true
    validates :kind, inclusion: { in: KINDS }

    scope :active, -> { where(active: true) }

    def label_with_kind
      "#{name} (#{self.class.kind_label(kind)})"
    end
  end
end
