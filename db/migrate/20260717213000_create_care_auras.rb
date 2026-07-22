class CreateCareAuras < ActiveRecord::Migration[8.1]
  # Slice 3 of guidelines/BI_DOCUMENT.md (HPS Lente 5, "Auras de Cuidado").
  # The clinical-isolation-preserving PROJECTION (§5.7): the diagnosis/detail
  # lives and STAYS in counseling (T3); what crosses the boundary is only this
  # abstract projection — a closed enum + counselor-authored guidance text with
  # ZERO clinical PII by construction of the workflow. Owned by analytics_bi
  # ("care_auras es una tabla de analytics_bi"), populated by a service object
  # invoked FROM counseling (AnalyticsBi::Aura::Projector) — never analytics_bi
  # reading counseling's tables, never counseling reaching into analytics_bi's
  # internals beyond that one service.
  #
  # authored_by_counselor_id is a plain FK to institution_users (identity only,
  # ON DELETE RESTRICT for accountability — same posture as counseling's
  # opened_by/author_id): it never exposes counselor PII beyond identity, and
  # there is no FK/association here to any counseling model.
  #
  # Effective-dated + append-only (same mold as classroom_layouts/seat_assignments
  # from Slice 2 and Subscription#end!/Entitlement#revoke! from billing v1.33.0):
  # republishing a kind CLOSES the active row (effective_until = Date.current)
  # and OPENS a new one, so guidance history is preserved and auditable.
  def up
    create_table :care_auras, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      # Identity of the authoring counselor. RESTRICT (not cascade/nullify) — a
      # membership with counseling authorship history is deactivated, not
      # deleted, so a published aura always has a defensible author on record.
      t.references :authored_by_counselor, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :institution_users, on_delete: :restrict }
      # Closed enum: an INSTRUCTION OF TREATMENT, never a diagnosis. string +
      # CHECK (the house mold, extracurriculars.kind) over the ERD's smallint
      # sketch — greppable and explicit ("aburrido/explícito/greppable").
      t.string :aura_kind, null: false
      # Free text the counselor writes for the teacher — apto para el docente,
      # sin dato clínico. The invariant is procedural (who may write it), not a
      # technical PII scanner; see AnalyticsBi::Aura::Projector / the counseling
      # authoring surface.
      t.text   :guidance_text, null: false
      t.date   :effective_from, null: false
      t.date   :effective_until, null: true

      t.timestamps
    end

    # LEADER institution_id (TenantRlsGuardTest requires it) + the exact shape
    # both read sides filter on: AnalyticsBi::Lens::AuraScope (teacher, by
    # student_ids) and AnalyticsBi::Aura::CounselorScope (counselor, by student)
    # — (institution, student, effective_from).
    add_index :care_auras, %i[institution_id student_id effective_from],
      name: "idx_care_auras_on_inst_student_from"

    add_check_constraint :care_auras,
      "aura_kind IN ('private_or_oral_evaluation','positive_reinforcement_public','extra_time','quiet_space')",
      name: "care_auras_aura_kind_check"
    add_check_constraint :care_auras,
      "effective_until IS NULL OR effective_until >= effective_from",
      name: "care_auras_effective_range_check"

    # Concurrency decision (§5.7 left it open): a student MAY hold multiple
    # concurrent auras of DIFFERENT kinds (a child can need both extra_time AND
    # quiet_space), but NEVER two ACTIVE auras of the SAME kind — that's a
    # duplicate, not additive care. Enforced at the DB with a partial unique
    # index on the active rows only (effective_until IS NULL == active), the
    # same active-partial-index mold as extracurriculars v1.27.0. Closed
    # (past) rows are unconstrained, so append-only history is unaffected.
    add_index :care_auras, %i[institution_id student_id aura_kind],
      unique: true, where: "effective_until IS NULL",
      name: "idx_care_auras_one_active_per_student_kind"

    enable_rls :care_auras
  end

  def down
    disable_rls :care_auras
    drop_table :care_auras
  end
end
