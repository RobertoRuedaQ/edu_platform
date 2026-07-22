class CreateHouseholdsAndGuardianRelationships < ActiveRecord::Migration[8.1]
  # Slice 8 of guidelines/BI_DOCUMENT.md (HPS T2 formativo, §5.6) — Lens 4
  # "Núcleo Familiar". Extends the EXISTING `guardian_students` link (never
  # duplicates it) with the metadata the orbital graph needs: which guardian is
  # the primary caregiver, custody sensitivity, and household grouping.
  #
  # ENUM DEVIATION (documented, same call as every prior slice): every closed
  # enum here (relationship_kind/custody_kind/household kind) is `string` +
  # add_check_constraint, NOT the `smallint` the §5.6 sketch draws.
  #
  # SENSITIVITY (§6.2, "custody_kind... sensible; segregado"): custody_kind is a
  # plain column (no separate table needed — this is T2, not T3 clinical data,
  # so it does not need counseling's encrypted-column posture), but the READ
  # side (AnalyticsBi::Lens::FamilyGraph) never exposes it through the graph
  # payload — only through a narrow, explicit accessor a caller must opt into,
  # same allowlist-by-construction posture as care_aura's AuraScope (v1.37.0).
  def up
    # --- households -----------------------------------------------------
    create_table :households, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # nuclear/single_parent/extended/blended/other — string + CHECK.
      t.string :kind, null: false

      t.timestamps
    end
    add_index :households, :institution_id, name: "idx_households_on_institution"
    add_check_constraint :households,
      "kind IN ('nuclear','single_parent','extended','blended','other')",
      name: "households_kind_check"
    enable_rls :households

    # --- guardian_relationships ------------------------------------------
    # ONE row per existing guardian_students link — extends it 1:1 (unique
    # index below), never duplicates student_id/guardian_user_id/relationship
    # (those stay owned by Core::GuardianStudent).
    create_table :guardian_relationships, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :guardian_student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :guardian_students, on_delete: :cascade }
      # mother/father/grandparent/legal_guardian/sibling/other — string + CHECK.
      t.string  :relationship_kind, null: false
      t.boolean :is_primary_caregiver, null: false, default: false
      # shared/sole/supervised/unspecified — string + CHECK. NULLABLE: most
      # guardian_students links have no custody dimension to record at all
      # (§6.2 sensitivity — never populated speculatively).
      t.string :custody_kind
      t.references :household, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :households, on_delete: :nullify }

      t.timestamps
    end
    # ONE extension row per guardian_students link (leader institution_id
    # satisfies the RLS guard AND is the 1:1 identity constraint).
    add_index :guardian_relationships, %i[institution_id guardian_student_id],
      unique: true, name: "idx_guardian_relationships_unique_link"
    # Sibling-detection / orbital-graph reads filter by household frequently.
    add_index :guardian_relationships, %i[institution_id household_id],
      name: "idx_guardian_relationships_on_inst_household"
    add_check_constraint :guardian_relationships,
      "relationship_kind IN ('mother','father','grandparent','legal_guardian','sibling','other')",
      name: "guardian_relationships_relationship_kind_check"
    add_check_constraint :guardian_relationships,
      "custody_kind IS NULL OR custody_kind IN ('shared','sole','supervised','unspecified')",
      name: "guardian_relationships_custody_kind_check"
    enable_rls :guardian_relationships
  end

  def down
    disable_rls :guardian_relationships
    drop_table :guardian_relationships

    disable_rls :households
    drop_table :households
  end
end
