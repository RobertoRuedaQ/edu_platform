class CreateAffinityTaxonomyAndStudentAffinities < ActiveRecord::Migration[8.1]
  # Slice 7 of guidelines/BI_DOCUMENT.md (HPS T2 formativo, §5.5) — Lens 3
  # "Constelación de Afinidades". The curated talent tree plus the student <-> talent
  # link, both tenant-scoped (institution_id + RLS FORCE, uuidv7 PK, leader
  # institution_id index), same discipline as every prior slice.
  #
  # ENUM DEVIATION (documented, same call as Slices 2/3/5): every closed enum here
  # (kind/source/context) is `string` + add_check_constraint, NOT the `smallint`
  # the §5.5 sketch draws. The house mold for a closed set is greppable string +
  # CHECK (care_auras.aura_kind / character_evaluations.author_kind), never a
  # smallint mapping.
  #
  # SCHEMA EXTENSION beyond the §5.5 sketch (documented): affinity_taxonomy carries
  # a NULLABLE department_id FK. §4 makes Lens 3 a SUPERVISION surface whose scope is
  # "institución-wide OR department_id (un especialista)" — but neither the §5.5
  # taxonomy sketch nor `students` exposes a department dimension for the existing
  # :department scope reader (Authorization::Assignment::SCOPE_READERS) to cover.
  # Tagging the curated talent tree by department (the Deportes subtree -> the
  # Deportes department) is the minimal, honest way to make the §4 access model REAL
  # and testable while REUSING the :department reader exactly as Slice 2's Section
  # exposed group_id/grade_level_id — NOT a new scope_type. A NULL department_id is
  # an institution-level talent, visible only to an institution-wide grant. The
  # constellation itself stays "transversal al colegio" (§1.2): a department-scoped
  # specialist sees ALL students school-wide who hold a talent in their department.
  #
  # SEARCH: affinity_taxonomy.search_tsv is a PG18-native GENERATED ALWAYS AS
  # (to_tsvector('spanish', name)) STORED column (no trigger/callback) with a GIN
  # index — the taxonomy search (§1.1.6 "sin buscador de personas") queries THIS,
  # never a student name. 'spanish' config: the whole app is Spanish-language and
  # there is no prior FTS in this codebase to be consistent with (grep-confirmed).
  def up
    # --- affinity_taxonomy --------------------------------------------------
    # Singular table name on purpose (matches the §5.5 sketch); the model pins
    # self.table_name = "affinity_taxonomy".
    create_table :affinity_taxonomy, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # Self-referential hierarchy (Deportes > Fútbol). NULL == a root category.
      t.references :parent, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :affinity_taxonomy, on_delete: :cascade }
      # Optional department ownership (see header) — nullify so retiring a
      # department never deletes the curated talent tree, only unscopes it.
      t.references :department, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :departments, on_delete: :nullify }
      t.string  :name, null: false
      # sport/art/hobby/academic — string + CHECK (house mold, not smallint).
      t.string  :kind, null: false
      t.boolean :active, null: false, default: true
      # PG18-native generated FTS column over the Spanish-analyzed name. STORED so
      # the GIN index below is maintained by Postgres itself, no trigger/callback.
      t.virtual :search_tsv, type: :tsvector,
        as: "to_tsvector('spanish', coalesce(name, ''))", stored: true

      t.timestamps
    end
    add_index :affinity_taxonomy, %i[institution_id active],
      name: "idx_affinity_taxonomy_on_inst_active"
    # Scope filter (§4 department-scoped specialist) + tree walk, both leader
    # institution_id (satisfies the RLS guard AND is the real access filter).
    add_index :affinity_taxonomy, %i[institution_id department_id],
      name: "idx_affinity_taxonomy_on_inst_department"
    add_index :affinity_taxonomy, %i[institution_id parent_id],
      name: "idx_affinity_taxonomy_on_inst_parent"
    add_index :affinity_taxonomy, :search_tsv, using: :gin,
      name: "idx_affinity_taxonomy_on_search_tsv"
    add_check_constraint :affinity_taxonomy,
      "kind IN ('sport','art','hobby','academic')",
      name: "affinity_taxonomy_kind_check"
    enable_rls :affinity_taxonomy

    # --- student_affinities -------------------------------------------------
    create_table :student_affinities, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :taxonomy, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :affinity_taxonomy, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      # teacher_observed/guardian_reported/self_reported — string + CHECK. Only
      # teacher_observed has a write path this slice (§6); the other two values
      # are reachable data but their authoring UI (portal) is deferred.
      t.string :source, null: false
      # in_school/out_of_school — string + CHECK.
      t.string :context, null: false

      t.timestamps
    end
    # UNIQUE (§5.5): one link per (student, talent, term). LEADER institution_id
    # satisfies the RLS guard AND is the identity constraint.
    add_index :student_affinities,
      %i[institution_id student_id taxonomy_id academic_term_id],
      unique: true, name: "idx_student_affinities_unique_link"
    # Constellation lookup: "which students hold this talent, in this scope".
    add_index :student_affinities, %i[institution_id taxonomy_id],
      name: "idx_student_affinities_on_inst_taxonomy"
    add_check_constraint :student_affinities,
      "source IN ('teacher_observed','guardian_reported','self_reported')",
      name: "student_affinities_source_check"
    add_check_constraint :student_affinities,
      "context IN ('in_school','out_of_school')",
      name: "student_affinities_context_check"
    enable_rls :student_affinities
  end

  def down
    disable_rls :student_affinities
    drop_table :student_affinities

    disable_rls :affinity_taxonomy
    drop_table :affinity_taxonomy
  end
end
