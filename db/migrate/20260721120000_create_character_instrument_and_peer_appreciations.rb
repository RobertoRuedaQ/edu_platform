class CreateCharacterInstrumentAndPeerAppreciations < ActiveRecord::Migration[8.1]
  # Slice 5 of guidelines/BI_DOCUMENT.md (HPS T2 formativo, §5.4). The character
  # evaluation instrument ("rubric mold, but for behavior") plus the separate,
  # heavily-safeguarded peer/guardian appreciation path. The most NNA-sensitive
  # slice so far (§1.1) — anti-bullying and Habeas Data invariants are designed
  # INTO the schema, not bolted on after.
  #
  # TWO independent pieces, never mixed:
  #
  # 1) STAFF-AUTHORED evaluations (docente/orientador), structured exactly like
  #    assignments' rubrics (RubricTemplate/Criterion/Level + frozen snapshot):
  #      character_frameworks -> character_dimensions -> character_levels
  #      character_evaluations (framework_snapshot jsonb FROZEN at publish, same
  #        mold as assignments.rubric_snapshot) -> character_dimension_scores
  #        (dimension_key text referencing the FROZEN snapshot, NOT a live FK —
  #        same mold as rubric scores).
  #
  # 2) PEER/GUARDIAN appreciations — a SEPARATE, far more constrained pair:
  #      peer_appreciation_tags (closed, curated, constructive-only catalog —
  #        NEVER free text from a peer)
  #      peer_appreciations (one contribution; XOR giver identity; anti-duplicate
  #        / anti-brigading partial unique index; append-only moderation status).
  #
  # Plus the first CONSENT primitive in the codebase:
  #      character_program_consents (guardian consent for a minor's participation
  #        in the peer path — §5.4 point 5. The doc's molde "assignments.
  #        requires_consent" does NOT exist (grep-confirmed); this is the minimal,
  #        program-scoped consent gate that replaces that stale reference).
  #
  # ENUM DEVIATION (documented, same call as Slices 2/3): every closed enum here
  # is `string` + add_check_constraint, NOT the `smallint` the §5.4 sketch draws.
  # The house mold for a closed set is greppable string + CHECK
  # (care_auras.aura_kind / extracurriculars.kind), not a smallint mapping.
  def up
    # --- character_frameworks ----------------------------------------------
    create_table :character_frameworks, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text   :description
      # draft/published/archived — string + CHECK (house mold, not smallint).
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
    add_index :character_frameworks, %i[institution_id status],
      name: "idx_character_frameworks_on_inst_status"
    add_check_constraint :character_frameworks,
      "status IN ('draft','published','archived')",
      name: "character_frameworks_status_check"
    enable_rls :character_frameworks

    # --- character_dimensions ----------------------------------------------
    create_table :character_dimensions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :framework, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :character_frameworks, on_delete: :cascade }
      t.string  :name, null: false
      t.integer :position, null: false, default: 0
      # Relative weight (never forced to sum to 100 — same as RubricCriterion).
      t.decimal :weight, precision: 6, scale: 2, null: false, default: "1.0"

      t.timestamps
    end
    add_index :character_dimensions, %i[institution_id framework_id position],
      name: "idx_character_dimensions_on_inst_framework_pos"
    enable_rls :character_dimensions

    # --- character_levels ---------------------------------------------------
    create_table :character_levels, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :dimension, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :character_dimensions, on_delete: :cascade }
      t.string  :label, null: false
      # Observable qualitative descriptor, NOT a number (§5.4 / §1.1.2).
      t.text    :descriptor
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :character_levels, %i[institution_id dimension_id position],
      name: "idx_character_levels_on_inst_dimension_pos"
    enable_rls :character_levels

    # --- character_evaluations ----------------------------------------------
    create_table :character_evaluations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      t.references :framework, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :character_frameworks, on_delete: :restrict }
      # Structure FROZEN at publish (same mold as assignments.rubric_snapshot /
      # price_tiers_snapshot). Default '{}' so a draft is an explicit empty
      # object, never NULL (same posture as hps_term_snapshots.payload).
      t.jsonb  :framework_snapshot, null: false, default: {}
      # teacher/counselor — staff authorship only (T2). string + CHECK.
      t.string :author_kind, null: false
      # Identity of the authoring staff member. RESTRICT (not cascade/nullify) —
      # same accountability posture as care_auras.authored_by_counselor: a
      # published evaluation always has a defensible author on record.
      t.references :author_institution_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      # draft/published — string + CHECK.
      t.string   :status, null: false, default: "draft"
      t.datetime :published_at

      t.timestamps
    end
    # UNIQUE (§5.4): one author does not evaluate the same student twice in the
    # same term with the same framework. LEADER institution_id satisfies the RLS
    # guard AND is the identity constraint.
    add_index :character_evaluations,
      %i[institution_id student_id academic_term_id framework_id author_institution_user_id],
      unique: true, name: "idx_character_evaluations_unique_author"
    add_check_constraint :character_evaluations,
      "author_kind IN ('teacher','counselor')",
      name: "character_evaluations_author_kind_check"
    add_check_constraint :character_evaluations,
      "status IN ('draft','published')",
      name: "character_evaluations_status_check"
    enable_rls :character_evaluations

    # --- character_dimension_scores -----------------------------------------
    create_table :character_dimension_scores, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :evaluation, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :character_evaluations, on_delete: :cascade }
      # References the FROZEN snapshot (a dimension's id captured at publish),
      # NOT a live FK to character_dimensions — same mold as rubric scores, so
      # editing/deleting a framework never rewrites a published evaluation.
      t.text :dimension_key, null: false
      t.text :level_label, null: false
      # Optional qualitative observation by the author.
      t.text :note

      t.timestamps
    end
    add_index :character_dimension_scores, %i[institution_id evaluation_id],
      name: "idx_character_dimension_scores_on_inst_eval"
    enable_rls :character_dimension_scores

    # --- peer_appreciation_tags ---------------------------------------------
    # CLOSED, curated, constructive-only catalog — the ONLY thing a peer/guardian
    # may select. There is deliberately NO free-text column reachable from the
    # contribution path (§1.1.1 / §5.4 resguardo #1): it is impossible to write
    # an insult because there is nowhere to write one.
    create_table :peer_appreciation_tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string  :label, null: false
      t.string  :category, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :peer_appreciation_tags, %i[institution_id active],
      name: "idx_peer_appreciation_tags_on_inst_active"
    enable_rls :peer_appreciation_tags

    # --- peer_appreciations -------------------------------------------------
    create_table :peer_appreciations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # The student who RECEIVES the appreciation.
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :tag, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :peer_appreciation_tags, on_delete: :restrict }
      # peer_student/guardian — string + CHECK.
      t.string :giver_kind, null: false
      # XOR giver identity: a peer student OR a guardian user, never both, never
      # neither. Same num_nonnulls mold as messages_sender_identity_check /
      # conversation_participants_identity_check. Guardian identity is a global
      # Core::User (guardian_user_id), matching guardian_students/messages.
      t.references :giver_student, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :giver_guardian_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      # active/withheld_by_moderation — string + CHECK. Moderation is an
      # append-only status FLIP, never a destroy (§5.4 resguardo #6).
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_check_constraint :peer_appreciations,
      "giver_kind IN ('peer_student','guardian')",
      name: "peer_appreciations_giver_kind_check"
    add_check_constraint :peer_appreciations,
      "status IN ('active','withheld_by_moderation')",
      name: "peer_appreciations_status_check"
    add_check_constraint :peer_appreciations,
      "num_nonnulls(giver_student_id, giver_guardian_user_id) = 1",
      name: "peer_appreciations_giver_identity_check"

    # ANTI-DUPLICATE / ANTI-BRIGADING (§5.4 resguardo #2, molde extracurriculars
    # v1.27.0): a single giver may not repeat the same tag on the same recipient
    # in the same term. Two partial unique indexes — one per giver identity —
    # because the XOR CHECK guarantees exactly one of the two columns is non-null
    # per row, so each index constrains its own giver type (a NULL giver column
    # is distinct in a unique index and would otherwise let guardians brigade).
    # HARDENING beyond the §5.4 sketch's single (giver_student) index; documented.
    add_index :peer_appreciations,
      %i[institution_id student_id tag_id giver_student_id academic_term_id],
      unique: true, where: "status = 'active'",
      name: "idx_peer_appreciations_active_peer_giver"
    add_index :peer_appreciations,
      %i[institution_id student_id tag_id giver_guardian_user_id academic_term_id],
      unique: true, where: "status = 'active'",
      name: "idx_peer_appreciations_active_guardian_giver"
    enable_rls :peer_appreciations

    # --- character_program_consents -----------------------------------------
    # The first consent primitive in the codebase (§5.4 point 5). Program-scoped
    # (owned by analytics_bi), NOT a general Habeas-Data framework — deliberately
    # minimal. A guardian (global Core::User, same identity column as
    # guardian_students.guardian_user_id) grants a minor's participation in the
    # peer path; revoking sets revoked_at (append-only history, re-grant opens a
    # new row). "Active consent" == a row with revoked_at IS NULL.
    create_table :character_program_consents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :granted_by_guardian_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :users, on_delete: :cascade }
      t.datetime :granted_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end
    # At most ONE active consent per student. LEADER institution_id satisfies the
    # RLS guard AND enforces the "one open grant" invariant (partial index mold,
    # same as care_auras' one-active-per-kind).
    add_index :character_program_consents, %i[institution_id student_id],
      unique: true, where: "revoked_at IS NULL",
      name: "idx_character_program_consents_active_per_student"
    enable_rls :character_program_consents
  end

  def down
    disable_rls :character_program_consents
    drop_table :character_program_consents

    disable_rls :peer_appreciations
    drop_table :peer_appreciations

    disable_rls :peer_appreciation_tags
    drop_table :peer_appreciation_tags

    disable_rls :character_dimension_scores
    drop_table :character_dimension_scores

    disable_rls :character_evaluations
    drop_table :character_evaluations

    disable_rls :character_levels
    drop_table :character_levels

    disable_rls :character_dimensions
    drop_table :character_dimensions

    disable_rls :character_frameworks
    drop_table :character_frameworks
  end
end
